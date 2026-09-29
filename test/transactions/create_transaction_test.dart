import 'package:fintech/core/calendar.dart';
import 'package:fintech/features/categories/domain/category.dart';
import 'package:fintech/features/currencies/domain/rate.dart';
import 'package:fintech/features/transactions/data/transaction_repository.dart';
import 'package:fintech/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  late Harness h;
  setUp(() async => h = await Harness.create());
  tearDown(() => h.dispose());

  test('расход уменьшает баланс, доход увеличивает (§9.1, I3)', () async {
    final cash = await h.cashId();
    await h.income(cash, 4500000);
    await h.expense(cash, 1700);
    await h.expense(cash, 32500);
    expect(await h.balance(cash), 4500000 - 1700 - 32500);
  });

  test('валюта операции — валюта счёта, base_amount — снимок (I8)', () async {
    await h.rates.setRate('USD', 87450000, RateSource.manual);
    final usd = await h.card(currency: 'USD');
    final id = await h.expense(usd, 999, category: 'subscriptions');
    final t = (await h.transactions.get(id))!;
    expect(t.currency, 'USD');
    expect(t.baseAmount, 87363);
    // Курс поменялся — снимок прежний.
    await h.rates.setRate('USD', 90000000, RateSource.manual);
    expect((await h.transactions.get(id))!.baseAmount, 87363);
  });

  test('нет курса — MissingRate, ничего не записано', () async {
    final usd = await h.card(currency: 'USD');
    await expectLater(h.expense(usd, 100), throwsA(isA<MissingRate>()));
    expect(await h.transactions.list(const TxnFilter()), isEmpty);
  });

  test('проверки §3.4: сумма, категория того же вида, счёт', () async {
    final cash = await h.cashId();
    final salary = await h.categoryId('salary');
    Future<void> bad(TxnInput i) =>
        expectLater(h.transactions.create(i), throwsA(isA<TxnValidationError>()));
    await bad(TxnInput(kind: TxKind.expense, accountId: cash, amount: 0, date: h.today, categoryId: salary));
    await bad(TxnInput(kind: TxKind.expense, accountId: cash, amount: 100, date: h.today, categoryId: salary));
    await bad(TxnInput(kind: TxKind.expense, accountId: cash, amount: 100, date: h.today));
    await bad(TxnInput(kind: TxKind.expense, accountId: 'nope', amount: 100, date: h.today, categoryId: salary));
    expect(await h.transactions.list(const TxnFilter()), isEmpty);
  });

  test('запоминается счёт: общий и по категории (§8.3 «Add»)', () async {
    final card = await h.card();
    await h.expense(card, 100, category: 'cafe');
    expect((await h.settings.load()).lastAccountId, card);
    final cats = await h.categories.all();
    expect(byKey(cats, 'cafe').lastAccountId, card);
    expect(byKey(cats, 'groceries').lastAccountId, isNull);
  });

  test('удаление мягкое, Undo возвращает', () async {
    final cash = await h.cashId();
    final id = await h.expense(cash, 500);
    await h.transactions.delete(id);
    expect(await h.balance(cash), 0);
    final raw = await h.db.customSelect('SELECT COUNT(*) AS n FROM transactions').getSingle();
    expect(raw.read<int>('n'), 1, reason: 'строка на месте (I2)');
    await h.transactions.restore(id);
    expect(await h.balance(cash), -500);
  });

  test('корректировка баланса — операция на разницу, вне статистики по ключу', () async {
    final cash = await h.cashId();
    await h.expense(cash, 1000);
    await h.transactions.adjustBalance(accountId: cash, currentBalance: -1000, targetBalance: 5000, date: h.today);
    expect(await h.balance(cash), 5000);
    final txs = await h.transactions.list(const TxnFilter());
    final adj = txs.firstWhere((t) => t.kind == TxKind.income);
    final cat = await h.categories.get(adj.categoryId!);
    expect(cat!.key, adjustmentKey);
    expect(await h.transactions.adjustBalance(accountId: cash, currentBalance: 5000, targetBalance: 5000, date: h.today), isNull);
  });

  test('фильтр ленты: период, счёт, порядок — новые сверху', () async {
    final cash = await h.cashId();
    await h.expense(cash, 1, date: LocalDate.parse('2026-09-01'));
    await h.expense(cash, 2, date: LocalDate.parse('2026-09-28'));
    await h.expense(cash, 3, date: LocalDate.parse('2026-10-01'));
    final sep = await h.transactions.list(
      TxnFilter(from: LocalDate.parse('2026-09-01'), until: LocalDate.parse('2026-10-01')),
    );
    expect(sep.map((t) => t.amount), [2, 1]);
  });
}
