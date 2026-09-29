import 'package:fintech/app/router.dart';
import 'package:fintech/app/widgets/toast.dart';
import 'package:fintech/features/transactions/data/transaction_repository.dart';
import 'package:fintech/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/demo.dart';
import '../support/fonts.dart';
import '../support/harness.dart';

Future<List<Txn>> all(WidgetTester tester, Harness h) async =>
    (await tester.runAsync(() => h.transactions.list(const TxnFilter())))!;

void main() {
  setUpAll(loadAppFonts);

  testWidgets('«+» → сумма → тап по категории: записано, экран закрыт, тост с Undo', (tester) async {
    late Harness h;
    await tester.runAsync(() async => h = await Harness.create());
    final app = await pumpApp(tester, h);

    await tester.tap(find.byKey(const ValueKey('nav-action')));
    await settle(tester);
    expect(find.byKey(const ValueKey('amount-field')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('amount-field')), '350');
    await tester.tap(find.byKey(const ValueKey('cat-cafe')));
    await settle(tester);

    final txs = await all(tester, h);
    expect(txs, hasLength(1));
    expect(txs.single.amount, 35000);
    expect(txs.single.kind, TxKind.expense);
    expect(find.byKey(const ValueKey('amount-field')), findsNothing, reason: 'экран закрыт');
    expect(find.byKey(ActionToast.capsuleKey), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(await all(tester, h), isEmpty, reason: 'Undo удалил операцию');

    await unpumpApp(tester, app);
    await tester.runAsync(h.dispose);
  });

  testWidgets('без суммы категория не сохраняет и показывает подсказку', (tester) async {
    late Harness h;
    await tester.runAsync(() async => h = await Harness.create());
    final app = await pumpApp(tester, h, location: Routes.newTxn());
    await tester.tap(find.byKey(const ValueKey('cat-groceries')));
    await settle(tester);
    expect(await all(tester, h), isEmpty);
    expect(find.text('Enter the amount first'), findsOneWidget);
    await unpumpApp(tester, app);
    await tester.runAsync(h.dispose);
  });

  testWidgets('чип «Quick add» на Главной записывает операцию одним касанием', (tester) async {
    late Harness h;
    await tester.runAsync(() async {
      h = await Harness.create();
      await Demo.seed(h);
    });
    final before = (await all(tester, h)).length;
    final app = await pumpApp(tester, h);
    final chip = find.textContaining('Bus · 17').first;
    await tester.tap(chip);
    await settle(tester);
    final after = await all(tester, h);
    expect(after.length, before + 1);
    expect(after.first.note, 'Bus');
    expect(after.first.amount, 1700);
    expect(after.first.date, h.today);
    await unpumpApp(tester, app);
    await tester.runAsync(h.dispose);
  });

  testWidgets('категория подставляет свой счёт, если счёт не выбран руками', (tester) async {
    late Harness h;
    late Demo d;
    await tester.runAsync(() async {
      h = await Harness.create();
      d = await Demo.seed(h);
      // «Кафе» в последний раз оплачивали наличными, а последняя операция
      // вообще — по карте: записаться должно с наличных.
      await h.expense(await h.cashId(), 35000, category: 'cafe');
      await h.expense(d.card, 100, category: 'groceries');
    });
    final app = await pumpApp(tester, h, location: Routes.newTxn());
    await tester.enterText(find.byKey(const ValueKey('amount-field')), '120');
    await tester.tap(find.byKey(const ValueKey('cat-cafe')));
    await settle(tester);
    final last = (await all(tester, h)).first;
    expect(last.amount, 12000);
    expect(last.accountId, await tester.runAsync(h.cashId));
    await unpumpApp(tester, app);
    await tester.runAsync(h.dispose);
  });
}
