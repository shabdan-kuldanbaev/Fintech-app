// Каждый маршрут §8.2 открывается без исключений (переполнений в том числе)
// на пустой и на заполненной базе, в обеих локалях, на 320 и 393 pt.
import 'package:fintech/app/router.dart';
import 'package:fintech/features/accounts/domain/account.dart';
import 'package:fintech/features/categories/domain/category.dart';
import 'package:fintech/features/payments/domain/rule.dart';
import 'package:fintech/features/transactions/data/transaction_repository.dart';
import 'package:fintech/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/demo.dart';
import '../support/fonts.dart';
import '../support/harness.dart';

typedef RouteCase = ({String name, Future<String> Function(Harness h, Demo? d) location});

final List<RouteCase> cases = [
  (name: 'home', location: (h, d) async => Routes.home),
  (name: 'payments', location: (h, d) async => Routes.payments),
  (name: 'accounts', location: (h, d) async => Routes.accounts),
  (name: 'add-expense', location: (h, d) async => Routes.newTxn()),
  (name: 'add-income', location: (h, d) async => Routes.newTxn(kind: TxKind.income)),
  (name: 'add-transfer', location: (h, d) async => Routes.newTxn(kind: TxKind.transfer)),
  (name: 'transactions', location: (h, d) async => Routes.transactions),
  (name: 'transaction', location: (h, d) async {
    final t = await h.transactions.list(const TxnFilter(limit: 1));
    return t.isEmpty ? Routes.txn('missing') : Routes.txn(t.first.id);
  }),
  (name: 'account', location: (h, d) async => Routes.account(d?.card ?? await h.cashId())),
  (name: 'account-savings', location: (h, d) async => Routes.account(d?.vacation ?? 'missing')),
  (name: 'account-new', location: (h, d) async => Routes.newAccount(AccountKind.savings)),
  (name: 'account-edit', location: (h, d) async => Routes.editAccount(await h.cashId())),
  (name: 'categories', location: (h, d) async => Routes.categories),
  (name: 'category-new', location: (h, d) async => Routes.newCategory(CategoryKind.income)),
  (name: 'category-edit', location: (h, d) async => Routes.category(await h.categoryId('groceries'))),
  (name: 'stats', location: (h, d) async => Routes.stats),
  (name: 'budgets', location: (h, d) async => Routes.budgets),
  (name: 'settings', location: (h, d) async => Routes.settings),
  (name: 'rates', location: (h, d) async => Routes.rates),
  (name: 'backup', location: (h, d) async => Routes.backup),
  (name: 'new-loan', location: (h, d) async => Routes.newLoan),
  (name: 'new-credit-line', location: (h, d) async => Routes.newCreditLine),
  (name: 'new-rule', location: (h, d) async => Routes.newRule(RuleKind.utility)),
  (name: 'rule', location: (h, d) async => Routes.rule(d?.netflix ?? 'missing')),
  (name: 'rule-edit', location: (h, d) async => d == null ? Routes.newRule(RuleKind.other) : Routes.editRule(d.electricity)),
  (name: 'occurrence', location: (h, d) async => Routes.occurrence(d?.internetOccurrence ?? 'missing')),
  (name: 'occurrence-credit', location: (h, d) async => Routes.occurrence(d?.creditLineOccurrence ?? 'missing')),
  (name: 'transaction-paid', location: (h, d) async {
    if (d == null) return Routes.txn('missing');
    return Routes.txn(await h.rules.payAsExpected(d.internetOccurrence));
  }),
  (name: 'account-loan', location: (h, d) async => Routes.account(d?.loan ?? 'missing')),
  (name: 'account-credit', location: (h, d) async => Routes.account(d?.creditLine ?? 'missing')),
];

void main() {
  setUpAll(loadAppFonts);

  for (final c in cases) {
    for (final seeded in [false, true]) {
      for (final lang in ['en', 'ru']) {
        for (final size in [iphoneSe, iphone]) {
          final label = '${c.name} ${seeded ? 'demo' : 'empty'} $lang ${size.width.toInt()}';
          testWidgets(label, (tester) async {
            late Harness h;
            Demo? d;
            late String location;
            await tester.runAsync(() async {
              h = await Harness.create();
              if (seeded) d = await Demo.seed(h);
              location = await c.location(h, d);
            });
            final app = await pumpApp(tester, h, location: location, locale: Locale(lang), size: size);
            expect(tester.takeException(), isNull);
            await unpumpApp(tester, app);
            await tester.runAsync(h.dispose);
          });
        }
      }
    }
  }
}
