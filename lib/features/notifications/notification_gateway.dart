import 'domain/reminder_plan.dart';

/// Граница с плагином уведомлений: в приложении —
/// `LocalNotificationsGateway`, в тестах — подделка, фиксирующая вызовы.
abstract class NotificationGateway {
  Future<bool> hasPermission();

  /// Системный запрос разрешения — только по действию человека (§6).
  Future<bool> requestPermission();

  Future<void> cancelAll();

  /// Одноразовое уведомление (I11: без `matchDateTimeComponents`).
  Future<void> schedule(PlannedNotification n);

  Future<List<int>> pendingIds();
}

/// Идентификатор категории iOS с действиями «Paid» / «Remind tomorrow».
const String paymentCategoryId = 'payment';
const String actionPaid = 'paid';
const String actionSnooze = 'snooze';
