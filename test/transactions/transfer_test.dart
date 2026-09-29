import 'package:fintech/features/currencies/domain/rate.dart';
import 'package:fintech/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  late Harness h;
  setUp(() async => h = await Harness.create());
  tearDown(() => h.dispose());

  test('перевод в одной валюте: counter_amount = amount', () async {
    final cash = await h.cashId();
    final card = await h.card(balance: 1000000);
    await h.transactions.create(TxnInput(
      kind: TxKind.transfer, accountId: card, counterAccountId: cash, amount: 1000000, date: h.today,
    ));
    expect(await h.balance(card), 0);
    expect(await h.balance(cash), 1000000);
  });

  test('перевод в другую валюту требует сумму зачисления', () async {
    await h.rates.setRate('USD', 87450000, RateSource.manual);
    final usd = await h.card(currency: 'USD', name: 'USD cash');
    final card = await h.card(balance: 3500000);
    await expectLater(
      h.transactions.create(TxnInput(kind: TxKind.transfer, accountId: card, counterAccountId: usd, amount: 3498000, date: h.today)),
      throwsA(isA<TxnValidationError>()),
    );
    await h.transactions.create(TxnInput(
      kind: TxKind.transfer, accountId: card, counterAccountId: usd, amount: 3498000, counterAmount: 40000, date: h.today,
    ));
    expect(await h.balance(usd), 40000);
    expect(await h.balance(card), 2000);
  });

  test('перевод на тот же счёт — ошибка', () async {
    final cash = await h.cashId();
    await expectLater(
      h.transactions.create(TxnInput(kind: TxKind.transfer, accountId: cash, counterAccountId: cash, amount: 1, date: h.today)),
      throwsA(isA<TxnValidationError>()),
    );
  });
}
