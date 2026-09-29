// Курсы и бюджеты в интерфейсе (spec.md §8.3): «Currencies» подтягивает НБКР
// при открытии, если курсам больше суток; ручной курс; «Set budget».
import 'dart:io';

import 'package:fintech/app/router.dart';
import 'package:fintech/data/rates/nbkr_client.dart';
import 'package:fintech/features/budgets/data/budget_repository.dart';
import 'package:fintech/features/budgets/domain/budget.dart';
import 'package:fintech/features/currencies/domain/rate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fonts.dart';
import '../support/harness.dart';

class _Fixture implements KgsRatesSource {
  int calls = 0;
  @override
  Future<Map<String, int>> fetch() async {
    calls++;
    return parseNbkrDaily(File('test/fixtures/nbkr_daily.xml').readAsStringSync());
  }
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Currencies: курс НБКР при открытии, ручной курс — вручную', (tester) async {
    late Harness h;
    await tester.runAsync(() async {
      h = await Harness.create();
      await h.card(currency: 'USD', balance: 0, name: 'Dollars');
    });
    final source = _Fixture();
    final app = await pumpApp(tester, h, location: Routes.rates, rates: source);
    await settle(tester, frames: 20);
    expect(source.calls, 1, reason: 'курсов ещё не было — загрузка при открытии');
    expect(find.text('1 USD = 87.45 som'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rate-USD')));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, '90');
    await tester.tap(find.text('Save'));
    await settle(tester);
    final rates = (await tester.runAsync(() => h.rates.watchRates().first))!;
    final usd = rates.singleWhere((r) => r.code == 'USD');
    expect((usd.rateMicro, usd.source), (90000000, RateSource.manual));

    await unpumpApp(tester, app);
    await tester.runAsync(h.dispose);
  });

  testWidgets('Budgets: «Set budget» для категории без бюджета', (tester) async {
    late Harness h;
    await tester.runAsync(() async => h = await Harness.create());
    final app = await pumpApp(tester, h, location: Routes.budgets);

    await tester.scrollUntilVisible(find.byKey(const ValueKey('budget-cafe')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('budget-cafe')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('budget-amount')), '5000');
    await tester.tap(find.byKey(const ValueKey('budget-save')));
    await settle(tester);

    final rows = (await tester.runAsync(() => BudgetRepository(h.db, h.clock).all()))!;
    final cafe = (await tester.runAsync(() => h.categoryId('cafe')))!;
    expect(effectiveBudget(rows, cafe, '2026-09')!.amount, 500000);
    expect(find.text('0 of 5,000'), findsOneWidget);

    await unpumpApp(tester, app);
    await tester.runAsync(h.dispose);
  });
}
