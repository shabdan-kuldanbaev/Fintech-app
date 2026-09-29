// Смена базовой валюты (spec.md §4.2): base_amount пересчитан у всех,
// бюджеты пересчитаны, курсы через новую базу, отказ без курса.
import 'package:fintech/features/budgets/data/budget_repository.dart';
import 'package:fintech/features/currencies/data/rates_repository.dart';
import 'package:fintech/features/currencies/domain/rate.dart';
import 'package:fintech/features/transactions/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  late Harness h;
  setUp(() async => h = await Harness.create()); // база KGS
  tearDown(() => h.dispose());

  test('KGS → USD: операции, бюджеты, курсы', () async {
    await h.rates.setRate('USD', 87450000, RateSource.nbkr); // 1 $ = 87,45 сом
    await h.rates.setRate('EUR', 102345600, RateSource.nbkr);
    final som = await h.card(balance: 0);
    final usd = await h.card(currency: 'USD', balance: 0, name: 'USD');
    await h.expense(som, 874500); // 8 745 сом = 100 $
    await h.expense(usd, 1000); // 10 $ = 874,50 сом
    final budgets = BudgetRepository(h.db, h.clock);
    await budgets.set(null, 4372500, '2026-09'); // 43 725 сом = 500 $

    await h.rates.changeBase('USD');

    final c = await h.rates.converter();
    expect(c.base, 'USD');
    expect(c.rates['KGS'], 11435, reason: '1 сом = 1 / 87,45 USD');
    expect(c.rates['EUR'], 1170333);
    final txs = await h.transactions.list(const TxnFilter());
    expect(txs.map((t) => (t.currency, t.amount, t.baseAmount)).toSet(), {('KGS', 874500, 10000), ('USD', 1000, 1000)});
    expect((await budgets.all()).single.amount, 50000);
  });

  test('нет курса новой базы — отказ, ничего не изменилось', () async {
    final som = await h.card(balance: 0);
    await h.expense(som, 10000);
    await expectLater(h.rates.changeBase('EUR'), throwsA(isA<MissingBaseRate>()));
    expect((await h.rates.converter()).base, 'KGS');
    expect((await h.transactions.list(const TxnFilter())).single.baseAmount, 10000);
  });
}
