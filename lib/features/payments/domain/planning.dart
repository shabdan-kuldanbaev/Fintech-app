import 'package:flutter/foundation.dart';

import '../../../core/calendar.dart';
import '../../currencies/domain/converter.dart';
import 'rule.dart';
import 'schedule.dart';

/// Сколько вперёд материализуются наступления (spec.md §5.2): кредит —
/// весь срок, остальное — 92 дня, но не меньше одного будущего.
const int planningHorizonDays = 92;

/// Предел на правило: кредит на 30 лет — 360 платежей.
const int maxOccurrencesPerRule = 360;

/// Новое наступление, которое нужно вставить.
@immutable
class PlannedOccurrence {
  const PlannedOccurrence(this.seq, this.dueDate);
  final int seq;
  final LocalDate dueDate;

  @override
  bool operator ==(Object other) =>
      other is PlannedOccurrence && other.seq == seq && other.dueDate == dueDate;

  @override
  int get hashCode => Object.hash(seq, dueDate);

  @override
  String toString() => '#$seq $dueDate';
}

/// Какие наступления правила [rule] добавить (§5.2 п. 1–2), зная последнее
/// существующее ([lastDue], [lastSeq]; `null` — наступлений ещё нет).
/// Существующие не трогаются (I10): считаем только то, что после них.
List<PlannedOccurrence> occurrencesToAdd(
  Rule rule, {
  required LocalDate today,
  LocalDate? lastDue,
  int lastSeq = 0,
}) {
  final spec = rule.spec;
  final from = lastDue == null ? rule.startDate : lastDue.addDays(1);
  LocalDate until;
  if (rule.kind == RuleKind.loanPayment && rule.endDate != null) {
    until = rule.endDate!;
  } else {
    until = today.addDays(planningHorizonDays);
  }
  var dates = scheduleDates(spec, from: from, until: until);
  if (rule.kind != RuleKind.loanPayment) {
    // Не меньше одного будущего наступления: годовая подписка через
    // полгода тоже должна быть видна в «Rules» и получить напоминание.
    final hasFuture = dates.any((d) => d >= today) ||
        (lastDue != null && lastDue >= today);
    if (!hasFuture) {
      final start = from > today ? from : today;
      final next = nextDateAfter(spec, start.addDays(-1));
      if (next != null) dates = [...dates, next];
    }
  }
  final room = maxOccurrencesPerRule - lastSeq;
  if (room <= 0) return const [];
  return [
    for (var i = 0; i < dates.length && i < room; i++)
      PlannedOccurrence(lastSeq + i + 1, dates[i]),
  ];
}

/// Сумма к оплате наступления для прогноза (§9.7): ожидаемая, иначе —
/// последняя оплаченная этого правила, иначе 0.
int expectedAmount(Occurrence o, {int? lastPaid}) =>
    o.amountExpected ?? lastPaid ?? 0;

/// Сумма правила в пересчёте на месяц (§9.5), в валюте правила; `null` —
/// сумма неизвестна и оплат ещё не было.
int? monthlyEquivalent(Rule rule, {int? lastPaid}) {
  final amount = rule.amount ?? lastPaid;
  if (amount == null) return null;
  final n = rule.interval < 1 ? 1 : rule.interval;
  return switch (rule.frequency) {
    Frequency.monthly => amount ~/ n,
    Frequency.weekly => amount * 52 ~/ (12 * n),
    Frequency.yearly => amount ~/ (12 * n),
    Frequency.everyNDays => amount * 365 ~/ (12 * n),
  };
}

/// «To pay» для Safe to spend (spec.md §9.7), в базовой валюте: `planned`
/// наступления с `due_date < periodEnd` (и просроченные), кроме платежей по
/// кредитной линии и автооплат со счёта вне Own funds ([inOwnFunds]).
int toPayUntil(
  List<DueItem> items, {
  required LocalDate periodEnd,
  required Map<String, int> lastPaid,
  required Converter converter,
  required bool Function(String accountId) inOwnFunds,
}) {
  var sum = 0;
  for (final i in items) {
    final o = i.occurrence;
    if (o.status != OccStatus.planned || o.dueDate >= periodEnd) continue;
    if (i.rule.kind == RuleKind.creditLinePayment) continue;
    final from = i.rule.accountId;
    if (i.rule.autoPay && (from == null || !inOwnFunds(from))) continue;
    sum += converter.toBase(expectedAmount(o, lastPaid: lastPaid[i.rule.id]), o.currency) ?? 0;
  }
  return sum;
}
