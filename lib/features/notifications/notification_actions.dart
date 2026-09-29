import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/clock.dart';
import '../../core/timezone_setup.dart';
import '../../data/db/database.dart';
import '../accounts/data/account_repository.dart';
import '../currencies/data/rates_repository.dart';
import '../payments/data/occurrence_planner.dart';
import '../payments/data/rule_repository.dart';
import '../settings/data/settings_repository.dart';
import '../transactions/data/transaction_repository.dart';
import 'local_notifications_gateway.dart';
import 'notification_gateway.dart';
import 'reminder_service.dart';

/// Действие из уведомления (§6.6): «Paid» — оплатить ожидаемой суммой со
/// счёта правила; «Remind tomorrow» — одно напоминание на завтра. Потом —
/// перепланировать. Уже оплачено или удалено — ничего.
Future<void> handleNotificationAction(
  AppDatabase db, {
  required Clock clock,
  required NotificationGateway gateway,
  required String deviceLanguage,
  required String? actionId,
  required String? payload,
}) async {
  if (payload == null || payload.isEmpty) return;
  final settings = SettingsRepository(db);
  final rates = RatesRepository(db, clock);
  final transactions = TransactionRepository(db, clock, rates);
  final rules = RuleRepository(db, clock, settings, transactions, rates);
  final service = ReminderService(
    rules: rules,
    settings: settings,
    rates: rates,
    clock: clock,
    gateway: gateway,
    deviceLanguage: () => deviceLanguage,
  );
  if (actionId == actionPaid) {
    try {
      await rules.payAsExpected(payload);
    } on Exception {
      // Уже оплачено, нет курса или счёта — человек увидит в приложении.
    }
    await OccurrencePlanner(db, clock, rules, AccountRepository(db, clock), rates).replan();
    await service.replan();
  } else if (actionId == actionSnooze) {
    await service.replan();
    await service.snooze(payload);
  }
}

/// Обработчик действия, когда приложение не запущено (§6.6, §12.5): свой
/// изолят, своя база. Проверяется только на устройстве.
@pragma('vm:entry-point')
Future<void> onBackgroundNotificationResponse(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await setupLocalTimezone();
  final db = AppDatabase();
  try {
    await handleNotificationAction(
      db,
      clock: const SystemClock(),
      gateway: LocalNotificationsGateway(),
      deviceLanguage: WidgetsBinding.instance.platformDispatcher.locale.languageCode,
      actionId: response.actionId,
      payload: response.payload,
    );
  } finally {
    await db.close();
  }
}
