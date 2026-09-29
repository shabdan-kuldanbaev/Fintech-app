import 'package:fintech/features/accounts/domain/account.dart';
import 'package:fintech/features/payments/data/obligation_repository.dart';
import 'package:fintech/features/payments/domain/rule.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  late Harness h;
  setUp(() async => h = await Harness.create());
  tearDown(() => h.dispose());

  test('кредитная линия: счёт, правило, к оплате — текущий долг', () async {
    final card = await h.card(balance: 10000000);
    final cl = await h.obligations.createCreditLine(CreditLineInput(
      name: 'Simbank card', currency: 'KGS', creditLimit: 20000000, dueDay: 15,
      currentDebt: 2400000, minPayment: 240000, payFromAccountId: card,
    ));
    expect((await h.accounts.get(cl))!.kind, AccountKind.creditLine);
    expect(await h.balance(cl), -2400000);
    await h.planner.replan();
    final rule = (await h.obligations.ruleFor(cl))!;
    expect(rule.kind, RuleKind.creditLinePayment);
    expect(rule.startDate.iso, '2026-10-15');
    var occ = await h.occurrencesOf(rule.id);
    expect(occ.first.dueDate.iso, '2026-10-15');
    expect(occ.every((o) => o.amountExpected == 2400000), isTrue);

    // Покупка по карте увеличивает долг — к оплате пересчитывается.
    await h.expense(cl, 50000);
    await h.planner.replan();
    occ = await h.occurrencesOf(rule.id);
    expect(occ.first.amountExpected, 2450000);
  });

  test('погашение кредитки — перевод, не трата (I15)', () async {
    h.clock.current = DateTime.utc(2026, 9, 28, 12);
    final card = await h.card(balance: 10000000);
    final cl = await h.obligations.createCreditLine(CreditLineInput(
      name: 'CL', currency: 'KGS', creditLimit: 20000000, dueDay: 28, currentDebt: 100000, payFromAccountId: card,
    ));
    await h.planner.replan();
    final rule = (await h.obligations.ruleFor(cl))!;
    final occ = (await h.occurrencesOf(rule.id)).first;
    expect(occ.dueDate, h.today, reason: 'день оплаты сегодня — наступление сегодня');
    await h.rules.pay(occ.id, amount: 100000, accountId: card);
    expect(await h.balance(cl), 0);
    await h.planner.replan();
    final next = (await h.occurrencesOf(rule.id)).where((o) => o.status == OccStatus.planned).first;
    expect(next.amountExpected, 0, reason: 'долга нет — «Nothing to pay»');
  });

  AccountInput edited(Account a, {String? name, int? dueDay}) => AccountInput(
    name: name ?? a.name, kind: a.kind, currency: a.currency, openingBalance: a.openingBalance,
    creditLimit: a.creditLimit, dueDay: dueDay ?? a.dueDay, minPayment: a.minPayment, principal: a.principal,
    totalPayable: a.totalPayable, monthlyPayment: a.monthlyPayment, termMonths: a.termMonths, rateBp: a.rateBp,
    ratePeriod: a.ratePeriod, firstPaymentDate: a.firstPaymentDate, includeInTotal: a.includeInTotal,
  );

  test('правка кредитной линии: новый день оплаты и имя — у правила и наступлений', () async {
    final card = await h.card(balance: 10000000);
    final cl = await h.obligations.createCreditLine(CreditLineInput(
      name: 'Visa', currency: 'KGS', creditLimit: 20000000, dueDay: 15, currentDebt: 100000, payFromAccountId: card,
    ));
    await h.planner.replan();
    await h.accounts.update(cl, edited((await h.accounts.get(cl))!, name: 'Visa Gold', dueDay: 5));
    await h.obligations.syncRule(cl);
    await h.planner.replan();
    final rule = (await h.obligations.ruleFor(cl))!;
    expect((rule.name, rule.dayOfMonth), ('Visa Gold', 5));
    final planned = (await h.occurrencesOf(rule.id)).where((o) => o.status == OccStatus.planned).toList();
    expect(planned.first.dueDate.iso, '2026-10-05');
    expect(planned.every((o) => o.dueDate.day == 5), isTrue);
  });

  test('правка кредита: имя правила меняется, график с последним платежом — нет', () async {
    final card = await h.card(balance: 10000000);
    final loan = await h.obligations.createLoan(LoanInput(
      name: 'Loan', currency: 'KGS', principal: 500000, totalPayable: 516860, monthlyPayment: 258431,
      termMonths: 2, firstPaymentDate: h.today.addDays(30), payFromAccountId: card,
    ));
    await h.accounts.update(loan, edited((await h.accounts.get(loan))!, name: 'Simbank loan'));
    await h.obligations.syncRule(loan);
    await h.planner.replan();
    final rule = (await h.obligations.ruleFor(loan))!;
    expect(rule.name, 'Simbank loan');
    expect((await h.occurrencesOf(rule.id)).map((o) => o.amountExpected), [258431, 258429]);
  });
}
