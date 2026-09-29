import 'package:drift/drift.dart';

import '../../../core/calendar.dart';
import '../../../core/clock.dart';
import '../../../core/uuid.dart';
import '../../../data/db/database.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/domain/loan_math.dart';
import '../domain/rule.dart';
import '../domain/schedule.dart';
import 'rule_repository.dart';

/// Что вводит пользователь на «New loan» (§8.3, §4.3).
class LoanInput {
  const LoanInput({
    required this.name,
    required this.currency,
    required this.principal,
    required this.totalPayable,
    required this.monthlyPayment,
    required this.termMonths,
    required this.firstPaymentDate,
    this.rateBp,
    this.ratePeriod,
    this.payFromAccountId,
    this.remindDaysBefore = const [3, 0],
  });

  final String name;
  final String currency;
  final int principal;
  final int totalPayable;
  final int monthlyPayment;
  final int termMonths;
  final LocalDate firstPaymentDate;
  final int? rateBp;
  final RatePeriod? ratePeriod;
  final String? payFromAccountId;
  final List<int> remindDaysBefore;
}

/// «New credit line» (§8.3).
class CreditLineInput {
  const CreditLineInput({
    required this.name,
    required this.currency,
    required this.creditLimit,
    required this.dueDay,
    this.currentDebt = 0,
    this.minPayment,
    this.payFromAccountId,
    this.remindDaysBefore = const [3, 0],
  });

  final String name;
  final String currency;
  final int creditLimit;
  final int dueDay;
  final int currentDebt;
  final int? minPayment;
  final String? payFromAccountId;
  final List<int> remindDaysBefore;
}

/// Кредиты и кредитные линии: счёт, правило и наступления — одной
/// транзакцией (spec.md §3.4).
class ObligationRepository {
  ObligationRepository(this._db, this._clock, this._accounts, this._rules);

  final AppDatabase _db;
  final Clock _clock;
  final AccountRepository _accounts;
  final RuleRepository _rules;

  /// Кредит: счёт `loan` с `opening = −total`, правило `loan_payment` и
  /// все платежи сразу; последний добирает разницу до `total` (§3.4).
  Future<String> createLoan(LoanInput input) async {
    late String accountId;
    await _db.transaction(() async {
      accountId = await _accounts.insertRaw(
        AccountInput(
          name: input.name,
          kind: AccountKind.loan,
          currency: input.currency,
          openingBalance: -input.totalPayable,
          principal: input.principal,
          totalPayable: input.totalPayable,
          monthlyPayment: input.monthlyPayment,
          termMonths: input.termMonths,
          rateBp: input.rateBp,
          ratePeriod: input.ratePeriod,
          firstPaymentDate: input.firstPaymentDate,
          includeInTotal: false,
        ),
      );
      final end = input.firstPaymentDate.addMonths(input.termMonths - 1);
      final ruleId = await _rules.insert(
        RuleInput(
          name: input.name,
          kind: RuleKind.loanPayment,
          accountId: input.payFromAccountId,
          counterAccountId: accountId,
          amount: input.monthlyPayment,
          currency: input.currency,
          frequency: Frequency.monthly,
          dayOfMonth: input.firstPaymentDate.day,
          startDate: input.firstPaymentDate,
          endDate: end,
          remindDaysBefore: input.remindDaysBefore,
        ),
      );
      final dates = scheduleDates(
        ScheduleSpec(
          frequency: Frequency.monthly,
          start: input.firstPaymentDate,
          dayOfMonth: input.firstPaymentDate.day,
          end: end,
        ),
        from: input.firstPaymentDate,
        until: end,
      );
      final amounts = paymentSchedule(
        total: input.totalPayable,
        payment: input.monthlyPayment,
        months: dates.length,
      );
      final now = _clock.now();
      for (var i = 0; i < dates.length; i++) {
        await _db.into(_db.occurrences).insert(
          OccurrencesCompanion.insert(
            id: newId(),
            createdAt: now,
            updatedAt: now,
            ruleId: ruleId,
            seq: i + 1,
            dueDate: dates[i].iso,
            amountExpected: Value(amounts[i]),
            currency: input.currency,
          ),
        );
      }
    });
    return accountId;
  }

  /// Кредитная линия: счёт и правило погашения; наступления с суммой
  /// текущего долга создаст планировщик (§5.2).
  Future<String> createCreditLine(CreditLineInput input) async {
    late String accountId;
    await _db.transaction(() async {
      accountId = await _accounts.insertRaw(
        AccountInput(
          name: input.name,
          kind: AccountKind.creditLine,
          currency: input.currency,
          openingBalance: -input.currentDebt,
          creditLimit: input.creditLimit,
          dueDay: input.dueDay,
          minPayment: input.minPayment,
          includeInTotal: false,
        ),
      );
      final start = _creditLineStart(input.dueDay);
      await _rules.insert(
        RuleInput(
          name: input.name,
          kind: RuleKind.creditLinePayment,
          accountId: input.payFromAccountId,
          counterAccountId: accountId,
          currency: input.currency,
          frequency: Frequency.monthly,
          dayOfMonth: input.dueDay,
          startDate: start,
          remindDaysBefore: input.remindDaysBefore,
        ),
      );
    });
    return accountId;
  }

