import 'package:fintech/features/notifications/domain/reminder_plan.dart';
import 'package:fintech/features/notifications/notification_gateway.dart';

/// Шлюз-подделка: фиксирует вызовы (spec.md §13.3).
class FakeGateway implements NotificationGateway {
  FakeGateway({this.permitted = true});

  bool permitted;
  int cancelCalls = 0;
  final List<PlannedNotification> scheduled = [];

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<bool> requestPermission() async => permitted = true;

  @override
  Future<void> cancelAll() async {
    cancelCalls++;
    scheduled.clear();
  }

  @override
  Future<void> schedule(PlannedNotification n) async {
    scheduled.removeWhere((x) => x.id == n.id);
    scheduled.add(n);
  }

  @override
  Future<List<int>> pendingIds() async => scheduled.map((n) => n.id).toList();
}
