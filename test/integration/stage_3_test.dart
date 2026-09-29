// Сквозной тест этапа 3 (spec.md §11, §13.3) с шлюзом-подделкой: кредит из
// скриншота Simbank (5 000 / 2 мес / 2,24 %), подписка с автосписанием,
// коммуналка без суммы; напоминания за 3 дня и в день в заданное время,
// сводка утром; тап ведёт на наступление, «Paid» из уведомления создаёт
// операцию и уменьшает остаток кредита; «Remind tomorrow»; автосписание.
import 'package:fintech/app/notification_navigation.dart';
import 'package:fintech/features/accounts/domain/loan_math.dart';
import 'package:fintech/features/notifications/domain/reminder_plan.dart';
import 'package:fintech/features/notifications/notification_actions.dart';
import 'package:fintech/features/notifications/notification_gateway.dart';
import 'package:fintech/features/notifications/reminder_service.dart';
import 'package:fintech/features/payments/data/obligation_repository.dart';
import 'package:fintech/features/payments/domain/rule.dart';
import 'package:fintech/features/transactions/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_gateway.dart';
import '../support/harness.dart';

void main() {
  test('этап 3: кредит, подписка, коммуналка, уведомления, оплата, автосписание', () async {
    final h = await Harness.create();
    addTearDown(h.dispose);
    final gateway = FakeGateway();
    final service = ReminderService(
      rules: h.rules,
      settings: h.settings,
      rates: h.rates,
      clock: h.clock,
      gateway: gateway,
      deviceLanguage: () => 'en',
    );
    final card = await h.card(balance: 5000000);

    // --- кредит как в Simbank: форма предлагает 2 584,31 × 2 = 5 168,62
    final estimate = estimateLoan(principal: 500000, months: 2, rateBp: 224);
    expect(estimate.payment, 258431);
    expect(estimate.total, 516862);
    final loan = await h.obligations.createLoan(LoanInput(
      name: 'Simbank loan', currency: 'KGS', principal: 500000, totalPayable: estimate.total,
      monthlyPayment: estimate.payment, termMonths: 2, firstPaymentDate: h.today.addDays(30),
      rateBp: 224, ratePeriod: RatePeriod.month, payFromAccountId: card,
    ));
    final loanRule = (await h.obligations.ruleFor(loan))!;
    final spotify = await h.rule(name: 'Spotify', amount: 20000, accountId: card, start: h.today.addDays(2), autoPay: true);
    final power = await h.rule(name: 'Electricity', kind: RuleKind.utility, amount: null, accountId: card,
        category: 'utilities', start: h.today.addDays(5));
    await h.planner.replan();
    await service.replan();

    final loanOccs = await h.occurrencesOf(loanRule.id);
    expect(loanOccs.map((o) => o.amountExpected), [258431, 258431]);
    expect(await h.balance(loan), -516862);

    // --- напоминания за 3 дня и в день, в 10:00 (умолчание), с действиями
    final first = loanOccs.first;
    final loanReminders = gateway.scheduled.where((n) => n.payload == first.id).toList();
    expect(loanReminders.map((n) => n.day), [first.dueDate.addDays(-3), first.dueDate]);
    expect(loanReminders.every((n) => n.minutes == 600 && n.withActions), isTrue);
    expect(loanReminders.last.body, 'Due today · 2,584.31\u00A0som');

    final powerOcc = (await h.occurrencesOf(power)).first;
    final powerReminders = gateway.scheduled.where((n) => n.payload == powerOcc.id).toList();
    expect(powerReminders, hasLength(2));
    expect(powerReminders.first.body, 'Due in 3 days · amount not set');
    expect(powerReminders.any((n) => n.withActions), isFalse, reason: 'без суммы — только тап');

    // --- сводка утром (9:00) только в дни с платежами: 1 окт. (Spotify) и 4 окт.
    final digests = gateway.scheduled.where((n) => n.payload == digestPayload).toList();
    expect(digests.map((n) => (n.id, n.day, n.minutes)), [
      (3, h.today.addDays(2), 540),
      (6, h.today.addDays(5), 540),
    ]);
    expect(gateway.scheduled.length, lessThanOrEqualTo(maxPending));

    // --- тап по напоминанию ведёт на наступление
    expect(
      await resolveNotificationTarget(first.id, h.rules.occurrence),
      isA<OpenOccurrence>().having((t) => t.id, 'id', first.id),
    );

    // --- «Paid» из уведомления: операция, остаток кредита меньше, напоминания сняты
    await handleNotificationAction(h.db, clock: h.clock, gateway: gateway, deviceLanguage: 'en',
        actionId: actionPaid, payload: first.id);
    expect((await h.rules.occurrence(first.id))!.status, OccStatus.paid);
    expect(await h.balance(loan), -258431);
    expect(await h.balance(card), 5000000 - 258431);
    expect(gateway.scheduled.where((n) => n.payload == first.id), isEmpty);
    // Повторное «Paid» (второе уведомление того же платежа) — ничего.
    await handleNotificationAction(h.db, clock: h.clock, gateway: gateway, deviceLanguage: 'en',
        actionId: actionPaid, payload: first.id);
    expect(await h.balance(loan), -258431);
    expect(
      await resolveNotificationTarget(first.id, h.rules.occurrence),
      isA<OpenPayments>().having((t) => t.alreadyPaid, 'alreadyPaid', isTrue),
    );

    // --- «Remind tomorrow»: одно напоминание на завтра, id base + 7
    await handleNotificationAction(h.db, clock: h.clock, gateway: gateway, deviceLanguage: 'en',
        actionId: actionSnooze, payload: powerOcc.id);
    final powerRule = (await h.rules.rule(power))!;
    final snoozed = gateway.scheduled.where((n) => n.id == powerRule.notificationBaseId + 7).single;
    expect(snoozed.day, h.today.addDays(1));
    expect(snoozed.payload, powerOcc.id);

    // --- автосписание в день платежа
    h.clock.current = DateTime.utc(2026, 10, 1, 6);
    final result = await h.planner.replan();
    expect(result.autoPaid, 1);
    final spotifyOcc = (await h.occurrencesOf(spotify)).first;
    expect(spotifyOcc.status, OccStatus.paid);
    final tx = await h.transactions.list(TxnFilter(accountId: card));
    expect(tx.where((t) => t.occurrenceId == spotifyOcc.id).single.amount, 20000);

    // --- отмена оплаты кредита возвращает долг
    await h.rules.unpay(first.id);
    expect(await h.balance(loan), -516862);
    expect((await h.rules.occurrence(first.id))!.status, OccStatus.planned);
  });
}
