import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/clock.dart';
import '../../../core/money.dart';
import '../../../data/db/database.dart';
import '../../settings/domain/settings.dart';
import '../domain/converter.dart';
import '../domain/rate.dart';

/// Курсы и базовая валюта (spec.md §4.2).
class RatesRepository {
  RatesRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  static const _baseMarker = '#base';

  /// Базовая валюта и курсы одним запросом: поток обновляется и при смене
  /// курса, и при смене базовой валюты.
  Selectable<Converter> _converterQuery() => _db
      .customSelect(
        'SELECT code AS c, rate_micro AS r FROM exchange_rates '
        "UNION ALL SELECT '$_baseMarker' AS c, value AS r FROM app_settings "
        "WHERE key = '${SettingKeys.baseCurrency}'",
        readsFrom: {_db.exchangeRates, _db.appSettings},
      )
      .asConverter();

  Stream<Converter> watchConverter() => _converterQuery().watchSingle().distinct();

  Future<Converter> converter() => _converterQuery().getSingle();

  Stream<List<Rate>> watchRates() =>
      (_db.select(_db.exchangeRates)..orderBy([(r) => OrderingTerm(expression: r.code)]))
          .watch()
          .map((rows) => [for (final r in rows) _rate(r)]);

  Future<void> setRate(String code, int rateMicro, RateSource source) async {
    if (rateMicro <= 0) throw ArgumentError.value(rateMicro, 'rateMicro');
    await _db.into(_db.exchangeRates).insertOnConflictUpdate(
      ExchangeRatesCompanion.insert(
        code: code,
        rateMicro: rateMicro,
        source: source.db,
        updatedAt: _clock.now(),
      ),
    );
  }

  /// Курсы из сети: ручной курс (`manual`) сетью не перезаписывается (§4.2).
  Future<int> applyFetched(Map<String, int> rates) async {
    var applied = 0;
    await _db.transaction(() async {
      final existing = {
        for (final r in await _db.select(_db.exchangeRates).get()) r.code: r,
      };
      for (final e in rates.entries) {
        final old = existing[e.key];
        if (old != null && old.source == RateSource.manual.db) continue;
        await setRate(e.key, e.value, RateSource.nbkr);
        applied++;
      }
    });
    return applied;
  }

  /// Валюты счетов и правил, отличные от базовой: для них нужен курс.
  Stream<Set<String>> watchForeignCurrencies() => _db
      .customSelect(
        'SELECT currency AS c FROM accounts WHERE deleted_at IS NULL '
        'UNION SELECT currency AS c FROM recurring_rules WHERE deleted_at IS NULL '
        "UNION SELECT value AS c FROM app_settings WHERE key = '${SettingKeys.baseCurrency}'",
        readsFrom: {_db.accounts, _db.recurringRules, _db.appSettings},
      )
      .watch()
      .map((rows) {
        final all = rows.map((r) => r.read<String>('c')).toList();
        final base = all.where((c) => c.startsWith('"')).map((c) => jsonDecode(c) as String).toSet();
        return all.where((c) => !c.startsWith('"') && !base.contains(c)).toSet();
      });

  /// Смена базовой валюты (§4.2) — одна транзакция: курсы, `base_amount`
  /// всех операций, суммы бюджетов. Нет курса новой базы — [MissingBaseRate].
  Future<void> changeBase(String newBase) async {
    await _db.transaction(() async {
      final conv = await converter();
      final oldBase = conv.base;
      if (newBase == oldBase) return;
      final newRate = conv.rates[newBase];
      if (newRate == null) throw MissingBaseRate(newBase);

      // Курсы: X → новая база = rate(X) / rate(newBase).
      final now = _clock.now();
      for (final r in await _db.select(_db.exchangeRates).get()) {
        if (r.code == newBase) continue;
        await (_db.update(_db.exchangeRates)..where((e) => e.code.equals(r.code))).write(
          ExchangeRatesCompanion(
            rateMicro: Value(mulDivRound(r.rateMicro, rateScale, newRate)),
            updatedAt: Value(now),
          ),
        );
      }
      await _db.into(_db.exchangeRates).insertOnConflictUpdate(
        ExchangeRatesCompanion.insert(
          code: oldBase,
          rateMicro: mulDivRound(rateScale, rateScale, newRate),
          source: RateSource.manual.db,
          updatedAt: now,
        ),
      );
      // Строка курса самой новой базы остаётся: Converter базу не читает.
      await _db.into(_db.appSettings).insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: SettingKeys.baseCurrency, value: jsonEncode(newBase)),
      );

      final next = await converter();
      // base_amount каждой операции — заново из amount по курсу её валюты.
      final txs = await _db.select(_db.transactions).get();
      for (final t in txs) {
        final v = next.toBase(t.amount, t.currency);
        if (v == null) throw MissingBaseRate(t.currency);
        if (v != t.baseAmount) {
          await (_db.update(_db.transactions)..where((x) => x.id.equals(t.id)))
              .write(TransactionsCompanion(baseAmount: Value(v)));
        }
      }
      // Бюджеты были в старой базе: пересчёт через старый курс новой базы.
      for (final b in await _db.select(_db.budgets).get()) {
        final v = fromBaseMinor(b.amount, newBase, oldBase, newRate);
        await (_db.update(_db.budgets)..where((x) => x.id.equals(b.id)))
            .write(BudgetsCompanion(amount: Value(v), updatedAt: Value(now)));
      }
    });
  }

  Rate _rate(ExchangeRate r) => Rate(
    code: r.code,
    rateMicro: r.rateMicro,
    source: RateSource.fromDb(r.source),
    updatedAt: r.updatedAt.toUtc(),
  );
}

extension on Selectable<QueryRow> {
  Selectable<Converter> asConverter() => _ConverterSelectable(this);
}

/// Все строки запроса сворачиваются в один [Converter].
class _ConverterSelectable extends Selectable<Converter> {
  _ConverterSelectable(this._inner);
  final Selectable<QueryRow> _inner;

  static Converter _fold(List<QueryRow> rows) {
    var base = 'USD';
    final rates = <String, int>{};
    for (final row in rows) {
      final code = row.read<String>('c');
      if (code == RatesRepository._baseMarker) {
        base = jsonDecode(row.read<String>('r')) as String;
      } else {
        rates[code] = row.read<int>('r');
      }
    }
    rates.remove(base);
    return Converter(base, rates);
  }

  @override
  Future<List<Converter>> get() async => [_fold(await _inner.get())];

  @override
  Stream<List<Converter>> watch() => _inner.watch().map((rows) => [_fold(rows)]);
}

/// Нет курса валюты, нужной для смены базовой (§4.2).
class MissingBaseRate implements Exception {
  const MissingBaseRate(this.currency);
  final String currency;

  @override
  String toString() => 'MissingBaseRate: $currency';
}
