import 'notification_gateway.dart';
import 'reminder_service.dart';

/// Разрешение на уведомления спрашивается при первом напоминании у правила
/// (§6), не при запуске. Дали — сразу перепланировать: слежение за данными
/// могло отработать, пока системный диалог был открыт.
Future<void> requestRemindersIfNeeded(
  NotificationGateway gateway,
  ReminderService service,
  List<int> remindDaysBefore,
) async {
  if (remindDaysBefore.isEmpty || await gateway.hasPermission()) return;
  if (await gateway.requestPermission()) await service.replanQuietly();
}
