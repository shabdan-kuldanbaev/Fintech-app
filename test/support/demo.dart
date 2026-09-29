import 'package:fintech/core/calendar.dart';
import 'package:fintech/features/accounts/domain/account.dart';
import 'package:fintech/features/accounts/domain/loan_math.dart';
import 'package:fintech/features/currencies/domain/rate.dart';
import 'package:fintech/features/payments/data/obligation_repository.dart';
import 'package:fintech/features/payments/domain/rule.dart';
import 'package:fintech/features/transactions/domain/transaction.dart';

import 'harness.dart';

/// Демо-данные для кадров и сквозных тестов: день жителя Бишкека
/// (`docs/ux-analysis.md` §7). Сегодня — 2026-09-29.
class Demo {
  Demo._(this.h);
  final Harness h;

  late final String cash;
  late final String card;
  late final String usd;
  late final String vacation;

  /// Кредит из скриншота Simbank: 5 000 сом, 2 месяца, 2,24 %/мес.
  late final String loan;
  late final String creditLine;
  late final String netflix;
  late final String electricity;
  late final String internet;
  late final String internetOccurrence;
  late final String creditLineOccurrence;

  static Future<Demo> seed(Harness h) async {
    final d = Demo._(h);
    await d._seed();
    return d;
  }

  LocalDate day(int daysAgo) => h.today.addDays(-daysAgo);

  Future<void> _seed() async {
    await h.rates.setRate('USD', 87450000, RateSource.nbkr);
    cash = await h.cashId();
    await h.accounts.setOpeningBalance(cash, 362000);
    card = await h.accounts.create(const AccountInput(
      name: 'Simbank', kind: AccountKind.card, currency: 'KGS', openingBalance: 1200000,
    ));
    usd = await h.accounts.create(const AccountInput(
      name: 'USD', kind: AccountKind.cash, currency: 'USD', openingBalance: 50000,
    ));
    vacation = await h.accounts.create(AccountInput(
      name: 'Vacation', kind: AccountKind.savings, currency: 'KGS', openingBalance: 1200000,
      targetAmount: 6000000, targetDate: LocalDate.parse('2027-06-01'),
    ));
    await h.income(card, 4500000, date: day(24));
    for (var i = 0; i < 6; i++) {
      await h.expense(card, 1700, category: 'transport', date: day(i), note: 'Bus');
    }
    await h.expense(card, 1700, category: 'transport', date: day(0), note: 'Bus');
    await h.expense(cash, 35000, category: 'cafe', date: day(0), note: 'Lunch');
    await h.expense(cash, 35000, category: 'cafe', date: day(1), note: 'Lunch');
    await h.expense(cash, 35000, category: 'cafe', date: day(3), note: 'Lunch');
    await h.expense(card, 18000, category: 'cafe', date: day(1), note: 'Coffee');
    await h.expense(card, 18000, category: 'cafe', date: day(2), note: 'Coffee');
    await h.expense(card, 124000, category: 'groceries', date: day(1), note: 'Globus');
    await h.expense(card, 32500, category: 'groceries', date: day(1), note: 'Magazin Yrysky IP Bazarbaeva M.M.');
    await h.expense(card, 25000, category: 'taxi', date: day(2), note: 'Yandex Go');
    await h.expense(cash, 180000, category: 'groceries', date: day(5), note: 'Osh bazaar');
    await h.transactions.create(TxnInput(
      kind: TxKind.transfer, accountId: card, counterAccountId: cash, amount: 1000000, date: day(4), note: 'ATM',
    ));
    await h.transactions.create(TxnInput(
      kind: TxKind.transfer, accountId: card, counterAccountId: cash, amount: 1000000, date: day(12), note: 'ATM',
    ));
    await h.transactions.create(TxnInput(
      kind: TxKind.transfer, accountId: card, counterAccountId: vacation, amount: 500000, date: day(10),
    ));

    loan = await h.obligations.createLoan(LoanInput(
      name: 'Simbank loan', currency: 'KGS', principal: 500000, totalPayable: 516862,
      monthlyPayment: 258431, termMonths: 2, firstPaymentDate: day(-1), rateBp: 224,
      ratePeriod: RatePeriod.month, payFromAccountId: card,
    ));
    creditLine = await h.obligations.createCreditLine(CreditLineInput(
      name: 'Simbank Visa', currency: 'KGS', creditLimit: 20000000, dueDay: 10,
      currentDebt: 2400000, minPayment: 240000, payFromAccountId: card,
    ));
    netflix = await h.rule(name: 'Netflix', amount: 999, currency: 'USD', accountId: card,
        start: day(-12), autoPay: true);
    electricity = await h.rule(name: 'Electricity', kind: RuleKind.utility, amount: null, accountId: card,
        category: 'utilities', start: day(-5));
    internet = await h.rule(name: 'Internet · Megaline', kind: RuleKind.utility, amount: 90000, accountId: card,
        category: 'utilities', start: day(3));
    await h.planner.replan();
    internetOccurrence = (await h.occurrencesOf(internet)).first.id;
    final visaRule = await h.obligations.ruleFor(creditLine);
    creditLineOccurrence = (await h.occurrencesOf(visaRule!.id)).first.id;
  }
}
