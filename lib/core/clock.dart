/// Источник текущего времени. Всегда возвращает UTC (spec.md §9).
abstract class Clock {
  /// Текущее время, `isUtc == true`.
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

/// Управляемые часы для тестов.
class FakeClock implements Clock {
  FakeClock(DateTime start) : _now = start.toUtc();

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration duration) => _now = _now.add(duration);

  set current(DateTime value) => _now = value.toUtc();
}
