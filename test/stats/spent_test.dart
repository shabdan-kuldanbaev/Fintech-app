// «Потрачено», «Доход», «Отложено» (spec.md §9.3, I15) и долг по месяцам.
import 'package:fintech/core/calendar.dart';
import 'package:fintech/features/accounts/domain/account.dart';
import 'package:fintech/features/payments/data/obligation_repository.dart';
import 'package:fintech/features/stats/domain/stats.dart';
import 'package:fintech/features/transactions/data/transaction_repository.dart';
import 'package:fintech/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  late Harness h;
  setUp(() async => h = await Harness.create());
  tearDown(() => h.dispose());

  final period = MonthPeriod.containing(LocalDate.parse('2026-09-29'), 1);

  Future<PeriodStats> stats() async {
    final txs = await h.transactions.list(const TxnFilter());
    final accounts = {for (final a in await h.accounts.watchAll().first) a.id: a};
    final excluded = {for (final c in await h.categories.all()) if (c.isSystem) c.id};
    return periodStats(txs, period: period, accounts: accounts, excluded: excluded);
  }

  test('трата — расходы и переводы на кредит; кредитка, правка баланса, накопления — нет', () async {
    final card = await h.card(balance: 10000000);
    final savings = await h.accounts.create(const AccountInput(
      name: 'Goal', kind: AccountKind.savings, currency: 'KGS', openingBalance: 0,
    ));
    final visa = await h.obligations.createCreditLine(CreditLineInput(
      name: 'Visa', currency: 'KGS', creditLimit: 1000000, dueDay: 10, currentDebt: 100000,
    ));
    final loan = await h.obligations.createLoan(LoanInput(
      name: 'Loan', currency: 'KGS', principal: 100000, totalPayable: 100000, monthlyPayment: 50000,
      termMonths: 2, firstPaymentDate: h.today.addDays(10),
    ));

    await h.expense(card, 30000, category: 'cafe');
    await h.expense(visa, 20000, category: 'groceries'); // покупка по кредитке — трата
    await h.expense(card, 99900, category: 'cafe', date: LocalDate.parse('2026-08-31')); // не этот месяц
    await h.income(card, 500000);
    Future<void> transfer(String from, String to, int amount) => h.transactions.create(TxnInput(
      kind: TxKind.transfer, accountId: from, counterAccountId: to, amount: amount, date: h.today,
    ));
    await transfer(card, loan, 50000); // платёж по кредиту — трата
    await transfer(card, visa, 100000); // погашение кредитки — не трата
    await transfer(card, savings, 70000);
    await transfer(savings, card, 20000);
    await h.transactions.adjustBalance(accountId: card, currentBalance: await h.balance(card),
        targetBalance: await h.balance(card) - 12345, date: h.today);

    final s = await stats();
    expect(s.spent, 30000 + 20000 + 50000);
    expect(s.income, 500000);
    expect(s.saved, 50000);
    expect(s.byCategory.first, isA<MapEntry<String, int>>().having((e) => e.key, 'key', loanPaymentsKey));
    expect({for (final e in s.byCategory) e.key: e.value}, {
      loanPaymentsKey: 50000,
      await h.categoryId('cafe'): 30000,
      await h.categoryId('groceries'): 20000,
    });
  });

  test('долг на начало дня: сейчас минус всё, что датировано позже', () async {
    final card = await h.card(balance: 10000000);
    final visa = await h.obligations.createCreditLine(CreditLineInput(
      name: 'Visa', currency: 'KGS', creditLimit: 1000000, dueDay: 10, currentDebt: 100000,
    ));
    await h.expense(visa, 40000, date: LocalDate.parse('2026-08-15'));
    await h.transactions.create(TxnInput(
      kind: TxKind.transfer, accountId: card, counterAccountId: visa, amount: 30000, date: LocalDate.parse('2026-09-01'), // в сам день точки — ещё не было
    ));
    final series = debtSeries(
      dates: [LocalDate.parse('2026-08-01'), LocalDate.parse('2026-09-01'), LocalDate.parse('2026-09-29')],
      accounts: await h.accounts.watchAll().first,
      balances: await h.accounts.balances(),
      txns: await h.transactions.list(const TxnFilter()),
      converter: await h.rates.converter(),
    );
    expect(series, [100000, 140000, 110000]);
  });
}
