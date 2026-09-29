import 'package:flutter/foundation.dart';

import '../../../core/calendar.dart';
import '../../currencies/domain/converter.dart';
import '../../payments/domain/rule.dart';

/// Одно одноразовое уведомление (I11): день и минуты — по местному времени.
@immutable
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.day,
    required this.minutes,
    required this.title,
    required this.body,
    required this.payload,
    this.withActions = false,
  });

  final int id;
  final LocalDate day;

  /// Минуты от полуночи.
  final int minutes;
  final String title;
  final String body;

  /// id наступления или [digestPayload].
  final String payload;

  /// Категория `payment` с действиями «Paid» / «Remind tomorrow» (§6.6).
  final bool withActions;

  DateTime get localTime =>
      DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

  @override
  String toString() => '#$id $day ${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')} $title — $body';
}

/// Тексты уведомлений на языке приложения (ARB, I14).
abstract class ReminderTexts {
  String digestTitle();
  String digestBody(int count, String total);
  String dueToday(String amount);
  String dueTomorrow(String amount);
  String dueIn(int days, String amount);
  String amountNotSet();
  String resumes(String name, LocalDate date);
  String money(int minor, String currency);
}

const String digestPayload = 'digest';

/// iOS хранит не больше 64 ожидающих уведомлений (§6).
const int maxPending = 64;

/// Сводка — id 1..7 (I11).
const int digestDays = 7;

/// На правило — не больше 8 id: `notification_base_id + 0..7`.
const int perRule = 8;

/// Расписание уведомлений (spec.md §6), без I/O.
///
/// [items] — запланированные наступления живых правил (включая просроченные);
/// [nowLocal] — местное время; всё, что не позже него, не планируется.
List<PlannedNotification> planReminders({
  required List<DueItem> items,
  required List<Rule> rules,
  required LocalDate today,
  required DateTime nowLocal,
  required bool digestEnabled,
  required int digestMinutes,
  required int defaultMinutes,
  required Converter converter,
  required ReminderTexts texts,
  Map<String, int> lastPaid = const {},
}) {
  bool future(LocalDate day, int minutes) =>
      DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60).isAfter(nowLocal);

  final result = <PlannedNotification>[];
  final planned = items.where((i) => i.occurrence.status == OccStatus.planned).toList();

  // --- сводка
  if (digestEnabled) {
    for (var d = 0; d < digestDays; d++) {
      final day = today.addDays(d);
      if (!future(day, digestMinutes)) continue;
      final dayItems = planned
          .where((i) => i.occurrence.dueDate == day || (d == 0 && i.occurrence.dueDate < day))
          .toList();
      var total = 0;
      for (final i in dayItems) {
        final amount = i.occurrence.amountExpected ?? lastPaid[i.rule.id] ?? 0;
        total += converter.toBase(amount, i.occurrence.currency) ?? 0;
      }
      final resuming = [
        for (final r in rules)
          if (r.pausedUntil != null && r.pausedUntil!.daysUntil(day) == -3) r,
      ];
      if (dayItems.isEmpty && resuming.isEmpty) continue;
      final lines = [
        if (dayItems.isNotEmpty) texts.digestBody(dayItems.length, texts.money(total, converter.base)),
        for (final r in resuming) texts.resumes(r.name, r.pausedUntil!),
      ];
      result.add(
        PlannedNotification(
          id: 1 + d,
          day: day,
          minutes: digestMinutes,
          title: texts.digestTitle(),
          body: lines.join('\n'),
          payload: digestPayload,
        ),
      );
    }
  }

  // --- по правилам
  final candidates = <(DueItem, LocalDate, int, int)>[];
  for (final i in planned) {
    if (i.occurrence.dueDate < today) continue;
    final minutes = i.rule.remindMinutes ?? defaultMinutes;
    for (final before in i.rule.remindDaysBefore.toSet()) {
      final day = i.occurrence.dueDate.addDays(-before);
      if (!future(day, minutes)) continue;
      candidates.add((i, day, minutes, before));
    }
  }
  candidates.sort((a, b) {
    final byDay = a.$2.compareTo(b.$2);
    if (byDay != 0) return byDay;
    final byMin = a.$3.compareTo(b.$3);
    return byMin != 0 ? byMin : a.$1.rule.id.compareTo(b.$1.rule.id);
  });
  final budget = maxPending - digestDays;
  final used = <String, int>{};
  var count = 0;
  for (final (item, day, minutes, before) in candidates) {
    if (count >= budget) break;
    final k = used[item.rule.id] ?? 0;
    if (k >= perRule) continue;
    used[item.rule.id] = k + 1;
    count++;
    final o = item.occurrence;
    final amount = o.amountExpected == null
        ? texts.amountNotSet()
        : texts.money(o.amountExpected!, o.currency);
    final body = switch (before) {
      0 => texts.dueToday(amount),
      1 => texts.dueTomorrow(amount),
      _ => texts.dueIn(before, amount),
    };
    result.add(
      PlannedNotification(
        id: item.rule.notificationBaseId + k,
        day: day,
        minutes: minutes,
        title: item.rule.name,
        body: body,
        payload: o.id,
        withActions: o.amountExpected != null &&
            item.rule.accountId != null &&
            item.rule.kind != RuleKind.creditLinePayment,
      ),
    );
  }
  return result;
}
