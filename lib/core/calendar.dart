import 'package:flutter/foundation.dart';

import 'clock.dart';

/// Календарная дата без времени и часового пояса (spec.md I6, I7).
///
/// Дата платежа — это день, а не момент: «до 25-го» не зависит от того, в
/// каком поясе телефон и который час. Поэтому в базе она лежит строкой
/// `YYYY-MM-DD` ([iso]), а вся арифметика дат — здесь и в
/// `features/payments/domain/schedule.dart`, больше нигде.
///
/// Внутри арифметика идёт через `DateTime.utc`: у UTC нет перехода на летнее
/// время, и «плюс один день» всегда ровно сутки.
@immutable
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day)
    : assert(month >= 1 && month <= 12),
      assert(day >= 1 && day <= 31);

  /// Дата из строки `YYYY-MM-DD`. Любой другой формат — [FormatException].
  factory LocalDate.parse(String iso) {
    final m = _isoPattern.firstMatch(iso);
    if (m == null) throw FormatException('not an ISO date', iso);
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > daysInMonth(y, mo)) {
      throw FormatException('not a calendar date', iso);
    }
    return LocalDate(y, mo, d);
  }

  /// Календарная дата момента [dateTime] в ЕГО представлении: локальный
  /// `DateTime` даёт локальную дату, UTC — дату по UTC.
  factory LocalDate.of(DateTime dateTime) =>
      LocalDate(dateTime.year, dateTime.month, dateTime.day);

  /// Сегодня по локальному календарю пользователя.
  factory LocalDate.today(Clock clock) =>
      LocalDate.of(clock.now().toLocal());

  static final _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  static int daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// `YYYY-MM-DD` — формат хранения; лексикографический порядок строк
  /// совпадает с календарным.
  String get iso =>
      '${year.toString().padLeft(4, '0')}-${_two(month)}-${_two(day)}';

  /// `YYYY-MM` — ключ месяца (`budgets.from_month`).
  String get monthKey => '${year.toString().padLeft(4, '0')}-${_two(month)}';

  /// 1 — понедельник … 7 — воскресенье.
  int get weekday => _utc.weekday;

  LocalDate addDays(int days) => LocalDate.of(_utc.add(Duration(days: days)));

  /// Тот же день через [months] месяцев; если такого дня нет, — последний
  /// день месяца. [anchorDay] — день, к которому стремиться (31-е в
  /// феврале становится 28-м, но в марте снова 31-м: отсчёт всегда от
  /// якоря, а не от предыдущей даты).
  LocalDate addMonths(int months, {int? anchorDay}) {
    final index = year * 12 + (month - 1) + months;
    final y = index ~/ 12;
    final m = index % 12 + 1;
    final want = anchorDay ?? day;
    final dim = daysInMonth(y, m);
    return LocalDate(y, m, want > dim ? dim : want);
  }

  /// Число дней от этой даты до [other]; отрицательное, если [other] раньше.
  int daysUntil(LocalDate other) => other._utc.difference(_utc).inDays;

  /// Полночь этой даты по локальному времени.
  DateTime toLocalDateTime() => DateTime(year, month, day);

  bool isBefore(LocalDate other) => compareTo(other) < 0;
  bool isAfter(LocalDate other) => compareTo(other) > 0;
  bool operator <(LocalDate other) => compareTo(other) < 0;
  bool operator <=(LocalDate other) => compareTo(other) <= 0;
  bool operator >(LocalDate other) => compareTo(other) > 0;
  bool operator >=(LocalDate other) => compareTo(other) >= 0;

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => iso;

  static String _two(int v) => v.toString().padLeft(2, '0');
}

/// Расчётный месяц (`app_settings.home.month_start_day`, spec.md §9.3, §9.7):
/// месяц «с зарплаты до зарплаты». [start] включительно, [end] — нет.
@immutable
class MonthPeriod {
  const MonthPeriod(this.start, this.end);

  /// Период, в который попадает [date], при начале месяца [startDay]
  /// (1..28 — поэтому дню не нужно прижиматься к концу месяца).
  factory MonthPeriod.containing(LocalDate date, int startDay) {
    assert(startDay >= 1 && startDay <= 28);
    final thisMonth = LocalDate(date.year, date.month, startDay);
    final start = date >= thisMonth ? thisMonth : thisMonth.addMonths(-1);
    return MonthPeriod(start, start.addMonths(1));
  }

  final LocalDate start;
  final LocalDate end;

  MonthPeriod shift(int months) =>
      MonthPeriod(start.addMonths(months), end.addMonths(months));

  bool contains(LocalDate date) => date >= start && date < end;

  /// Ключ месяца бюджета `YYYY-MM` — по дате начала периода (§9.4).
  String get monthKey => start.iso.substring(0, 7);

  @override
  bool operator ==(Object other) =>
      other is MonthPeriod && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '[$start, $end)';
}
