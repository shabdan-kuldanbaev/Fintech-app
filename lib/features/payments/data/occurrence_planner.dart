import 'package:drift/drift.dart';

import '../../../core/calendar.dart';
import '../../../core/clock.dart';
import '../../../core/uuid.dart';
import '../../../data/db/database.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/balances.dart';
import '../../currencies/data/rates_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/planning.dart';
import '../domain/rule.dart';
import 'rule_repository.dart';

/// Материализация наступлений (spec.md §5.2). Идемпотентна: повторный
/// вызов в тот же день ничего не меняет. Оплаченные и пропущенные не
/// трогает (I10).
class OccurrencePlanner {
  OccurrencePlanner(this._db, this._clock, this._rules, this._accounts, this._rates);

  final AppDatabase _db;
  final Clock _clock;
  final RuleRepository _rules;
  final AccountRepository _accounts;
  final RatesRepository _rates;

  /// Итог прогона — для тестов и журнала.
  Future<ReplanResult> replan() async {
    final today = LocalDate.today(_clock);
    var added = 0;
    var autoPaid = 0;
    await _db.transaction(() async {
      final rules = await _rules.rules();
      final balances = await _accounts.balances();
      for (final rule in rules) {
        added += await _materialize(rule, today, balances);
        if (rule.kind == RuleKind.creditLinePayment) {
          await _refreshCreditLine(rule, balances);
        }
      }
      autoPaid = await _autoPay(rules, today);
    });
    return ReplanResult(added: added, autoPaid: autoPaid);
  }

  Future<int> _materialize(Rule rule, LocalDate today, Map<String, int> balances) async {
    final last = await _db
        .customSelect(
          'SELECT MAX(due_date) AS d, MAX(seq) AS s FROM occurrences '
          'WHERE rule_id = ? AND deleted_at IS NULL',
          variables: [Variable(rule.id)],
        )
        .getSingle();
    final lastDue = last.read<String?>('d');
    final toAdd = occurrencesToAdd(
      rule,
      today: today,
      lastDue: lastDue == null ? null : LocalDate.parse(lastDue),
      lastSeq: last.read<int?>('s') ?? 0,
    );
    if (toAdd.isEmpty) return 0;
    final now = _clock.now();
    final expected = rule.kind == RuleKind.creditLinePayment
        ? _creditLineDebt(rule, balances)
        : rule.amount;
    for (final p in toAdd) {
      await _db.into(_db.occurrences).insert(
        OccurrencesCompanion.insert(
          id: newId(),
          createdAt: now,
          updatedAt: now,
          ruleId: rule.id,
          seq: p.seq,
          dueDate: p.dueDate.iso,
          amountExpected: Value(expected),
          currency: rule.currency,
        ),
      );
    }
    return toAdd.length;
  }

  int? _creditLineDebt(Rule rule, Map<String, int> balances) {
    final balance = balances[rule.counterAccountId];
    if (balance == null) return null;
    return balance < 0 ? -balance : 0;
  }

  /// §5.2 п. 3: у кредитной линии к оплате — текущий долг.
  Future<void> _refreshCreditLine(Rule rule, Map<String, int> balances) async {
    final debt = _creditLineDebt(rule, balances);
    await (_db.update(_db.occurrences)
          ..where((o) =>
              o.ruleId.equals(rule.id) &
              o.status.equals(OccStatus.planned.db) &
              o.deletedAt.isNull()))
        .write(OccurrencesCompanion(amountExpected: Value(debt)));
  }

  /// §5.2 п. 4: автосписание — запланированные с `due_date ≤ сегодня`
  /// оплачиваются датой `due_date` суммой `amount_expected` (в валюте счёта
  /// по курсу; нет курса — остаются запланированными).
  Future<int> _autoPay(List<Rule> rules, LocalDate today) async {
    var paid = 0;
    final auto = {
      for (final r in rules)
        if (r.autoPay && r.accountId != null) r.id: r,
    };
    if (auto.isEmpty) return 0;
    final due = await (_db.select(_db.occurrences)
          ..where((o) =>
              o.status.equals(OccStatus.planned.db) &
              o.deletedAt.isNull() &
              o.dueDate.isSmallerOrEqualValue(today.iso) &
              o.amountExpected.isNotNull() &
              o.ruleId.isIn(auto.keys)))
        .get();
    for (final row in due) {
      final rule = auto[row.ruleId]!;
      try {
        await _rules.payAsExpected(row.id, date: LocalDate.parse(row.dueDate), accountId: rule.accountId);
        paid++;
      } on MissingRate {
        // Курса нет — оплата подождёт человека.
      } on TxnValidationError {
        // Счёт удалён или в архиве — тоже.
      }
    }
    return paid;
  }

  /// Итоги по счетам — для тестов.
  Future<Totals> totals() async => computeTotals(
    await _accounts.all(),
    await _accounts.balances(),
    await _rates.converter(),
  );
}

class ReplanResult {
  const ReplanResult({required this.added, required this.autoPaid});
  final int added;
  final int autoPaid;
}
