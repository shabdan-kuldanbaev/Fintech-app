import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/calendar.dart';
import '../../../core/clock.dart';
import '../../../core/uuid.dart';
import '../../../data/db/database.dart';
import '../../currencies/data/rates_repository.dart';
import '../../settings/data/settings_repository.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/rule.dart';
import '../domain/schedule.dart';

/// Правила и наступления (spec.md §3.4, §5, I9, I10).
class RuleRepository {
  RuleRepository(this._db, this._clock, this._settings, this._transactions, this._rates);

  final AppDatabase _db;
  final Clock _clock;
  final SettingsRepository _settings;
  final TransactionRepository _transactions;
  final RatesRepository _rates;

  LocalDate get _today => LocalDate.today(_clock);

  // --------------------------------------------------------------- правила

  Stream<List<Rule>> watchRules() =>
      (_db.select(_db.recurringRules)
            ..where((r) => r.deletedAt.isNull())
            ..orderBy([(r) => OrderingTerm(expression: r.createdAt)]))
          .watch()
          .map((rows) => rows.map(toRule).toList());

  Future<List<Rule>> rules() async =>
      (await (_db.select(_db.recurringRules)..where((r) => r.deletedAt.isNull())).get())
          .map(toRule)
          .toList();

  Future<Rule?> rule(String id) async {
    final row = await (_db.select(_db.recurringRules)..where((r) => r.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : toRule(row);
  }

  Stream<Rule?> watchRule(String id) =>
      (_db.select(_db.recurringRules)..where((r) => r.id.equals(id) & r.deletedAt.isNull()))
          .watchSingleOrNull()
          .map((r) => r == null ? null : toRule(r));

  static void validate(RuleInput input) {
    if (input.name.trim().isEmpty) throw const RuleValidationError('name');
    if (input.amount != null && input.amount! <= 0) {
      throw const RuleValidationError('amount');
    }
    if (input.interval < 1) throw const RuleValidationError('interval');
    if (input.kind.isTransfer) {
      if (input.counterAccountId == null) throw const RuleValidationError('counter_account');
    } else if (input.categoryId == null) {
      throw const RuleValidationError('category');
    }
    if (input.kind == RuleKind.loanPayment && input.endDate == null) {
      throw const RuleValidationError('end_date');
    }
    if (input.endDate != null && input.endDate! < input.startDate) {
      throw const RuleValidationError('end_date');
    }
    if (input.dayOfMonth != null && (input.dayOfMonth! < 1 || input.dayOfMonth! > 31)) {
      throw const RuleValidationError('day_of_month');
    }
  }

  /// Вставка правила; внутри транзакции вызывающего (кредит) — в ней же.
  /// Наступления создаёт `OccurrencePlanner`.
  Future<String> insert(RuleInput input) async {
    validate(input);
    final id = newId();
    await _db.transaction(() async {
      final now = _clock.now();
      final base = await _settings.takeNotificationBaseId();
      await _db.into(_db.recurringRules).insert(
        RecurringRulesCompanion.insert(
          id: id,
          createdAt: now,
          updatedAt: now,
          name: input.name.trim(),
          kind: input.kind.db,
          accountId: Value(input.accountId),
          counterAccountId: Value(input.counterAccountId),
          categoryId: Value(input.categoryId),
          amount: Value(input.amount),
          currency: input.currency,
          frequency: input.frequency.db,
          interval: Value(input.interval),
          dayOfMonth: Value(input.dayOfMonth),
          startDate: input.startDate.iso,
          endDate: Value(input.endDate?.iso),
          remindDaysBefore: Value(jsonEncode(input.remindDaysBefore)),
          remindMinutes: Value(input.remindMinutes),
          notificationBaseId: base,
          autoPay: Value(input.autoPay),
          iconKey: input.iconKey ?? input.kind.defaultIcon,
          colorKey: input.colorKey ?? input.kind.defaultColor,
        ),
      );
    });
    return id;
  }

  /// Правка правила (§3.4): поля расписания поменялись — будущие
  /// запланированные наступления уходят, планировщик создаст новые.
  /// Оплаченные и пропущенные не трогаются (I10).
  Future<void> update(String id, RuleInput input) async {
    validate(input);
    await _db.transaction(() async {
      final now = _clock.now();
      await (_db.update(_db.recurringRules)..where((r) => r.id.equals(id))).write(
        RecurringRulesCompanion(
          updatedAt: Value(now),
          name: Value(input.name.trim()),
          accountId: Value(input.accountId),
          counterAccountId: Value(input.counterAccountId),
          categoryId: Value(input.categoryId),
          amount: Value(input.amount),
          currency: Value(input.currency),
          frequency: Value(input.frequency.db),
          interval: Value(input.interval),
          dayOfMonth: Value(input.dayOfMonth),
          startDate: Value(input.startDate.iso),
          endDate: Value(input.endDate?.iso),
          remindDaysBefore: Value(jsonEncode(input.remindDaysBefore)),
          remindMinutes: Value(input.remindMinutes),
          autoPay: Value(input.autoPay),
          iconKey: Value(input.iconKey ?? input.kind.defaultIcon),
          colorKey: Value(input.colorKey ?? input.kind.defaultColor),
        ),
      );
      await _dropFuturePlanned(id, from: _today, now: now);
    });
  }

  /// Пауза до [until] (`Rule.pausedForever` — без срока): запланированные
  /// наступления в `[сегодня, until)` снимаются.
  Future<void> pause(String id, LocalDate until) async {
    await _db.transaction(() async {
      final now = _clock.now();
      await (_db.update(_db.recurringRules)..where((r) => r.id.equals(id))).write(
        RecurringRulesCompanion(pausedUntil: Value(until.iso), updatedAt: Value(now)),
      );
      await (_db.update(_db.occurrences)
            ..where((o) =>
                o.ruleId.equals(id) &
                o.status.equals(OccStatus.planned.db) &
                o.deletedAt.isNull() &
                o.dueDate.isBiggerOrEqualValue(_today.iso) &
                o.dueDate.isSmallerThanValue(until.iso)))
          .write(OccurrencesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
    });
  }

  Future<void> resume(String id) async {
    await (_db.update(_db.recurringRules)..where((r) => r.id.equals(id))).write(
      RecurringRulesCompanion(pausedUntil: const Value(null), updatedAt: Value(_clock.now())),
    );
  }

  /// Удаление правила: оно и его запланированные наступления — soft;
  /// оплаченные и их операции остаются (§3.4).
  Future<void> delete(String id) async {
    await _db.transaction(() async {
      final now = _clock.now();
      await (_db.update(_db.recurringRules)..where((r) => r.id.equals(id)))
          .write(RecurringRulesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
      await (_db.update(_db.occurrences)
            ..where((o) => o.ruleId.equals(id) & o.status.equals(OccStatus.planned.db) & o.deletedAt.isNull()))
          .write(OccurrencesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
    });
  }

  Future<void> _dropFuturePlanned(String ruleId, {required LocalDate from, required DateTime now}) =>
      (_db.update(_db.occurrences)
            ..where((o) =>
                o.ruleId.equals(ruleId) &
                o.status.equals(OccStatus.planned.db) &
                o.deletedAt.isNull() &
                o.dueDate.isBiggerOrEqualValue(from.iso)))
          .write(OccurrencesCompanion(deletedAt: Value(now), updatedAt: Value(now)));

  // ------------------------------------------------------------ наступления

  Future<Occurrence?> occurrence(String id) async {
    final row = await (_db.select(_db.occurrences)..where((o) => o.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : toOccurrence(row);
  }

  /// Наступление вместе с правилом; удалённое — `null`.
  Stream<DueItem?> watchItem(String occurrenceId) {
    final q = _db.select(_db.occurrences).join([
      innerJoin(_db.recurringRules, _db.recurringRules.id.equalsExp(_db.occurrences.ruleId)),
    ])..where(_db.occurrences.id.equals(occurrenceId) & _db.occurrences.deletedAt.isNull());
    return q.watchSingleOrNull().map(
      (row) => row == null
          ? null
          : DueItem(
              toOccurrence(row.readTable(_db.occurrences)),
              toRule(row.readTable(_db.recurringRules)),
            ),
    );
  }

  /// Живые наступления живых правил с `due_date` в `[from, until]` и
  /// статусами [statuses], по дате.
  Stream<List<DueItem>> watchItems({
    LocalDate? from,
    required LocalDate until,
    Set<OccStatus> statuses = const {OccStatus.planned},
    String? ruleId,
  }) {
    final o = _db.occurrences;
    final r = _db.recurringRules;
    final q = _db.select(o).join([innerJoin(r, r.id.equalsExp(o.ruleId))])
      ..where(o.deletedAt.isNull() & r.deletedAt.isNull() & o.dueDate.isSmallerOrEqualValue(until.iso))
      ..where(o.status.isIn(statuses.map((s) => s.db)))
      ..orderBy([OrderingTerm(expression: o.dueDate), OrderingTerm(expression: o.seq)]);
    if (from != null) q.where(o.dueDate.isBiggerOrEqualValue(from.iso));
    if (ruleId != null) q.where(o.ruleId.equals(ruleId));
    return q.watch().map(
      (rows) => [for (final row in rows) DueItem(toOccurrence(row.readTable(o)), toRule(row.readTable(r)))],
    );
  }

  /// Все наступления правила (для экрана правила и графика кредита).
  Stream<List<Occurrence>> watchOfRule(String ruleId) =>
      (_db.select(_db.occurrences)
            ..where((o) => o.ruleId.equals(ruleId) & o.deletedAt.isNull())
            ..orderBy([(o) => OrderingTerm(expression: o.dueDate)]))
          .watch()
          .map((rows) => rows.map(toOccurrence).toList());

  /// Наступления правил-переводов (кредит, кредитная линия) — для сведений
  /// «оплачено N из M» и «следующий платёж» по счёту-пассиву.
  Stream<List<DueItem>> watchObligationItems() {
    final o = _db.occurrences;
    final r = _db.recurringRules;
    final q = _db.select(o).join([innerJoin(r, r.id.equalsExp(o.ruleId))])
      ..where(o.deletedAt.isNull() & r.deletedAt.isNull() & r.counterAccountId.isNotNull())
      ..orderBy([OrderingTerm(expression: o.dueDate), OrderingTerm(expression: o.seq)]);
    return q.watch().map(
      (rows) => [for (final row in rows) DueItem(toOccurrence(row.readTable(o)), toRule(row.readTable(r)))],
    );
  }

  /// Сумма последней оплаты правила — подсказка «Last time» и прогноз.
  Future<int?> lastPaidAmount(String ruleId) async {
    final row = await _db
        .customSelect(
          'SELECT t.amount AS a FROM occurrences o JOIN transactions t ON t.id = o.transaction_id '
          "WHERE o.rule_id = ? AND o.status = 'paid' AND o.deleted_at IS NULL AND t.deleted_at IS NULL "
          'ORDER BY o.due_date DESC LIMIT 1',
          variables: [Variable(ruleId)],
        )
        .getSingleOrNull();
    return row?.read<int>('a');
  }

  /// Последняя оплата по каждому правилу — одним запросом.
  Stream<Map<String, int>> watchLastPaid() => _db
      .customSelect(
        'SELECT o.rule_id AS r, t.amount AS a, o.due_date AS d FROM occurrences o '
        'JOIN transactions t ON t.id = o.transaction_id '
        "WHERE o.status = 'paid' AND o.deleted_at IS NULL AND t.deleted_at IS NULL "
        'ORDER BY o.due_date',
        readsFrom: {_db.occurrences, _db.transactions},
      )
      .watch()
      .map((rows) => {for (final row in rows) row.read<String>('r'): row.read<int>('a')});

  /// Оплата наступления (I9): операция и статус — одна транзакция БД.
  /// [amount] — в валюте счёта [accountId].
  Future<String> pay(
    String occurrenceId, {
    required int amount,
    required String accountId,
    LocalDate? date,
    int? counterAmount,
  }) async {
    late String txId;
    await _db.transaction(() async {
      final occ = await occurrence(occurrenceId);
      if (occ == null || occ.status != OccStatus.planned) {
        throw const RuleValidationError('not_planned');
      }
      final r = (await rule(occ.ruleId))!;
      final input = r.kind.isTransfer
          ? TxnInput(
              kind: TxKind.transfer,
              accountId: accountId,
              counterAccountId: r.counterAccountId,
              amount: amount,
              counterAmount: await _counterAmount(accountId, r.counterAccountId!, amount, counterAmount),
              date: date ?? _today,
              occurrenceId: occ.id,
            )
          : TxnInput(
              kind: TxKind.expense,
              accountId: accountId,
              amount: amount,
              date: date ?? _today,
              categoryId: r.categoryId,
              occurrenceId: occ.id,
            );
      txId = await _transactions.create(input);
      final now = _clock.now();
      await (_db.update(_db.occurrences)..where((o) => o.id.equals(occ.id))).write(
        OccurrencesCompanion(
          status: Value(OccStatus.paid.db),
          transactionId: Value(txId),
          paidAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    });
    return txId;
  }

  /// Перевод на пассив в другой валюте: зачисление по текущему курсу;
  /// в одной валюте — `null` (репозиторий операций подставит ту же сумму).
  Future<int?> _counterAmount(String from, String to, int amount, int? given) async {
    final a = await (_db.select(_db.accounts)..where((x) => x.id.equals(from))).getSingle();
    final b = await (_db.select(_db.accounts)..where((x) => x.id.equals(to))).getSingle();
    if (a.currency == b.currency) return null;
    if (given != null) return given;
    final converted = (await _rates.converter()).convert(amount, a.currency, b.currency);
    if (converted == null) throw MissingRate(b.currency);
    return converted;
  }

  /// Оплатить «как запланировано» (кнопка «Pay N» в строке, действие
  /// «Paid» уведомления, автосписание): ожидаемая сумма в валюте счёта
  /// по курсу, счёт правила или [accountId].
  Future<String> payAsExpected(String occurrenceId, {LocalDate? date, String? accountId}) async {
    final occ = await occurrence(occurrenceId);
    if (occ == null || occ.status != OccStatus.planned) {
      throw const RuleValidationError('not_planned');
    }
    final r = (await rule(occ.ruleId))!;
    final from = accountId ?? r.accountId;
    if (from == null) throw const RuleValidationError('account');
    final expected = occ.amountExpected;
    if (expected == null || expected <= 0) throw const RuleValidationError('amount');
    final account = await (_db.select(_db.accounts)..where((a) => a.id.equals(from) & a.deletedAt.isNull()))
        .getSingleOrNull();
    if (account == null) throw const TxnValidationError('account');
    final amount = (await _rates.converter()).convert(expected, occ.currency, account.currency);
    if (amount == null) throw MissingRate(occ.currency);
    return pay(occurrenceId, amount: amount, accountId: from, date: date);
  }

  /// Отмена оплаты (I9): операция — soft, наступление — снова planned.
  Future<void> unpay(String occurrenceId) async {
    await _db.transaction(() async {
      final occ = await occurrence(occurrenceId);
      if (occ == null || occ.status != OccStatus.paid) return;
      final now = _clock.now();
      if (occ.transactionId != null) {
        await (_db.update(_db.transactions)..where((t) => t.id.equals(occ.transactionId!)))
            .write(TransactionsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
      }
      await (_db.update(_db.occurrences)..where((o) => o.id.equals(occurrenceId))).write(
        OccurrencesCompanion(
          status: Value(OccStatus.planned.db),
          transactionId: const Value(null),
          paidAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
    });
  }

  Future<void> skip(String occurrenceId) => _setStatus(occurrenceId, OccStatus.skipped, from: OccStatus.planned);

  Future<void> unskip(String occurrenceId) => _setStatus(occurrenceId, OccStatus.planned, from: OccStatus.skipped);

  Future<void> _setStatus(String id, OccStatus to, {required OccStatus from}) =>
      (_db.update(_db.occurrences)..where((o) => o.id.equals(id) & o.status.equals(from.db)))
          .write(OccurrencesCompanion(status: Value(to.db), updatedAt: Value(_clock.now())));

  /// Изменить ожидаемую сумму наступления (коммуналка, пересчёт кредита).
  Future<void> setExpected(String occurrenceId, int? amount) =>
      (_db.update(_db.occurrences)..where((o) => o.id.equals(occurrenceId))).write(
        OccurrencesCompanion(amountExpected: Value(amount), updatedAt: Value(_clock.now())),
      );

  // ------------------------------------------------------------- маппинг

  static Rule toRule(RuleRow r) => Rule(
    id: r.id,
    name: r.name,
    kind: RuleKind.fromDb(r.kind),
    accountId: r.accountId,
    counterAccountId: r.counterAccountId,
    categoryId: r.categoryId,
    amount: r.amount,
    currency: r.currency,
    frequency: Frequency.fromDb(r.frequency),
    interval: r.interval,
    dayOfMonth: r.dayOfMonth,
    startDate: LocalDate.parse(r.startDate),
    endDate: r.endDate == null ? null : LocalDate.parse(r.endDate!),
    remindDaysBefore: (jsonDecode(r.remindDaysBefore) as List<dynamic>).cast<int>(),
    remindMinutes: r.remindMinutes,
    notificationBaseId: r.notificationBaseId,
    autoPay: r.autoPay,
    pausedUntil: r.pausedUntil == null ? null : LocalDate.parse(r.pausedUntil!),
    iconKey: r.iconKey,
    colorKey: r.colorKey,
  );

  static Occurrence toOccurrence(OccurrenceRow o) => Occurrence(
    id: o.id,
    ruleId: o.ruleId,
    seq: o.seq,
    dueDate: LocalDate.parse(o.dueDate),
    amountExpected: o.amountExpected,
    currency: o.currency,
    status: OccStatus.fromDb(o.status),
    transactionId: o.transactionId,
    paidAt: o.paidAt?.toUtc(),
  );
}

class RuleValidationError implements Exception {
  const RuleValidationError(this.reason);
  final String reason;

  @override
  String toString() => 'RuleValidationError: $reason';
}
