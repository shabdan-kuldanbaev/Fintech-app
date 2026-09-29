import 'package:fintech/features/categories/domain/category.dart';
import 'package:fintech/features/transactions/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  late Harness h;
  setUp(() async => h = await Harness.create());
  tearDown(() => h.dispose());

  test('своя категория встаёт в конец своего вида', () async {
    final id = await h.categories.create(name: 'Bazaar', kind: CategoryKind.expense, iconKey: 'groceries', colorKey: 'mint');
    final cats = (await h.categories.all()).where((c) => c.kind == CategoryKind.expense && !c.isSystem).toList();
    expect(cats.last.id, id);
    expect(cats.last.name, 'Bazaar');
  });

  test('удаление с операциями требует переноса; перенос — одной транзакцией', () async {
    final cash = await h.cashId();
    final bazaar = await h.categories.create(name: 'Bazaar', kind: CategoryKind.expense, iconKey: 'groceries', colorKey: 'mint');
    await h.transactions.create(
      (await h.expenseInput(cash, bazaar)),
    );
    await expectLater(h.categories.delete(bazaar), throwsStateError);
    final groceries = await h.categoryId('groceries');
    await h.categories.delete(bazaar, moveTo: groceries);
    final txs = await h.transactions.list(const TxnFilter());
    expect(txs.single.categoryId, groceries);
    expect(await h.categories.get(bazaar), isNotNull, reason: 'мягкое удаление');
    expect((await h.categories.all()).where((c) => c.id == bazaar), isEmpty);
  });

  test('переименование предустановленной и возврат имени из ARB', () async {
    final g = await h.categoryId('groceries');
    await h.categories.update(g, name: 'Еда', iconKey: 'groceries', colorKey: 'mint');
    expect((await h.categories.get(g))!.name, 'Еда');
    await h.categories.update(g, name: '  ', iconKey: 'groceries', colorKey: 'mint');
    expect((await h.categories.get(g))!.name, isNull);
  });

  test('порядок', () async {
    final all = (await h.categories.all()).where((c) => c.kind == CategoryKind.income && !c.isSystem).map((c) => c.id).toList();
    await h.categories.reorder(all.reversed.toList());
    final after = (await h.categories.all()).where((c) => c.kind == CategoryKind.income && !c.isSystem).map((c) => c.id).toList();
    expect(after, all.reversed.toList());
  });
}
