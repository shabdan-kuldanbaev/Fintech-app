// «To pay» для Safe to spend (spec.md §9.7).
import 'package:fintech/core/calendar.dart';
import 'package:fintech/features/accounts/domain/account.dart';
import 'package:fintech/features/currencies/domain/rate.dart';
import 'package:fintech/features/payments/domain/planning.dart';
import 'package:fintech/features/payments/domain/rule.dart';
import 'package:fintech/features/payments/data/obligation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  late Harness h;
  late String card;
  // Сегодня 2026-09-29, месяц с 1-го: period_end = 2026-10-01.
  final periodEnd = LocalDate.parse('2026-10-01');

  setUp(() async {
    h = await Harness.create();
    card = await h.card(balance: 10000000);
  });
  tearDown(() => h.dispose());

  Future<int> toPay({LocalDate? end}) async {
    await h.planner.replan();
    final items = await h.rules.watchItems(until: h.today.addDays(92)).first;
    final accounts = {for (final a in await h.accounts.watchAll().first) a.id: a};
    return toPayUntil(
      items,
      periodEnd: end ?? periodEnd,
      lastPaid: await h.rules.watchLastPaid().first,
      converter: await h.rates.converter(),
      inOwnFunds: (id) => accounts[id]?.kind.isAsset == true && accounts[id]!.includeInTotal,
    );
  }

  test('просроченные и до конца периода — да; в сам день period_end — нет', () async {
    await h.rule(name: 'Overdue', amount: 10000, accountId: card, start: h.today.addDays(-3));
    await h.rule(name: 'Tomorrow', amount: 20000, accountId: card, start: h.today.addDays(1));
    await h.rule(name: 'Period end', amount: 40000, accountId: card, start: periodEnd);
    expect(await toPay(), 30000);
  });

  test('погашение кредитной линии не считается: долг уже учтён отдельно', () async {
    // День оплаты — 1..28, поэтому месяц здесь начинается 5-го: 3 окт. < 5 окт.
    await h.obligations.createCreditLine(CreditLineInput(
      name: 'Visa', currency: 'KGS', creditLimit: 1000000, dueDay: 3, currentDebt: 50000, payFromAccountId: card,
    ));
    await h.rule(name: 'Rent', amount: 10000, accountId: card, start: LocalDate.parse('2026-10-03'));
    expect(await toPay(end: LocalDate.parse('2026-10-05')), 10000);
  });

  test('автосписание со счёта вне Own funds — не считается; со своего — считается', () async {
    final hidden = await h.accounts.create(const AccountInput(
      name: 'Hidden', kind: AccountKind.card, currency: 'KGS', openingBalance: 0, includeInTotal: false,
    ));
    await h.rule(name: 'From hidden', amount: 10000, accountId: hidden, start: h.today.addDays(1), autoPay: true);
    await h.rule(name: 'From card', amount: 20000, accountId: card, start: h.today.addDays(1), autoPay: true);
    expect(await toPay(), 20000);
  });

  test('без суммы — по последней оплате; нет оплат — 0; валюта — в базовую', () async {
    final bill = await h.rule(name: 'Bill', kind: RuleKind.utility, amount: null, accountId: card,
        start: h.today.addDays(-30));
    await h.planner.replan();
    final first = (await h.occurrencesOf(bill)).first;
    await h.rules.pay(first.id, amount: 70000, accountId: card, date: h.today.addDays(-30));
    await h.rule(name: 'Never paid', kind: RuleKind.utility, amount: null, accountId: card, start: h.today);
    await h.rates.setRate('USD', 87450000, RateSource.manual);
    await h.rule(name: 'USD', amount: 1000, currency: 'USD', accountId: card, start: h.today);
    // 70 000 (как в прошлый раз) + 0 + 10 $ × 87,45 = 874,50 сом.
    expect(await toPay(), 70000 + 87450);
  });
}
