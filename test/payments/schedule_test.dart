import 'package:fintech/core/calendar.dart';
import 'package:fintech/features/payments/domain/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

LocalDate d(String iso) => LocalDate.parse(iso);

List<String> dates(ScheduleSpec spec, String from, String until) =>
    scheduleDates(spec, from: d(from), until: d(until)).map((x) => x.iso).toList();

void main() {
  test('ежемесячно 31-го: конец короткого месяца и возврат к 31-му', () {
    final spec = ScheduleSpec(frequency: Frequency.monthly, start: d('2026-01-31'));
    expect(dates(spec, '2026-01-01', '2026-05-31'), [
      '2026-01-31', '2026-02-28', '2026-03-31', '2026-04-30', '2026-05-31',
    ]);
  });

  test('день месяца отличается от даты старта: первое — не раньше старта', () {
    final spec = ScheduleSpec(
      frequency: Frequency.monthly,
      start: d('2026-01-20'),
      dayOfMonth: 5,
    );
    expect(dates(spec, '2026-01-01', '2026-04-30'), ['2026-02-05', '2026-03-05', '2026-04-05']);
  });

  test('каждые 3 месяца', () {
    final spec = ScheduleSpec(frequency: Frequency.monthly, start: d('2026-01-15'), interval: 3);
    expect(dates(spec, '2026-01-01', '2026-12-31'), ['2026-01-15', '2026-04-15', '2026-07-15', '2026-10-15']);
  });

  test('еженедельно и каждые две недели', () {
    final w = ScheduleSpec(frequency: Frequency.weekly, start: d('2026-09-28'));
    expect(dates(w, '2026-09-29', '2026-10-20'), ['2026-10-05', '2026-10-12', '2026-10-19']);
    final w2 = ScheduleSpec(frequency: Frequency.weekly, start: d('2026-09-28'), interval: 2);
    expect(dates(w2, '2026-09-28', '2026-10-31'), ['2026-09-28', '2026-10-12', '2026-10-26']);
  });

  test('ежегодно 29 февраля', () {
    final spec = ScheduleSpec(frequency: Frequency.yearly, start: d('2024-02-29'));
    expect(dates(spec, '2024-01-01', '2028-12-31'), [
      '2024-02-29', '2025-02-28', '2026-02-28', '2027-02-28', '2028-02-29',
    ]);
  });

  test('каждые N дней', () {
    final spec = ScheduleSpec(frequency: Frequency.everyNDays, start: d('2026-09-01'), interval: 10);
    expect(dates(spec, '2026-09-05', '2026-10-01'), ['2026-09-11', '2026-09-21', '2026-10-01']);
  });

  test('end_date включительно', () {
    final spec = ScheduleSpec(frequency: Frequency.monthly, start: d('2026-09-02'), end: d('2026-10-02'));
    expect(dates(spec, '2026-01-01', '2027-12-31'), ['2026-09-02', '2026-10-02']);
  });

  test('пауза до даты: раньше неё наступлений нет', () {
    final spec = ScheduleSpec(
      frequency: Frequency.monthly,
      start: d('2026-01-10'),
      pausedUntil: d('2026-10-15'),
    );
    expect(dates(spec, '2026-09-01', '2026-12-31'), ['2026-11-10', '2026-12-10']);
  });

  test('окно далеко от старта не требует перебора с нуля и не теряет дат', () {
    final spec = ScheduleSpec(frequency: Frequency.everyNDays, start: d('2000-01-01'), interval: 1);
    final got = dates(spec, '2026-09-29', '2026-10-01');
    expect(got, ['2026-09-29', '2026-09-30', '2026-10-01']);
    final monthly = ScheduleSpec(frequency: Frequency.monthly, start: d('2001-03-31'));
    expect(dates(monthly, '2026-02-01', '2026-03-31'), ['2026-02-28', '2026-03-31']);
  });

  test('nextDateAfter', () {
    final spec = ScheduleSpec(frequency: Frequency.monthly, start: d('2026-01-25'));
    expect(nextDateAfter(spec, d('2026-09-25')), d('2026-10-25'));
    expect(nextDateAfter(spec, d('2026-09-24')), d('2026-09-25'));
    final ended = ScheduleSpec(frequency: Frequency.monthly, start: d('2026-01-25'), end: d('2026-02-25'));
    expect(nextDateAfter(ended, d('2026-03-01')), isNull);
  });

  test('Frequency ↔ строка базы', () {
    for (final f in Frequency.values) {
      expect(Frequency.fromDb(f.db), f);
    }
    expect(() => Frequency.fromDb('daily'), throwsArgumentError);
  });
}
