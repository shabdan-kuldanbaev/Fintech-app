import 'package:fintech/core/calendar.dart';
import 'package:fintech/features/notifications/domain/reminder_plan.dart';
import 'package:fintech/features/notifications/reminder_service.dart';
import 'package:fintech/features/currencies/domain/converter.dart';
import 'package:fintech/features/payments/domain/rule.dart';
import 'package:fintech/features/payments/domain/schedule.dart';
import 'package:fintech/features/settings/domain/settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_gateway.dart';
import '../support/harness.dart';

void main() {
  late Harness h;
  late FakeGateway gateway;
  late ReminderService service;
  var device = 'en';

  setUp(() async {
    h = await Harness.create();
    gateway = FakeGateway();
    device = 'en';
    service = ReminderService(
      rules: h.rules,
      settings: h.settings,
      rates: h.rates,
      clock: h.clock,
      gateway: gateway,
      deviceLanguage: () => device,
    );
  });
  tearDown(() => h.dispose());

  // Часы стоят на 2026-09-29 12:00 UTC; в тесте местное время — любое, поэтому
  // сравниваем с тем же «сейчас», что видит планировщик.
  DateTime nowLocal() => h.clock.now().toLocal();

  test('без разрешения — ни одного вызова', () async {
    gateway.permitted = false;
    await h.rule(start: h.today.addDays(3));
    await h.planner.replan();
    expect(await service.replan(), 0);
    expect(gateway.cancelCalls, 0);
    expect(gateway.scheduled, isEmpty);
  });

  test('за 3 дня и в день платежа; id = base + k; payload — наступление', () async {
    final id = await h.rule(start: h.today.addDays(5), remind: const [3, 0], remindMinutes: 600);
    await h.planner.replan();
    await service.replan();
    final rule = (await h.rules.rule(id))!;
    final occ = (await h.occurrencesOf(id)).first;
    final mine = gateway.scheduled.where((n) => n.payload == occ.id).toList();
    expect(mine.map((n) => n.day), [occ.dueDate.addDays(-3), occ.dueDate]);
    expect(mine.map((n) => n.id), [rule.notificationBaseId, rule.notificationBaseId + 1]);
    expect(mine.every((n) => n.minutes == 600), isTrue);
    expect(mine.last.body, startsWith('Due today'));
    expect(mine.first.body, startsWith('Due in 3 days'));
    expect(mine.first.title, 'Netflix');
  });

  test('сводка: id 1..7 только в дни с платежами; просроченные — в сегодняшней', () async {
    await h.rule(name: 'A', start: h.today.addDays(2), remind: const []);
    await h.rule(name: 'B', start: h.today.addDays(2), remind: const []);
    await h.rule(name: 'Old', start: h.today.addDays(-2), remind: const []);
    await h.planner.replan();
    await h.settings.write(SettingKeys.digestMinutes, 23 * 60 + 59);
    await service.replan();
    final digests = gateway.scheduled.where((n) => n.payload == digestPayload).toList();
    for (final d in digests) {
      expect(d.id, inInclusiveRange(1, 7));
    }
    final byDay = {for (final d in digests) d.day: d};
    expect(byDay[h.today.addDays(2)]!.body, startsWith('2 payments'));
    expect(byDay.containsKey(h.today.addDays(1)), isFalse, reason: 'пустая сводка не отправляется');
    final todays = byDay[h.today];
    if (todays != null) expect(todays.body, startsWith('1 payment'), reason: 'просрочка — в сегодняшней');
  });

  test('на правило не больше 8, всего не больше 64, ранние — первыми', () async {
    // 12 еженедельных правил × 13 недель × 2 напоминания — куда больше 64.
    for (var i = 0; i < 12; i++) {
      await h.rule(name: 'W$i', frequency: _weekly, start: h.today.addDays(1 + i % 7));
    }
    await h.planner.replan();
    await service.replan();
    final list = gateway.scheduled;
    expect(list.length, lessThanOrEqualTo(64));
    final perRuleIds = <String, int>{};
    for (final n in list.where((n) => n.payload != digestPayload)) {
      perRuleIds[n.title] = (perRuleIds[n.title] ?? 0) + 1;
    }
    expect(perRuleIds.values.every((c) => c <= 8), isTrue, reason: 'I11: base + 0..7');
    expect(list.map((n) => n.id).toSet().length, list.length, reason: 'id не повторяются');
    final dates = list.where((n) => n.payload != digestPayload).map((n) => n.localTime).toList();
    final latestKept = dates.reduce((a, b) => a.isAfter(b) ? a : b);
    // Всё, что раньше самого позднего поставленного, — поставлено.
    expect(latestKept.isAfter(nowLocal()), isTrue);
  });

  test('прошедшее время не планируется', () {
    final today = LocalDate.of(DateTime(2026, 9, 29));
    final rule = Rule(
      id: 'r', name: 'X', kind: RuleKind.subscription, currency: 'KGS', frequency: _monthly,
      startDate: today, notificationBaseId: 1000, iconKey: 'x', colorKey: 'x', remindMinutes: 600,
      remindDaysBefore: const [0], accountId: 'a',
    );
    final item = DueItem(
      Occurrence(id: 'o', ruleId: 'r', seq: 1, dueDate: today, currency: 'KGS', status: OccStatus.planned, amountExpected: 100),
      rule,
    );
    final at = planReminders(
      items: [item], rules: [rule], today: today, nowLocal: DateTime(2026, 9, 29, 10, 0),
      digestEnabled: false, digestMinutes: 540, defaultMinutes: 600,
      converter: _conv, texts: _texts,
    );
    expect(at, isEmpty, reason: '10:00 == сейчас — уже не будущее');
    final before = planReminders(
      items: [item], rules: [rule], today: today, nowLocal: DateTime(2026, 9, 29, 9, 59),
      digestEnabled: false, digestMinutes: 540, defaultMinutes: 600,
      converter: _conv, texts: _texts,
    );
    expect(before.single.withActions, isTrue);
  });

  test('без суммы: «amount not set» и без действий; кредитка — без действий', () async {
    final card = await h.card(balance: 1000);
    await h.rule(name: 'Electricity', kind: RuleKind.utility, category: 'utilities', amount: null, start: h.today.addDays(4), accountId: card, remind: const [0]);
    await h.planner.replan();
    await service.replan();
    final n = gateway.scheduled.firstWhere((n) => n.title == 'Electricity');
    expect(n.body, contains('amount not set'));
    expect(n.withActions, isFalse);
  });

  test('тексты по-русски, если так выбрано в настройках или в системе', () async {
    await h.rule(start: h.today.addDays(5), remind: const [1]);
    await h.planner.replan();
    await h.settings.write(SettingKeys.locale, 'ru');
    await service.replan();
    expect(gateway.scheduled.firstWhere((n) => n.title == 'Netflix').body, startsWith('Завтра'));
    await h.settings.write(SettingKeys.locale, 'system');
    device = 'ru';
    await service.replan();
    expect(gateway.scheduled.firstWhere((n) => n.title == 'Netflix').body, startsWith('Завтра'));
  });

  test('«Remind tomorrow» — одно напоминание завтра, id base + 7', () async {
    final id = await h.rule(start: h.today.addDays(5));
    await h.planner.replan();
    final occ = (await h.occurrencesOf(id)).first;
    await service.snooze(occ.id);
    final rule = (await h.rules.rule(id))!;
    final n = gateway.scheduled.single;
    expect(n.id, rule.notificationBaseId + 7);
    expect(n.day, LocalDate.of(nowLocal()).addDays(1));
  });
}

const _weekly = Frequency.weekly;
const _monthly = Frequency.monthly;
const _conv = Converter('KGS', {});

final _texts = _PlainTexts();

class _PlainTexts implements ReminderTexts {
  @override
  String amountNotSet() => 'n/a';
  @override
  String digestBody(int count, String total) => '$count · $total';
  @override
  String digestTitle() => 'Digest';
  @override
  String dueIn(int days, String amount) => 'in $days · $amount';
  @override
  String dueToday(String amount) => 'today · $amount';
  @override
  String dueTomorrow(String amount) => 'tomorrow · $amount';
  @override
  String money(int minor, String currency) => '$minor $currency';
  @override
  String resumes(String name, LocalDate date) => '$name $date';
}
