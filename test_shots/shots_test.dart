// Кадры экранов для просмотра глазами (скилл /shots): tool/shots.sh.
// Не входит в `flutter test` (каталог вне test/): пишет PNG в build/shots.
import 'package:fintech/app/router.dart';
import 'package:fintech/features/accounts/domain/account.dart';
import 'package:fintech/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/app_harness.dart';
import '../test/support/demo.dart';
import '../test/support/fonts.dart';
import '../test/support/harness.dart';

typedef Shot = ({String name, String Function(Demo d) location, double keyboard, bool emptyDb});

final List<Shot> shots = [
  (name: 'home', location: (d) => Routes.home, keyboard: 0, emptyDb: false),
  (name: 'home-empty', location: (d) => Routes.home, keyboard: 0, emptyDb: true),
  (name: 'add-expense', location: (d) => Routes.newTxn(), keyboard: 260, emptyDb: false),
  (name: 'add-transfer', location: (d) => Routes.newTxn(kind: TxKind.transfer), keyboard: 260, emptyDb: false),
  (name: 'transactions', location: (d) => Routes.transactions, keyboard: 0, emptyDb: false),
  (name: 'accounts', location: (d) => Routes.accounts, keyboard: 0, emptyDb: false),
  (name: 'account-card', location: (d) => Routes.account(d.card), keyboard: 0, emptyDb: false),
  (name: 'account-savings', location: (d) => Routes.account(d.vacation), keyboard: 0, emptyDb: false),
  (name: 'account-new', location: (d) => Routes.newAccount(AccountKind.card), keyboard: 0, emptyDb: false),
  (name: 'categories', location: (d) => Routes.categories, keyboard: 0, emptyDb: false),
];

void main() {
  setUpAll(loadAppFonts);
  const filter = String.fromEnvironment('SHOTS');

  for (final shot in shots) {
    if (filter.isNotEmpty && !shot.name.contains(filter)) continue;
    for (final lang in ['en', 'ru']) {
      for (final brightness in Brightness.values) {
        for (final size in [iphone, iphoneSe]) {
          final theme = brightness == Brightness.light ? 'light' : 'dark';
          final file = '${shot.name}-$theme-$lang-${size.width.toInt()}';
          testWidgets(file, (tester) async {
            late Harness h;
            late Demo demo;
            await tester.runAsync(() async {
              h = await Harness.create();
              if (!shot.emptyDb) demo = await Demo.seed(h);
            });
            final app = await pumpApp(
              tester,
              h,
              location: shot.emptyDb ? Routes.home : shot.location(demo),
              locale: Locale(lang),
              brightness: brightness,
              size: size,
              keyboard: size == iphone ? shot.keyboard : shot.keyboard * 0.85,
            );
            final overflow = tester.takeException();
            await expectLater(find.byType(MaterialApp), matchesGoldenFile('../build/shots/$file.png'));
            await unpumpApp(tester, app);
            await tester.runAsync(h.dispose);
            expect(overflow, isNull, reason: 'исключение при отрисовке $file');
          });
        }
      }
    }
  }
}
