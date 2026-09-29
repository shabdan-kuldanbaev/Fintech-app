// Куда ведёт тап по уведомлению (spec.md §6).
import 'package:fintech/app/notification_navigation.dart';
import 'package:fintech/features/notifications/domain/reminder_plan.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  late Harness h;
  late String occurrence;

  setUp(() async {
    h = await Harness.create();
    final card = await h.card(balance: 1000000);
    final rule = await h.rule(accountId: card, start: h.today.addDays(2));
    await h.planner.replan();
    occurrence = (await h.occurrencesOf(rule)).first.id;
  });
  tearDown(() => h.dispose());

  Future<NotificationTarget> target(String payload) => resolveNotificationTarget(payload, h.rules.occurrence);

  test('сводка — вкладка Payments без тоста', () async {
    final t = await target(digestPayload);
    expect(t, isA<OpenPayments>().having((t) => t.alreadyPaid, 'alreadyPaid', isFalse));
  });

  test('запланированное наступление — его экран', () async {
    expect(await target(occurrence), isA<OpenOccurrence>().having((t) => t.id, 'id', occurrence));
  });

  test('уже оплачено, пропущено или нет такого — Payments с «Already paid»', () async {
    await h.rules.payAsExpected(occurrence);
    expect(await target(occurrence), isA<OpenPayments>().having((t) => t.alreadyPaid, 'alreadyPaid', isTrue));
    expect(await target('missing'), isA<OpenPayments>().having((t) => t.alreadyPaid, 'alreadyPaid', isTrue));
  });
}
