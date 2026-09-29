import 'package:drift/drift.dart';

import '../../../core/calendar.dart';
import '../../../core/clock.dart';
import '../../../core/uuid.dart';
import '../../../data/db/database.dart';
import '../domain/account.dart';
import '../domain/loan_math.dart';

/// Счета (spec.md §3.4). Балансы — только вычисления над транзакциями (I3).
class AccountRepository {
  AccountRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  SimpleSelectStatement<$AccountsTable, AccountRow> _alive() =>
      _db.select(_db.accounts)
        ..where((a) => a.deletedAt.isNull())
        ..orderBy([
          (a) => OrderingTerm(expression: a.sortOrder),
          (a) => OrderingTerm(expression: a.createdAt),
        ]);

  Stream<List<Account>> watchAll() =>
      _alive().watch().map((rows) => rows.map(toAccount).toList());

  Future<List<Account>> all() async =>
      (await _alive().get()).map(toAccount).toList();

  Future<Account?> get(String id) async {
    final row = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(id) & a.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : toAccount(row);
  }

  Stream<Account?> watch(String id) =>
      (_db.select(_db.accounts)
            ..where((a) => a.id.equals(id) & a.deletedAt.isNull()))
          .watchSingleOrNull()
          .map((r) => r == null ? null : toAccount(r));

  /// Баланс каждого живого счёта (§9.1): начальный + доходы − расходы −
  /// исходящие переводы + входящие переводы. Только неудалённые операции.
  static const String _balancesSql = '''
SELECT a.id AS id,
  a.opening_balance
  + COALESCE((SELECT SUM(CASE WHEN t.kind = 'income' THEN t.amount ELSE -t.amount END)
      FROM transactions t WHERE t.account_id = a.id AND t.deleted_at IS NULL), 0)
  + COALESCE((SELECT SUM(t.counter_amount)
      FROM transactions t WHERE t.counter_account_id = a.id
        AND t.kind = 'transfer' AND t.deleted_at IS NULL), 0) AS balance
FROM accounts a WHERE a.deleted_at IS NULL''';

  Selectable<Map<String, int>> _balancesQuery() => _db
      .customSelect(_balancesSql, readsFrom: {_db.accounts, _db.transactions})
      .map((r) => MapEntry(r.read<String>('id'), r.read<int>('balance')))
      .asMap();

  Stream<Map<String, int>> watchBalances() => _balancesQuery().watchSingle();

  Future<Map<String, int>> balances() => _balancesQuery().getSingle();

  /// Изменение баланса счетов за период `[from, to)` — «−7 119 this month».
  Stream<Map<String, int>> watchDelta(LocalDate from, LocalDate to) => _db
      .customSelect(
        '''
SELECT id, SUM(v) AS v FROM (
  SELECT account_id AS id,
    CASE WHEN kind = 'income' THEN amount ELSE -amount END AS v
  FROM transactions WHERE deleted_at IS NULL AND date >= ?1 AND date < ?2
  UNION ALL
  SELECT counter_account_id AS id, counter_amount AS v
  FROM transactions WHERE deleted_at IS NULL AND kind = 'transfer'
    AND date >= ?1 AND date < ?2
) GROUP BY id''',
        variables: [Variable(from.iso), Variable(to.iso)],
        readsFrom: {_db.transactions},
      )
      .map((r) => MapEntry(r.read<String>('id'), r.read<int>('v')))
      .asMap()
      .watchSingle();

  Future<bool> hasTransactions(String id) async {
    final row = await _db
        .customSelect(
          'SELECT EXISTS(SELECT 1 FROM transactions WHERE deleted_at IS NULL '
          'AND (account_id = ?1 OR counter_account_id = ?1)) AS e',
          variables: [Variable(id)],
        )
        .getSingle();
    return row.read<bool>('e');
  }

