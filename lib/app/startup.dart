import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;


import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:go_router/go_router.dart';

import '../core/clock.dart';
import '../core/timezone_setup.dart';
import '../data/db/database.dart';
import '../features/notifications/local_notifications_gateway.dart';
import '../features/notifications/notification_actions.dart';
import '../features/notifications/notification_taps.dart';
import '../features/notifications/reminder_service.dart';
import '../features/settings/data/bootstrap.dart';
import '../features/settings/data/settings_repository.dart';
import '../l10n/app_localizations.dart';
import 'notification_navigation.dart';
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
  const StartupSuccess({required this.container, required this.router, required this.taps});
  final ProviderContainer container;
  final GoRouter router;

  /// Тапы по уведомлениям до того, как роутер в дереве, ждут здесь;
  /// вести по ним начинает [completeStartup].
  final NotificationTaps taps;
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

    // §6: тап приходит либо в колбэк плагина (приложение работает или в
    // фоне), либо в «детали запуска» (холодный старт); оба пути сходятся в
    // `taps`. Действия «Paid» / «Remind tomorrow» выполняются сразу.
    final taps = NotificationTaps();
    final gateway = LocalNotificationsGateway();
    final texts = ReminderService.textsFor(await SettingsRepository(db).load(), device.languageCode);
    final openDb = db;
    void onResponse(NotificationResponse r) {
      final action = r.actionId;
      if (action == null || action.isEmpty) {
        taps.report(r.payload);
        return;
      }
      unawaited(
        handleNotificationAction(
          openDb,
          clock: const SystemClock(),
          gateway: gateway,
          deviceLanguage: device.languageCode,
          actionId: action,
          payload: r.payload,
        ).catchError((Object e, StackTrace s) => FlutterError.reportError(
              FlutterErrorDetails(exception: e, stack: s, library: 'notifications'),
            )),
      );
    }

    await gateway.init(
      onResponse: onResponse,
      onBackground: onBackgroundNotificationResponse,
      paidTitle: texts.notifActionPaid,
      snoozeTitle: texts.notifActionSnooze,
    );
    final launch = await gateway.launchResponse();
    if (launch != null) onResponse(launch);

    return StartupSuccess(
      container: ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationGatewayProvider.overrideWithValue(gateway),
          ...overrides,
        ],
      ),
      router: createRouter(),
      taps: taps,
    );
  } catch (error, stack) {
    await _closeQuietly(db);
    return StartupFailure(reason: classifyStartupFailure(error, stack), error: error);
  }
}

/// После первого кадра успешного запуска: тапы по уведомлениям начинают
/// вести на экраны, наступления и уведомления перепланируются, дальше
/// уведомления следят за данными сами ([ReminderSync]). Ничто из этого не
/// стоит между человеком и первым экраном и не роняет его.
void completeStartup(StartupSuccess success) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final container = success.container;
    success.taps.attach(
      (payload) => unawaited(
        openFromNotification(container: container, router: success.router, payload: payload),
      ),
    );
    container.read(reminderSyncProvider).start();
    unawaited(replanAllQuietly(container.read));
  });
}

/// Наступления (горизонт, автооплата, долг по карте), затем уведомления —
/// при старте и возвращении из фона (§5.2, §6).
Future<void> replanAllQuietly(T Function<T>(ProviderListenable<T>) read) async {
  try {
    await read(occurrencePlannerProvider).replan();
  } catch (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'payments'));
  }
  await read(reminderServiceProvider).replanQuietly();
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
