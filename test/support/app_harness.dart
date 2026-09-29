import 'dart:async';

import 'package:fintech/app/app.dart';
import 'package:fintech/app/providers.dart';
import 'package:fintech/app/router.dart';
import 'package:fintech/core/clock.dart';
import 'package:fintech/data/backup/backup_codec.dart';
import 'package:fintech/data/backup/backup_files.dart';
import 'package:fintech/data/rates/nbkr_client.dart';
import 'package:fintech/features/security/app_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'harness.dart';

/// Face ID в тестах: отвечает [result], считает вызовы.
class FakeAuthenticator implements Authenticator {
  FakeAuthenticator([this.result = UnlockResult.unlocked]);
  UnlockResult result;
  int calls = 0;

  /// Задан — «системный диалог Face ID» открыт, пока его не завершат.
  Completer<void>? hold;

  @override
  Future<UnlockResult> unlock(String reason) async {
    calls++;
    await hold?.future;
    return result;
  }
}

/// Файлы копий в памяти; «выбор файла» отдаёт [picked].
class MemoryBackupFiles implements BackupFileSystem {
  final Map<String, String> files = {};
  final List<String> shared = [];
  String? picked;
  BackupData? replacedWith;

  @override
  Future<String> write(String json, String isoDay) async {
    final path = 'backups/fintech-backup-$isoDay.json';
    files[path] = json;
    return path;
  }

  @override
  Future<List<String>> list() async => files.keys.toList()..sort((a, b) => b.compareTo(a));

  @override
  Future<void> share(String path) async => shared.add(path);

  @override
  Future<String?> pick() async => picked;

  @override
  Future<void> replaceDatabase(BackupData data, Future<void> Function() closeCurrent) async => replacedWith = data;
}

/// Курсы без сети: в тестах НБКР «недоступен», если тест не дал свои.
class OfflineRates implements KgsRatesSource {
  const OfflineRates();
  @override
  Future<Map<String, int>> fetch() async => throw StateError('offline');
}

/// iPhone 15: 393 × 852, статус-бар 59, полоска «домой» 34.
const Size iphone = Size(393, 852);
const Size iphoneSe = Size(320, 568);

/// Приложение целиком поверх базы [h]: роутер на [location], язык, тема,
/// размер экрана с безопасными зонами; [keyboard] — высота системной
/// клавиатуры (0 — закрыта).
class AppUnderTest {
  AppUnderTest(this.container, this.router);
  final ProviderContainer container;
  final GoRouter router;
}

Future<AppUnderTest> pumpApp(
  WidgetTester tester,
  Harness h, {
  String location = Routes.home,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  Size size = iphone,
  double keyboard = 0,
  double dpr = 2,
  KgsRatesSource? rates,
  Authenticator? authenticator,
  BackupFileSystem? backupFiles,
}) async {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = size * dpr;
  final top = size.height > 700 ? 59.0 : 20.0;
  final bottom = size.height > 700 ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top * dpr, bottom: keyboard > 0 ? 0 : bottom * dpr);
  tester.view.viewPadding = FakeViewPadding(top: top * dpr, bottom: bottom * dpr);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * dpr);
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(h.db),
      clockProvider.overrideWithValue(h.clock as Clock),
      kgsRatesSourceProvider.overrideWithValue(rates ?? const OfflineRates()),
      authenticatorProvider.overrideWithValue(authenticator ?? FakeAuthenticator()),
      backupFileSystemProvider.overrideWithValue(backupFiles ?? MemoryBackupFiles()),
    ],
  );
  final router = createRouter(initialLocation: location);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: FintechApp(router: router, locale: locale),
    ),
  );
  await settle(tester);
  return AppUnderTest(container, router);
}

/// Дождаться потоков drift и анимаций без `pumpAndSettle` (курсор поля
/// мигает бесконечно).
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Снять приложение и дать drift закрыть потоки.
Future<void> unpumpApp(WidgetTester tester, AppUnderTest app) async {
  await tester.pumpWidget(const SizedBox.shrink());
  app.container.dispose();
  app.router.dispose();
  await tester.pump(const Duration(milliseconds: 100));
}
