// Уведомления перепланируются сами при изменении данных (spec.md §6).
import 'package:fintech/features/notifications/reminder_service.dart';
import 'package:fintech/features/notifications/reminder_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_gateway.dart';
import '../support/harness.dart';

void main() {
  late Harness h;
  late FakeGateway gateway;
  late ReminderSync sync;

  setUp(() async {
    h = await Harness.create();
    gateway = FakeGateway();
    final service = ReminderService(
      rules: h.rules,
      settings: h.settings,
      rates: h.rates,
      clock: h.clock,
      gateway: gateway,
      deviceLanguage: () => 'en',
    );
    sync = ReminderSync(h.db, service, delay: const Duration(milliseconds: 5));
    sync.start();
  });
  tearDown(() async {
    await sync.dispose();
    await h.dispose();
  });

  /// Ждать условие, а не время (CLAUDE.md).
  Future<void> until(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('условие не наступило за 5 с');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test('новое правило — напоминания появляются; оплата — исчезают', () async {
    final card = await h.card(balance: 1000000);
    final rule = await h.rule(accountId: card, start: h.today.addDays(5), remind: const [3, 0]);
    await h.planner.replan();
    final occ = (await h.occurrencesOf(rule)).first;
    await until(() => gateway.scheduled.where((n) => n.payload == occ.id).length == 2);

    await h.rules.payAsExpected(occ.id);
    await until(() => gateway.scheduled.every((n) => n.payload != occ.id));
  });

  test('пачка изменений — один replan', () async {
    final card = await h.card(balance: 1000000);
    await h.rule(accountId: card, start: h.today.addDays(5));
    await h.planner.replan();
    await until(() => gateway.cancelCalls > 0);
    final before = gateway.cancelCalls;
    for (var i = 0; i < 5; i++) {
      await h.rule(name: 'R$i', accountId: card, start: h.today.addDays(6 + i));
    }
    await h.planner.replan();
    await until(() => gateway.scheduled.where((n) => n.title.startsWith('R')).map((n) => n.title).toSet().length == 5);
    expect(gateway.cancelCalls - before, lessThan(3));
  });
}