  /// Проверки §3.4 по виду счёта.
  static void validate(AccountInput input) {
    if (input.name.trim().isEmpty) {
      throw const AccountValidationError('name');
    }
    switch (input.kind) {
      case AccountKind.creditLine:
        if ((input.creditLimit ?? 0) <= 0) {
          throw const AccountValidationError('credit_limit');
        }
        final day = input.dueDay;
        if (day == null || day < 1 || day > 28) {
          throw const AccountValidationError('due_day');
        }
      case AccountKind.loan:
        if ((input.totalPayable ?? 0) <= 0 ||
            (input.monthlyPayment ?? 0) <= 0 ||
            (input.termMonths ?? 0) < 1 ||
            input.firstPaymentDate == null) {
          throw const AccountValidationError('loan');
        }
      case AccountKind.cash:
      case AccountKind.card:
      case AccountKind.savings:
      case AccountKind.deposit:
        break;
    }
  }

  /// Создание счёта. Для кредита и кредитной линии — только через
  /// `ObligationRepository.createLoan/createCreditLine` (там же правило).
  Future<String> create(AccountInput input) async {
    validate(input);
    final id = newId();
    await _db.transaction(() async {
      final now = _clock.now();
      final order = await _db
          .customSelect(
            'SELECT COALESCE(MAX(sort_order), -1) + 1 AS o FROM accounts',
          )
          .getSingle();
      await _db.into(_db.accounts).insert(
        _companion(input, id: id, now: now, sortOrder: order.read<int>('o')),
      );
    });
    return id;
  }

  AccountsCompanion _companion(
    AccountInput input, {
    required String id,
    required DateTime now,
    required int sortOrder,
  }) => AccountsCompanion.insert(
    id: id,
    createdAt: now,
    updatedAt: now,
    name: input.name.trim(),
    kind: input.kind.db,
    currency: input.currency,
    openingBalance: Value(input.openingBalance),
    creditLimit: Value(input.creditLimit),
    dueDay: Value(input.dueDay),
    minPayment: Value(input.minPayment),
    principal: Value(input.principal),
    totalPayable: Value(input.totalPayable),
    monthlyPayment: Value(input.monthlyPayment),
    termMonths: Value(input.termMonths),
    rateBp: Value(input.rateBp),
    ratePeriod: Value(input.ratePeriod?.name),
    firstPaymentDate: Value(input.firstPaymentDate?.iso),
    targetAmount: Value(input.targetAmount),
    targetDate: Value(input.targetDate?.iso),
    iconKey: input.iconKey ?? input.kind.defaultIcon,
    colorKey: input.colorKey ?? input.kind.defaultColor,
    sortOrder: Value(sortOrder),
    includeInTotal: Value(input.includeInTotal),
  );

  /// Вставка внутри чужой транзакции (кредит вместе с правилом).
  Future<String> insertRaw(AccountInput input) async {
    validate(input);
    final id = newId();
    final order = await _db
        .customSelect('SELECT COALESCE(MAX(sort_order), -1) + 1 AS o FROM accounts')
        .getSingle();
    await _db.into(_db.accounts).insert(
      _companion(input, id: id, now: _clock.now(), sortOrder: order.read<int>('o')),
    );
    return id;
  }