  /// Первый день оплаты кредитной линии: в этом месяце, если ещё не прошёл.
  LocalDate _creditLineStart(int dueDay) {
    final today = LocalDate.today(_clock);
    final thisMonth = LocalDate(today.year, today.month, dueDay);
    return thisMonth >= today ? thisMonth : thisMonth.addMonths(1);
  }

  /// Счёт-пассив поправили (§8.3 «Edit account»): имя правила — как у счёта;
  /// у кредитной линии новый день оплаты — новое расписание (будущие
  /// наступления создаст планировщик). График кредита не трогается: его
  /// суммы — не из правила, а из `createLoan` и пересчёта (§3.4, §4.3).
  Future<void> syncRule(String accountId) async {
    final account = await _accounts.get(accountId);
    final rule = await ruleFor(accountId);
    if (account == null || rule == null) return;
    final dueDay = account.dueDay;
    if (account.kind == AccountKind.creditLine && dueDay != null && dueDay != rule.dayOfMonth) {
      await _rules.update(
        rule.id,
        RuleInput(
          name: account.name,
          kind: rule.kind,
          accountId: rule.accountId,
          counterAccountId: rule.counterAccountId,
          categoryId: rule.categoryId,
          amount: rule.amount,
          currency: rule.currency,
          frequency: rule.frequency,
          interval: rule.interval,
          dayOfMonth: dueDay,
          startDate: _creditLineStart(dueDay),
          endDate: rule.endDate,
          remindDaysBefore: rule.remindDaysBefore,
          remindMinutes: rule.remindMinutes,
          autoPay: rule.autoPay,
          iconKey: rule.iconKey,
          colorKey: rule.colorKey,
        ),
      );
    } else if (rule.name != account.name) {
      await (_db.update(_db.recurringRules)..where((r) => r.id.equals(rule.id)))
          .write(RecurringRulesCompanion(name: Value(account.name), updatedAt: Value(_clock.now())));
    }
  }

  /// Правило, которое гасит этот счёт-пассив.
  Future<Rule?> ruleFor(String accountId) async {
    final row = await (_db.select(_db.recurringRules)
          ..where((r) => r.counterAccountId.equals(accountId) & r.deletedAt.isNull()))
        .getSingleOrNull();
    return row == null ? null : RuleRepository.toRule(row);
  }

  /// Пересчёт графика после досрочного погашения (§4.3): оставшиеся
  /// запланированные платежи — равными долями остатка. Одна транзакция.
  Future<void> recalculateLoan(String accountId, RecalcMode mode) async {
    await _db.transaction(() async {
      final account = await _accounts.get(accountId);
      final rule = await ruleFor(accountId);
      if (account == null || rule == null) return;
      final balance = (await _accounts.balances())[accountId] ?? account.openingBalance;
      final remaining = balance < 0 ? -balance : 0;
      final planned = await (_db.select(_db.occurrences)
            ..where((o) =>
                o.ruleId.equals(rule.id) &
                o.status.equals(OccStatus.planned.db) &
                o.deletedAt.isNull())
            ..orderBy([(o) => OrderingTerm(expression: o.dueDate)]))
          .get();
      final amounts = recalculate(
        remaining: remaining,
        count: planned.length,
        payment: account.monthlyPayment ?? rule.amount ?? 0,
        mode: mode,
      );
      final now = _clock.now();
      for (var i = 0; i < planned.length; i++) {
        final o = planned[i];
        if (i < amounts.length) {
          await (_db.update(_db.occurrences)..where((x) => x.id.equals(o.id)))
              .write(OccurrencesCompanion(amountExpected: Value(amounts[i]), updatedAt: Value(now)));
        } else {
          await (_db.update(_db.occurrences)..where((x) => x.id.equals(o.id)))
              .write(OccurrencesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
        }
      }
      if (amounts.isNotEmpty && mode == RecalcMode.keepTerm) {
        await (_db.update(_db.accounts)..where((a) => a.id.equals(accountId)))
            .write(AccountsCompanion(monthlyPayment: Value(amounts.first), updatedAt: Value(now)));
        await (_db.update(_db.recurringRules)..where((r) => r.id.equals(rule.id)))
            .write(RecurringRulesCompanion(amount: Value(amounts.first), updatedAt: Value(now)));
      }
      if (amounts.length < planned.length) {
        // Срок сократился: конец правила — последнее живое наступление, иначе
        // планировщик вернул бы снятые платежи. Не осталось ни одного —
        // правило на паузе без срока.
        final last = await _db
            .customSelect(
              'SELECT MAX(due_date) AS d FROM occurrences WHERE rule_id = ? AND deleted_at IS NULL',
              variables: [Variable(rule.id)],
            )
            .getSingle();
        final lastDue = last.read<String?>('d');
        await (_db.update(_db.recurringRules)..where((r) => r.id.equals(rule.id))).write(
          lastDue == null
              ? RecurringRulesCompanion(pausedUntil: Value(Rule.pausedForever.iso), updatedAt: Value(now))
              : RecurringRulesCompanion(endDate: Value(lastDue), updatedAt: Value(now)),
        );
      }
    });
  }
}
