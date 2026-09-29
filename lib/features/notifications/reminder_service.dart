import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';

import '../../core/calendar.dart';
import '../../core/clock.dart';
import '../../l10n/app_localizations.dart';
import '../currencies/data/rates_repository.dart';
import '../payments/data/rule_repository.dart';
import '../payments/domain/rule.dart';
import '../settings/data/settings_repository.dart';
import '../settings/domain/settings.dart';
import 'domain/reminder_plan.dart';
import 'notification_gateway.dart';
import 'reminder_texts.dart';

/// Перепланирование уведомлений (spec.md §6): всё снять и поставить заново
/// по текущим наступлениям. Без разрешения — ничего.
class ReminderService {
  ReminderService({
    required this.rules,
    required this.settings,
    required this.rates,
    required this.clock,
    required this.gateway,
    required this.deviceLanguage,
  });

  final RuleRepository rules;
  final SettingsRepository settings;
  final RatesRepository rates;
  final Clock clock;
  final NotificationGateway gateway;

  /// Язык устройства — для `locale = system`.
  final String Function() deviceLanguage;

  /// Язык уведомлений: из настроек, «как в системе» — русский или английский.
  static AppLocalizations textsFor(Settings s, String device) => lookupAppLocalizations(
    Locale(switch (s.language) {
      AppLanguage.ru => 'ru',
      AppLanguage.en => 'en',
      AppLanguage.system => device == 'ru' ? 'ru' : 'en',
    }),
  );

  Future<List<PlannedNotification>> plan() async {
    final s = await settings.load();
    final today = LocalDate.today(clock);
    final items = await rules.watchItems(until: today.addDays(400)).first;
    return planReminders(
      items: items,
      rules: await rules.rules(),
      today: today,
      nowLocal: clock.now().toLocal(),
      digestEnabled: s.digestEnabled,
      digestMinutes: s.digestMinutes,
      defaultMinutes: s.defaultReminderMinutes,
      converter: await rates.converter(),
      texts: ArbReminderTexts(textsFor(s, deviceLanguage())),
      lastPaid: await rules.watchLastPaid().first,
    );
  }

  Future<int> replan() async {
    if (!await gateway.hasPermission()) return 0;
    final list = await plan();
    await gateway.cancelAll();
    for (final n in list) {
      await gateway.schedule(n);
    }
    return list.length;
  }

  /// Для фона: ошибка не роняет приложение и не теряется.
  Future<void> replanQuietly() async {
    try {
      await replan();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'notifications'),
      );
    }
  }

  /// «Remind tomorrow» (§6.6): одно напоминание на завтра в то же время,
  /// id `notification_base_id + 7`.
  Future<void> snooze(String occurrenceId) async {
    final occ = await rules.occurrence(occurrenceId);
    if (occ == null || occ.status != OccStatus.planned) return;
    final rule = await rules.rule(occ.ruleId);
    if (rule == null) return;
    final s = await settings.load();
    final now = clock.now().toLocal();
    final l = textsFor(s, deviceLanguage());
    final texts = ArbReminderTexts(l);
    final amount = occ.amountExpected == null
        ? texts.amountNotSet()
        : texts.money(occ.amountExpected!, occ.currency);
    final tomorrow = LocalDate.of(now).addDays(1);
    final days = tomorrow.daysUntil(occ.dueDate);
    await gateway.schedule(
      PlannedNotification(
        id: rule.notificationBaseId + perRule - 1,
        day: tomorrow,
        minutes: now.hour * 60 + now.minute,
        title: rule.name,
        body: days <= 0 ? texts.dueToday(amount) : days == 1 ? texts.dueTomorrow(amount) : texts.dueIn(days, amount),
        payload: occ.id,
        withActions: true,
      ),
    );
  }
}