  /// Правка полей счёта. Вид не меняется; валюту нельзя сменить, если по
  /// счёту есть операции (§3.4). Начальный баланс здесь не трогается —
  /// правка баланса идёт корректировкой (I3).
  Future<void> update(String id, AccountInput input) async {
    validate(input);
    await _db.transaction(() async {
      final old = await get(id);
      if (old == null) throw const AccountValidationError('missing');
      if (old.currency != input.currency && await hasTransactions(id)) {
        throw const AccountValidationError('currency_locked');
      }
      await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
        AccountsCompanion(
          updatedAt: Value(_clock.now()),
          name: Value(input.name.trim()),
          currency: Value(input.currency),
          creditLimit: Value(input.creditLimit),
          dueDay: Value(input.dueDay),
          minPayment: Value(input.minPayment),
          targetAmount: Value(input.targetAmount),
          targetDate: Value(input.targetDate?.iso),
          iconKey: Value(input.iconKey ?? old.iconKey),
          colorKey: Value(input.colorKey ?? old.colorKey),
          includeInTotal: Value(input.includeInTotal),
          rateBp: Value(input.rateBp ?? old.rateBp),
        ),
      );
    });
  }

  /// Начальный баланс — только пока по счёту нет операций (новый счёт,
  /// опечатка сразу после создания); дальше — корректировка.
  Future<void> setOpeningBalance(String id, int value) async {
    await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        openingBalance: Value(value),
        updatedAt: Value(_clock.now()),
      ),
    );
  }

  Future<void> setArchived(String id, bool archived) async {
    await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        isArchived: Value(archived),
        updatedAt: Value(_clock.now()),
      ),
    );
  }

  /// Удаление (soft) — только счёта без операций (§3.4); вместе с ним
  /// удаляются правила, которые с него платят или его гасят, и их
  /// запланированные наступления.
  Future<void> delete(String id) async {
    await _db.transaction(() async {
      if (await hasTransactions(id)) {
        throw const AccountValidationError('has_transactions');
      }
      final now = _clock.now();
      await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
        AccountsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      final rules = await (_db.select(_db.recurringRules)
            ..where((r) =>
                r.deletedAt.isNull() &
                (r.counterAccountId.equals(id) | r.accountId.equals(id))))
          .get();
      for (final r in rules) {
        if (r.counterAccountId == id) {
          await (_db.update(_db.recurringRules)..where((x) => x.id.equals(r.id)))
              .write(RecurringRulesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
          await (_db.update(_db.occurrences)
                ..where((o) => o.ruleId.equals(r.id) & o.status.equals('planned') & o.deletedAt.isNull()))
              .write(OccurrencesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
        } else {
          // Правило платило с этого счёта: остаётся, счёт спросят при оплате.
          await (_db.update(_db.recurringRules)..where((x) => x.id.equals(r.id)))
              .write(RecurringRulesCompanion(accountId: const Value(null), updatedAt: Value(now)));
        }
      }
    });
  }

  static Account toAccount(AccountRow r) => Account(
    id: r.id,
    name: r.name,
    kind: AccountKind.fromDb(r.kind),
    currency: r.currency,
    openingBalance: r.openingBalance,
    creditLimit: r.creditLimit,
    dueDay: r.dueDay,
    minPayment: r.minPayment,
    principal: r.principal,
    totalPayable: r.totalPayable,
    monthlyPayment: r.monthlyPayment,
    termMonths: r.termMonths,
    rateBp: r.rateBp,
    ratePeriod: switch (r.ratePeriod) {
      'year' => RatePeriod.year,
      'month' => RatePeriod.month,
      _ => null,
    },
    firstPaymentDate: r.firstPaymentDate == null
        ? null
        : LocalDate.parse(r.firstPaymentDate!),
    targetAmount: r.targetAmount,
    targetDate: r.targetDate == null ? null : LocalDate.parse(r.targetDate!),
    iconKey: r.iconKey,
    colorKey: r.colorKey,
    sortOrder: r.sortOrder,
    includeInTotal: r.includeInTotal,
    isArchived: r.isArchived,
  );
}

extension MapSelectable<K, V> on Selectable<MapEntry<K, V>> {
  /// Все строки запроса — одним `Map`.
  Selectable<Map<K, V>> asMap() => _MapSelectable(this);
}

class _MapSelectable<K, V> extends Selectable<Map<K, V>> {
  _MapSelectable(this._inner);
  final Selectable<MapEntry<K, V>> _inner;

  @override
  Future<List<Map<K, V>>> get() async => [Map.fromEntries(await _inner.get())];

  @override
  Stream<List<Map<K, V>>> watch() =>
      _inner.watch().map((rows) => [Map.fromEntries(rows)]);
}
