// Сквозной тест этапа 2 (spec.md §11, §13.3): 10 расходов за 3 дня (половина —
// повтором частой операции), доход, перевод между счетами; балансы сходятся
// с §9.1, лента — по дням.
import 'package:fintech/features/transactions/data/transaction_repository.dart';
import 'package:fintech/features/transactions/domain/frequent.dart';
import 'package:fintech/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  test('этап 2: расходы, частые, доход, перевод, балансы', () async {
    final h = await Harness.create();
    addTearDown(h.dispose);
    final cash = await h.cashId();
    final card = await h.card(balance: 0);

    await h.income(card, 4500000, date: h.today.addDays(-2));
    await h.expense(card, 1700, category: 'transport', date: h.today.addDays(-2), note: 'Bus');
    await h.expense(card, 1700, category: 'transport', date: h.today.addDays(-2), note: 'Bus');
    await h.expense(card, 32500, category: 'groceries', date: h.today.addDays(-1));
    await h.expense(card, 124000, category: 'groceries', date: h.today.addDays(-1));
    await h.expense(card, 25000, category: 'taxi', date: h.today);

    // Пять повторов частой операции «Bus · 17» — как чип Quick add.
    final settings = await h.categories.all();
    final excluded = {for (final c in settings) if (c.isSystem) c.id};
    for (var i = 0; i < 5; i++) {
      final txs = await h.transactions.list(const TxnFilter());
      final quick = frequentOps(txs, today: h.today, excludedCategoryIds: excluded);
      expect(quick.first.note, 'Bus');
      await h.transactions.create(quick.first.toInput(h.today));
    }

    await h.transactions.create(TxnInput(
      kind: TxKind.transfer, accountId: card, counterAccountId: cash, amount: 1000000, date: h.today,
    ));

    final txs = await h.transactions.list(const TxnFilter());
    final expenses = txs.where((t) => t.kind == TxKind.expense).toList();
    expect(expenses, hasLength(10));
    expect(expenses.map((t) => t.date).toSet(), hasLength(3));

    final spent = expenses.fold<int>(0, (s, t) => s + t.amount);
    expect(await h.balance(card), 4500000 - spent - 1000000);
    expect(await h.balance(cash), 1000000);
    expect(txs.first.date, h.today, reason: 'лента — новые сверху');
  });
}
