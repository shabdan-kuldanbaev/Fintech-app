// Обязательства в интерфейсе (spec.md §8.3): «Pay» в строке Главной с тостом
// «Undo», форма кредита как в Simbank, «Undo payment» на экране операции.
import 'package:fintech/app/router.dart';
import 'package:fintech/app/widgets/toast.dart';
import 'package:fintech/features/accounts/domain/account.dart';
import 'package:fintech/features/payments/domain/rule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/demo.dart';
import '../support/fonts.dart';
import '../support/harness.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<T> run<T>(WidgetTester tester, Future<T> Function() f) async => (await tester.runAsync(f)) as T;

  testWidgets('«Pay» в строке Upcoming платит на месте; «Undo» возвращает долг', (tester) async {
    late Harness h;
    late Demo d;
    late Occurrence first;
    await tester.runAsync(() async {
      h = await Harness.create();
      d = await Demo.seed(h);
      final rule = (await h.obligations.ruleFor(d.loan))!;
      first = (await h.occurrencesOf(rule.id)).first;
    });
    final app = await pumpApp(tester, h);

    await tester.tap(find.byKey(ValueKey('pay-${first.id}')));
    await settle(tester);
    expect(await run(tester, () => h.balance(d.loan)), -258431);
    expect((await run(tester, () => h.rules.occurrence(first.id)))!.status, OccStatus.paid);
    expect(find.byKey(ActionToast.capsuleKey), findsOneWidget);
    expect(find.text('Paid · Simbank loan'), findsOneWidget);
    expect(find.byKey(ValueKey('pay-${first.id}')), findsNothing, reason: 'строка ушла из Upcoming');

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(await run(tester, () => h.balance(d.loan)), -516862);
    expect((await run(tester, () => h.rules.occurrence(first.id)))!.status, OccStatus.planned);

    await unpumpApp(tester, app);
    await tester.runAsync(h.dispose);
  });

  testWidgets('New loan: 5 000, шкала на 2 месяца, 2,24 % → 2 × 2 584,31, счёт и график', (tester) async {
    late Harness h;
    await tester.runAsync(() async {
      h = await Harness.create();
      await h.card(balance: 1000000);
    });
    final app = await pumpApp(tester, h, location: Routes.newLoan);

    await tester.enterText(find.byKey(const ValueKey('amount-field')), '5000');
    await tester.enterText(find.byKey(const ValueKey('loan-rate')), '2.24');
    await settle(tester);
    expect(find.text('12 months'), findsOneWidget);

    // Шкала: медленно вправо на 10 делений (44 pt) плюс порог касания —
    // без броска, чтобы остановилась там, где отпустили.
    final g = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('month-ruler'))));
    for (var i = 0; i < 23; i++) {
      await g.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 400));
    await g.up();
    await settle(tester, frames: 20);
    expect(find.text('2 months'), findsOneWidget);

    final payment = tester.widget<TextField>(find.byKey(const ValueKey('loan-payment'))).controller!.text;
    final total = tester.widget<TextField>(find.byKey(const ValueKey('loan-total'))).controller!.text;
    expect((payment, total), ('2584.31', '5168.62'));

    // Итого по банку — 5 168,60 (§4.3): правка итого пересчитывает платёж.
    await tester.enterText(find.byKey(const ValueKey('loan-total')), '5168.60');
    await settle(tester);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('loan-payment'))).controller!.text, '2584.30');

    await tester.tap(find.byKey(const ValueKey('loan-create')));
    await settle(tester, frames: 20);

    final accounts = await run(tester, () => h.accounts.watchAll().first);
    final loan = accounts.singleWhere((a) => a.kind == AccountKind.loan);
    expect((loan.principal, loan.totalPayable, loan.monthlyPayment, loan.termMonths, loan.rateBp),
        (500000, 516860, 258430, 2, 224));
    expect(await run(tester, () => h.balance(loan.id)), -516860);
    final rule = (await run(tester, () => h.obligations.ruleFor(loan.id)))!;
    final occs = await run(tester, () => h.occurrencesOf(rule.id));
    expect(occs.map((o) => o.amountExpected), [258430, 258430]);
    expect(find.text('Loan opened'), findsOneWidget, reason: 'тост на экране счёта');

    await unpumpApp(tester, app);
    await tester.runAsync(h.dispose);
  });

  testWidgets('«Undo payment» на экране операции: наступление снова planned, тост «Undo» платит заново', (tester) async {
    late Harness h;
    late Demo d;
    late String occId;
    late String txId;
    await tester.runAsync(() async {
      h = await Harness.create();
      d = await Demo.seed(h);
      occId = d.internetOccurrence;
      txId = await h.rules.payAsExpected(occId);
    });
    final app = await pumpApp(tester, h, location: Routes.txn(txId));
    expect(find.textContaining('Payment for Internet · Megaline'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('undo-payment')));
    await settle(tester);
    expect((await run(tester, () => h.rules.occurrence(occId)))!.status, OccStatus.planned);
    expect(find.text('Payment undone · Internet · Megaline'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    final occ = (await run(tester, () => h.rules.occurrence(occId)))!;
    expect(occ.status, OccStatus.paid);
    expect(occ.transactionId, isNot(txId), reason: 'новая операция, старая — soft');

    await unpumpApp(tester, app);
    await tester.runAsync(h.dispose);
  });
}
