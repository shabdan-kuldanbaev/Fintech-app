import '../../../core/calendar.dart';

/// Периодичность правила (`recurring_rules.frequency`).
enum Frequency {
  monthly('monthly'),
  weekly('weekly'),
  yearly('yearly'),
  everyNDays('every_n_days');

  const Frequency(this.db);
  final String db;

  static Frequency fromDb(String value) => values.firstWhere(
    (f) => f.db == value,
    orElse: () => throw ArgumentError.value(value, 'frequency'),
  );
}

/// Параметры расписания правила — ровно то, от чего зависят даты.
class ScheduleSpec {
  const ScheduleSpec({
    required this.frequency,
    required this.start,
    this.interval = 1,
    this.dayOfMonth,
    this.end,
    this.pausedUntil,
  });

  final Frequency frequency;

  /// Первое наступление.
  final LocalDate start;

  /// monthly: каждые n месяцев; weekly: каждые n недель; yearly: каждые n
  /// лет; every_n_days: n дней.
  final int interval;

  /// monthly/yearly: день месяца 1..31; больше дней в месяце — последний
  /// день. `null` — день [start].
  final int? dayOfMonth;

  /// Последнее наступление включительно.
  final LocalDate? end;

  /// Наступлений раньше этой даты нет.
  final LocalDate? pausedUntil;
}

/// Даты наступлений правила в `[from, until]` (spec.md §5.1, I7). Без I/O.
///
/// Месячные даты считаются от якоря — дня месяца, а не от предыдущей даты:
/// 31 января → 28 (29) февраля → 31 марта, день не «уползает». 29 февраля в
/// ежегодном правиле в невисокосный год — 28-е.
List<LocalDate> scheduleDates(
  ScheduleSpec spec, {
  required LocalDate from,
  required LocalDate until,
}) {
  final step = spec.interval < 1 ? 1 : spec.interval;
  final result = <LocalDate>[];
  var lower = spec.start;
  if (spec.pausedUntil != null && spec.pausedUntil! > lower) {
    lower = spec.pausedUntil!;
  }
  if (from > lower) lower = from;
  var upper = until;
  if (spec.end != null && spec.end! < upper) upper = spec.end!;
  if (lower > upper) return result;

  final anchor = spec.dayOfMonth ?? spec.start.day;
  LocalDate at(int k) => switch (spec.frequency) {
    Frequency.monthly => LocalDate(
      spec.start.year,
      spec.start.month,
      1,
    ).addMonths(k * step, anchorDay: anchor),
    Frequency.yearly => LocalDate(
      spec.start.year,
      spec.start.month,
      1,
    ).addMonths(12 * k * step, anchorDay: anchor),
    Frequency.weekly => spec.start.addDays(7 * k * step),
    Frequency.everyNDays => spec.start.addDays(k * step),
  };

  // Первый номер, который может попасть в окно, — без перебора с нуля:
  // у ежедневного правила десятилетней давности это тысячи шагов.
  var k = switch (spec.frequency) {
    Frequency.weekly => spec.start.daysUntil(lower) ~/ (7 * step),
    Frequency.everyNDays => spec.start.daysUntil(lower) ~/ step,
    Frequency.monthly =>
      ((lower.year - spec.start.year) * 12 + lower.month - spec.start.month) ~/
          step,
    Frequency.yearly => (lower.year - spec.start.year) ~/ step,
  };
  k = k < 1 ? 0 : k - 1;
  for (;; k++) {
    final date = at(k);
    if (date > upper) break;
    if (date >= lower && date >= spec.start) result.add(date);
  }
  return result;
}

/// Следующее наступление строго после [after] — для «Next charge» в форме
/// и для старта правила кредитной линии. `null`, если правило кончилось.
LocalDate? nextDateAfter(ScheduleSpec spec, LocalDate after) {
  final dates = scheduleDates(
    spec,
    from: after.addDays(1),
    until: after.addDays(400 * (spec.interval < 1 ? 1 : spec.interval)),
  );
  return dates.isEmpty ? null : dates.first;
}
