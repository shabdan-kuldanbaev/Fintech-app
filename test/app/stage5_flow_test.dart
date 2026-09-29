// Замок и резервная копия в интерфейсе (spec.md §7, §8.3).
import 'dart:async';

import 'package:fintech/app/router.dart';
import 'package:fintech/data/backup/backup_codec.dart';
import 'package:fintech/features/security/app_lock.dart';
import 'package:fintech/features/settings/domain/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/demo.dart';
import '../support/fonts.dart';
import '../support/harness.dart';

void main() {
  setUpAll(loadAppFonts);

  final lockScreen = find.byKey(const ValueKey('lock-screen'));

  testWidgets('замок: холодный старт спрашивает Face ID; отказ — «Try again»; фон дольше минуты — снова', (tester) async {
    late Harness h;
    await tester.runAsync(() async {
      h = await Harness.create();
      await h.settings.write(SettingKeys.lockEnabled, true);
    });
    final auth = FakeAuthenticator(UnlockResult.failed);
    final app = await pumpApp(tester, h, authenticator: auth);
    expect(auth.calls, 1, reason: 'Face ID — сразу при появлении');
    expect(lockScreen, findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-hero')), findsNothing, reason: 'под замком ничего не рисуется');

    auth.result = UnlockResult.unlocked;
    await tester.tap(find.byKey(const ValueKey('lock-unlock')));
    await settle(tester);
    expect(lockScreen, findsNothing);
    expect(find.byKey(const ValueKey('home-hero')), findsOneWidget);

    // В фоне 30 с — не запирать; 61 с — запереть.
    for (final (seconds, locked) in [(30, false), (61, true)]) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      h.clock.advance(Duration(seconds: seconds));
      auth.result = UnlockResult.failed;
      auth.hold = Completer<void>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      // Диалог Face ID ещё открыт — содержимое уже закрыто замком.
      expect(lockScreen, locked ? findsOneWidget : findsNothing, reason: '$seconds с в фоне');
      auth.hold!.complete();
      auth.hold = null;
      await settle(tester);
      expect(lockScreen, locked ? findsOneWidget : findsNothing, reason: '$seconds с в фоне, после Face ID');
    }

    await unpumpApp(tester, app);
    await tester.runAsync(h.dispose);
  });

  testWidgets('копия: экспорт — файл и «Поделиться»; чужой файл — текст ошибки; своя — замена', (tester) async {
    late Harness h;
    await tester.runAsync(() async {
      h = await Harness.create();
      await Demo.seed(h);
    });
    final files = MemoryBackupFiles();
    final app = await pumpApp(tester, h, location: Routes.backup, backupFiles: files);

    await tester.tap(find.byKey(const ValueKey('backup-export')));
    await settle(tester);
    expect(files.files.keys, ['backups/fintech-backup-2026-09-29.json']);
    expect(files.shared, files.files.keys.toList());
    expect(find.text('fintech-backup-2026-09-29.json'), findsOneWidget);
    final exported = decodeBackup(files.files.values.single);
    expect(exported.tables['accounts'], isNotEmpty);

    files.picked = '{"format":"jattap-backup","version":1}';
    await tester.tap(find.byKey(const ValueKey('backup-import')));
    await settle(tester);
    expect(find.byKey(const ValueKey('backup-error')), findsOneWidget);
    expect(find.text('This file is not a backup of this app'), findsOneWidget);
    expect(files.replacedWith, isNull);

    files.picked = files.files.values.single;
    await tester.tap(find.byKey(const ValueKey('backup-import')));
    await settle(tester);
    expect(find.text('Replace all data?'), findsOneWidget);
    await tester.tap(find.text('Replace'));
    await settle(tester);
    expect(files.replacedWith?.tables['transactions']?.length, exported.tables['transactions']!.length);

    await unpumpApp(tester, app);
    await tester.runAsync(h.dispose);
  });
}
