import 'package:fintech/features/currencies/domain/rate.dart';
import 'package:fintech/features/payments/data/rule_repository.dart';
import 'package:fintech/features/payments/domain/rule.dart';
import 'package:fintech/features/transactions/data/transaction_repository.dart';
import 'package:fintech/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  late Harness h;
  setUp(() async => h = await Harness.create());
  tearDown(() => h.dispose());

  test('оплата — расход с категорией правила и статус paid (I9)', () async {
    final card = await h.card(balance: 1000000);
    final id = await h.rule(start: h.today, accountId: card);
    await h.planner.replan();
    final occ = (await h.occurrencesOf(id)).first;
    final txId = await h.rules.pay(occ.id, amount: 99900, accountId: card);
    final paid = (await h.rules.occurrence(occ.id))!;
    expect(paid.status, OccStatus.paid);
    expect(paid.transactionId, txId);
    expect(paid.paidAt, isNotNull);
    final t = (await h.transactions.get(txId))!;
    expect(t.kind, TxKind.expense);
    expect(t.categoryId, await h.categoryId('subscriptions'));
    expect(t.occurrenceId, occ.id);
    expect(await h.balance(card), 1000000 - 99900);
  });

  test('ошибка на записи операции — наступление осталось planned (одна транзакция)', () async {
    final usd = await h.card(currency: 'USD');
    final id = await h.rule(start: h.today);
    await h.planner.replan();
    final occ = (await h.occurrencesOf(id)).first;
    await expectLater(h.rules.pay(occ.id, amount: 100, accountId: usd), throwsA(isA<MissingRate>()));
    expect((await h.rules.occurrence(occ.id))!.status, OccStatus.planned);
    expect(await h.transactions.list(const TxnFilter()), isEmpty);
  });

  test('отмена оплаты: операция удалена мягко, наступление снова planned', () async {
    final card = await h.card(balance: 1000000);
    final id = await h.rule(start: h.today, accountId: card);
    await h.planner.replan();
    final occ = (await h.occurrencesOf(id)).first;
    final txId = await h.rules.pay(occ.id, amount: 99900, accountId: card);
    await h.rules.unpay(occ.id);
    expect((await h.rules.occurrence(occ.id))!.status, OccStatus.planned);
    expect(await h.transactions.list(const TxnFilter()), isEmpty);
    expect(await h.transactions.get(txId), isNotNull, reason: 'строка на месте (I2)');
    expect(await h.balance(card), 1000000);
  });

  test('операцию-оплату нельзя удалить мимо отмены оплаты (I9)', () async {
    final card = await h.card(balance: 1000000);
    final id = await h.rule(start: h.today, accountId: card);
    await h.planner.replan();
    final occ = (await h.occurrencesOf(id)).first;
    final txId = await h.rules.pay(occ.id, amount: 99900, accountId: card);
    await expectLater(h.transactions.delete(txId), throwsA(isA<TxnValidationError>()));
  });

  test('пропуск и возврат', () async {
    final id = await h.rule(start: h.today);
    await h.planner.replan();
    final occ = (await h.occurrencesOf(id)).first;
    await h.rules.skip(occ.id);
    expect((await h.rules.occurrence(occ.id))!.status, OccStatus.skipped);
    await expectLater(h.rules.pay(occ.id, amount: 1, accountId: await h.cashId()), throwsA(isA<RuleValidationError>()));
    await h.rules.unskip(occ.id);
    expect((await h.rules.occurrence(occ.id))!.status, OccStatus.planned);
  });

  test('«Pay» по ожидаемой сумме: аренда в долларах со счёта в сомах по курсу', () async {
    await h.rates.setRate('USD', 87000000, RateSource.manual);
    final card = await h.card(balance: 10000000);
    final id = await h.rule(name: 'Rent', kind: RuleKind.other, category: 'housing', currency: 'USD', amount: 40000, start: h.today, accountId: card);
    await h.planner.replan();
    final occ = (await h.occurrencesOf(id)).first;
    final txId = await h.rules.payAsExpected(occ.id);
    final t = (await h.transactions.get(txId))!;
    expect(t.currency, 'KGS');
    expect(t.amount, 3480000, reason: r'$400 × 87 = 34 800 сом');
  });

  test('последняя оплата — подсказка «Last time»', () async {
    final card = await h.card(balance: 1000000);
    final id = await h.rule(name: 'Electricity', kind: RuleKind.utility, category: 'utilities', amount: null, start: h.today, accountId: card);
    await h.planner.replan();
    final occ = (await h.occurrencesOf(id)).first;
    expect(await h.rules.lastPaidAmount(id), isNull);
    await h.rules.pay(occ.id, amount: 134000, accountId: card);
    expect(await h.rules.lastPaidAmount(id), 134000);
    expect((await h.rules.watchLastPaid().first)[id], 134000);
  });
}
