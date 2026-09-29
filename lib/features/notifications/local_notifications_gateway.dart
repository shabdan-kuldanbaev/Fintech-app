import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'domain/reminder_plan.dart';
import 'notification_gateway.dart';

/// Шлюз к `flutter_local_notifications` (≥ 19: `androidScheduleMode`
/// обязателен, `uiLocalNotificationDateInterpretation` нет).
class LocalNotificationsGateway implements NotificationGateway {
  LocalNotificationsGateway([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Инициализация без запроса разрешения (§6). [paidTitle] и
  /// [snoozeTitle] — подписи действий на языке приложения.
  Future<void> init({
    required void Function(NotificationResponse response) onResponse,
    required DidReceiveBackgroundNotificationResponseCallback onBackground,
    required String paidTitle,
    required String snoozeTitle,
  }) async {
    if (!Platform.isIOS) return;
    await _plugin.initialize(
      settings: InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              paymentCategoryId,
              actions: [
                DarwinNotificationAction.plain(actionPaid, paidTitle),
                DarwinNotificationAction.plain(actionSnooze, snoozeTitle),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse: onBackground,
    );
  }

  /// Ответ, которым приложение подняли из выключенного состояния.
  Future<NotificationResponse?> launchResponse() async {
    if (!Platform.isIOS) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse;
  }

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> hasPermission() async {
    final options = await _ios?.checkPermissions();
    return options?.isEnabled ?? false;
  }

  @override
  Future<bool> requestPermission() async =>
      await _ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> schedule(PlannedNotification n) => _plugin.zonedSchedule(
    id: n.id,
    title: n.title,
    body: n.body,
    scheduledDate: tz.TZDateTime(tz.local, n.day.year, n.day.month, n.day.day, n.minutes ~/ 60, n.minutes % 60),
    notificationDetails: NotificationDetails(
      iOS: DarwinNotificationDetails(
        categoryIdentifier: n.withActions ? paymentCategoryId : null,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.inexact,
    payload: n.payload,
  );

  @override
  Future<List<int>> pendingIds() async =>
      (await _plugin.pendingNotificationRequests()).map((p) => p.id).toList();
}
