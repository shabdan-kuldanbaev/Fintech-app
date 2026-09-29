import 'package:fintech/core/calendar.dart';
import 'package:fintech/features/accounts/domain/account.dart';
import 'package:fintech/features/accounts/domain/balances.dart';
import 'package:fintech/features/currencies/domain/converter.dart';
import 'package:fintech/features/currencies/domain/rate.dart';
import 'package:fintech/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

Account acc(String id, AccountKind kind, {String cur = 'KGS', int? limit, bool include = true, bool archived = false}) =>
    Account(id: id, name: id, kind: kind, currency: cur, openingBalance: 0, iconKey: 'x', colorKey: 'mint',
        creditLimit: limit, includeInTotal: include, isArchived: archived);

void main() {
  group('computeTotals (§9.2)', () {
    test('свои деньги — активы в базе; долг и доступно — отдельно', () {
      final t = computeTotals(
        [
          acc('cash', AccountKind.cash),
          acc('usd', AccountKind.cash, cur: 'USD'),
          acc('cl', AccountKind.creditLine, limit: 20000000),
          acc('loan', AccountKind.loan),
          acc('hidden', AccountKind.savings, include: false),
          acc('old', AccountKind.card, archived: true),
        ],
        {'cash': 362000, 'usd': 50000, 'cl': -2400000, 'loan': -516860, 'hidden': 999, 'old': 777},
        const Converter('KGS', {'USD': 87450000}),
      );
      expect(t.ownFunds, 362000 + 4372500);
      expect(t.debt, 2400000 + 516860);
      expect(t.creditAvailable, 17600000);
      expect(t.missingRates, isEmpty);
    });

    test('нет курса — счёт не в сумме, валюта названа', () {
      final t = computeTotals([acc('eur', AccountKind.cash, cur: 'EUR')], {'eur': 100}, const Converter('KGS', {}));
      expect(t.ownFunds, 0);
      expect(t.missingRates, {'EUR'});
    });
  });

  group('репозиторий', () {
    late Harness h;
    setUp(() async => h = await Harness.create());
    tearDown(() => h.dispose());

    test('изменение за месяц учитывает входящие переводы', () async {
      final cash = await h.cashId();
      final card = await h.card(balance: 10000000);
      await h.expense(card, 711900, date: LocalDate.parse('2026-09-10'));
      await h.expense(card, 100, date: LocalDate.parse('2026-08-31'));
      await h.transactions.create(TxnInput(kind: TxKind.transfer, accountId: card, counterAccountId: cash, amount: 500000, date: LocalDate.parse('2026-09-12')));
      final delta = await h.accounts.watchDelta(LocalDate.parse('2026-09-01'), LocalDate.parse('2026-10-01')).first;
      expect(delta[card], -711900 - 500000);
      expect(delta[cash], 500000);
    });

    test('валюту счёта с операциями сменить нельзя; удалить — тоже', () async {
      final card = await h.card();
      await h.expense(card, 1);
      await expectLater(
        h.accounts.update(card, const AccountInput(name: 'Card', kind: AccountKind.card, currency: 'USD')),
        throwsA(isA<AccountValidationError>()),
      );
      await expectLater(h.accounts.delete(card), throwsA(isA<AccountValidationError>()));
      await h.accounts.setArchived(card, true);
      expect((await h.accounts.get(card))!.isArchived, isTrue);
    });

    test('пустой счёт удаляется мягко', () async {
      final card = await h.card();
      await h.accounts.delete(card);
      expect(await h.accounts.get(card), isNull);
      final raw = await h.db.customSelect('SELECT COUNT(*) AS n FROM accounts').getSingle();
      expect(raw.read<int>('n'), 2);
    });

    test('проверки вида: кредитная линия без лимита и дня — ошибка', () async {
      await expectLater(
        h.accounts.create(const AccountInput(name: 'CL', kind: AccountKind.creditLine, currency: 'KGS')),
        throwsA(isA<AccountValidationError>()),
      );
    });

    test('курс сменился — свои деньги пересчитаны, снимки операций нет', () async {
      await h.rates.setRate('USD', 87000000, RateSource.manual);
      final usd = await h.card(currency: 'USD', balance: 10000);
      var conv = await h.rates.converter();
      var t = computeTotals(await h.accounts.all(), await h.accounts.balances(), conv);
      expect(t.ownFunds, 870000);
      await h.rates.setRate('USD', 88000000, RateSource.manual);
      conv = await h.rates.converter();
      t = computeTotals(await h.accounts.all(), await h.accounts.balances(), conv);
      expect(t.ownFunds, 880000);
      expect(usd, isNotEmpty);
    });
  });
}
