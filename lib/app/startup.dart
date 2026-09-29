import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';

import '../core/clock.dart';
import '../core/timezone_setup.dart';
import '../data/db/database.dart';
import '../features/settings/data/bootstrap.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';
import 'router.dart';

/// Почему запуск не удался: от этого зависит текст экрана отказа.
enum StartupFailureReason {
  /// Файл базы от сборки с другой `schemaVersion` (§3.2).
  incompatibleDatabase,
  unknown,
}

sealed class StartupResult {
  const StartupResult();
}

final class StartupSuccess extends StartupResult {
  const StartupSuccess({required this.container, required this.router});
  final ProviderContainer container;
  final GoRouter router;
}

final class StartupFailure extends StartupResult {
  const StartupFailure({required this.reason, required this.error});
  final StartupFailureReason reason;
  final Object error;
}

/// Инициализация до первого кадра. **Не бросает никогда**: любой сбой —
/// [StartupFailure], и `runApp` всё равно покажет экран (перенос из Jattap).
///
/// Первый запуск (§3.4) — здесь же: базовая валюта по стране устройства,
/// счёт «Наличные» на языке устройства, категории. Экранов онбординга нет.
Future<StartupResult> runStartup({List<Override> overrides = const []}) async {
  AppDatabase? db;
  try {
    await setupLocalTimezone();
    db = AppDatabase();
    final device = PlatformDispatcher.instance.locale;
    final l10n = lookupAppLocalizations(
      device.languageCode == 'ru' ? const Locale('ru') : const Locale('en'),
    );
    await bootstrapIfNeeded(
      db,
      const SystemClock(),
      countryCode: device.countryCode,
      cashName: l10n.cashDefaultName,
    );
    return StartupSuccess(
      container: ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db), ...overrides],
      ),
      router: createRouter(),
    );
  } catch (error, stack) {
    await _closeQuietly(db);
    return StartupFailure(reason: classifyStartupFailure(error, stack), error: error);
  }
}

/// Файл базы от другой `schemaVersion`: у drift нет своего типа исключения,
/// поэтому две приметы — текст и кадр стека (перенос из Jattap).
StartupFailureReason classifyStartupFailure(Object error, StackTrace? stack) {
  final message = error.toString().toLowerCase();
  final frames = stack?.toString() ?? '';
  return message.contains('strategy for schema updates') ||
          frames.contains('_defaultOnUpdate')
      ? StartupFailureReason.incompatibleDatabase
      : StartupFailureReason.unknown;
}

Future<void> _closeQuietly(AppDatabase? db) async {
  if (db == null) return;
  try {
    await db.close();
  } catch (_) {
    // База, которая не открылась, может и не закрыться — это не та ошибка.
  }
}
