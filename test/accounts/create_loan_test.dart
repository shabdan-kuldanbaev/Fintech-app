import 'package:fintech/core/calendar.dart';
import 'package:fintech/features/accounts/domain/account.dart';
import 'package:fintech/features/accounts/domain/loan_math.dart';
import 'package:fintech/features/payments/data/obligation_repository.dart';
import 'package:fintech/features/payments/domain/rule.dart';
import 'package:fintech/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  late Harness h;
  setUp(() async => h = await Harness.create());
  tearDown(() => h.dispose());

  Future<String> simbank({String? from, int months = 2, int total = 516860, int payment = 258431}) =>
      h.obligations.createLoan(LoanInput(
        name: 'Simbank installment', currency: 'KGS', principal: 500000,
        totalPayable: total, monthlyPayment: payment, termMonths: months,
        firstPaymentDate: LocalDate.parse('2026-10-02'), rateBp: 224, ratePeriod: RatePeriod.month,
        payFromAccountId: from,
      ));

  test('кредит: счёт с долгом = итого, правило и весь график сразу (§3.4)', () async {
    final loan = await simbank();
    final a = (await h.accounts.get(loan))!;
    expect(a.kind, AccountKind.loan);
    expect(await h.balance(loan), -516860);
    expect(a.includeInTotal, isFalse);
    final rule = (await h.obligations.ruleFor(loan))!;
    expect(rule.kind, RuleKind.loanPayment);
    expect(rule.endDate!.iso, '2026-11-02');
    final occ = await h.occurrencesOf(rule.id);
    expect(occ.map((o) => o.dueDate.iso), ['2026-10-02', '2026-11-02']);
    expect(occ.map((o) => o.amountExpected), [258431, 258429]);
    expect(occ.fold<int>(0, (s, o) => s + o.amountExpected!), 516860);
    expect((await h.planner.replan()).added, 0, reason: 'планировщик кредит не дополняет');
  });

  test('оплата платежа — перевод на кредит, долг уменьшается', () async {
    final card = await h.card(balance: 1000000);
    final loan = await simbank(from: card);
    final rule = (await h.obligations.ruleFor(loan))!;
    final first = (await h.occurrencesOf(rule.id)).first;
    final tx = await h.rules.payAsExpected(first.id);
    final t = (await h.transactions.get(tx))!;
    expect(t.kind, TxKind.transfer);
    expect(t.counterAccountId, loan);
    expect(await h.balance(loan), -258429);
    expect(await h.balance(card), 1000000 - 258431);
  });

  test('досрочное погашение и пересчёт: срок тот же — платёж меньше', () async {
    final card = await h.card(balance: 5000000);
    final loan = await h.obligations.createLoan(LoanInput(
      name: 'Phone', currency: 'KGS', principal: 1200000, totalPayable: 1200000,
      monthlyPayment: 100000, termMonths: 12, firstPaymentDate: LocalDate.parse('2026-10-10'),
      payFromAccountId: card,
    ));
    await h.transactions.create(TxnInput(kind: TxKind.transfer, accountId: card, counterAccountId: loan, amount: 600000, date: h.today));
    await h.obligations.recalculateLoan(loan, RecalcMode.keepTerm);
    final rule = (await h.obligations.ruleFor(loan))!;
    final occ = await h.occurrencesOf(rule.id);
    expect(occ, hasLength(12));
    expect(occ.fold<int>(0, (s, o) => s + o.amountExpected!), 600000);
    expect(occ.first.amountExpected, 50000);
    expect((await h.accounts.get(loan))!.monthlyPayment, 50000);
  });

  test('пересчёт: платёж тот же — платежей меньше, снятые не возвращаются', () async {
    final card = await h.card(balance: 5000000);
    final loan = await h.obligations.createLoan(LoanInput(
      name: 'Phone', currency: 'KGS', principal: 1200000, totalPayable: 1200000,
      monthlyPayment: 100000, termMonths: 12, firstPaymentDate: LocalDate.parse('2026-10-10'),
      payFromAccountId: card,
    ));
    await h.transactions.create(TxnInput(kind: TxKind.transfer, accountId: card, counterAccountId: loan, amount: 650000, date: h.today));
    await h.obligations.recalculateLoan(loan, RecalcMode.keepPayment);
    await h.planner.replan();
    final rule = (await h.obligations.ruleFor(loan))!;
    final occ = await h.occurrencesOf(rule.id);
    expect(occ.map((o) => o.amountExpected), [100000, 100000, 100000, 100000, 100000, 50000]);
    expect(rule.endDate!.iso, occ.last.dueDate.iso);
  });
}
