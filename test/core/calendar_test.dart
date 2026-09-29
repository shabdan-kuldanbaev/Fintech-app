import 'package:fintech/core/calendar.dart';
import 'package:fintech/core/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalDate', () {
    test('parse/iso — туда и обратно', () {
      final d = LocalDate.parse('2026-02-28');
      expect(d, const LocalDate(2026, 2, 28));
      expect(d.iso, '2026-02-28');
      expect(const LocalDate(2026, 9, 5).monthKey, '2026-09');
    });

    test('parse отвергает не-даты', () {
      for (final bad in ['2026-2-28', '2026-02-30', '2026-13-01', '28.02.2026', '']) {
        expect(() => LocalDate.parse(bad), throwsFormatException, reason: bad);
      }
      expect(() => LocalDate.parse('2025-02-29'), throwsFormatException);
      expect(LocalDate.parse('2024-02-29'), const LocalDate(2024, 2, 29));
    });

    test('лексикографический порядок строк совпадает с календарным', () {
      final dates = [
        const LocalDate(2026, 10, 1),
        const LocalDate(2026, 9, 30),
        const LocalDate(2025, 12, 31),
        const LocalDate(2026, 1, 9),
      ];
      final byDate = [...dates]..sort();
      final byString = [...dates]..sort((a, b) => a.iso.compareTo(b.iso));
      expect(byString, byDate);
    });

    test('addDays через конец месяца и года', () {
      expect(const LocalDate(2026, 12, 31).addDays(1), const LocalDate(2027, 1, 1));
      expect(const LocalDate(2024, 2, 28).addDays(1), const LocalDate(2024, 2, 29));
      expect(const LocalDate(2026, 3, 1).addDays(-1), const LocalDate(2026, 2, 28));
    });

    test('addMonths: 31-е прижимается к концу месяца и возвращается', () {
      const jan31 = LocalDate(2026, 1, 31);
      expect(jan31.addMonths(1), const LocalDate(2026, 2, 28));
      expect(jan31.addMonths(2), const LocalDate(2026, 3, 31));
      expect(jan31.addMonths(3), const LocalDate(2026, 4, 30));
      expect(const LocalDate(2024, 1, 31).addMonths(1), const LocalDate(2024, 2, 29));
      expect(jan31.addMonths(-2), const LocalDate(2025, 11, 30));
      expect(jan31.addMonths(12), const LocalDate(2027, 1, 31));
    });

    test('addMonths с якорем: от 28 февраля к 31 марта', () {
      expect(
        const LocalDate(2026, 2, 28).addMonths(1, anchorDay: 31),
        const LocalDate(2026, 3, 31),
      );
    });

    test('daysUntil', () {
      expect(const LocalDate(2026, 9, 25).daysUntil(const LocalDate(2026, 9, 29)), 4);
      expect(const LocalDate(2026, 9, 29).daysUntil(const LocalDate(2026, 9, 25)), -4);
    });

    test('today — локальная дата, а не дата UTC', () {
      // 2026-09-29 20:30 UTC. Где бы ни шёл тест, today совпадает с
      // локальной датой этого момента.
      final instant = DateTime.utc(2026, 9, 29, 20, 30);
      final clock = FakeClock(instant);
      expect(LocalDate.today(clock), LocalDate.of(instant.toLocal()));
    });
  });

  group('MonthPeriod', () {
    test('месяц с 1-го', () {
      final p = MonthPeriod.containing(const LocalDate(2026, 9, 29), 1);
      expect(p.start, const LocalDate(2026, 9, 1));
      expect(p.end, const LocalDate(2026, 10, 1));
    });

    test('месяц с 5-го: до зарплаты и после', () {
      final before = MonthPeriod.containing(const LocalDate(2026, 10, 1), 5);
      expect(before.start, const LocalDate(2026, 9, 5));
      expect(before.end, const LocalDate(2026, 10, 5));
      final on = MonthPeriod.containing(const LocalDate(2026, 10, 5), 5);
      expect(on.start, const LocalDate(2026, 10, 5));
      expect(on.contains(const LocalDate(2026, 11, 4)), isTrue);
      expect(on.contains(const LocalDate(2026, 11, 5)), isFalse);
    });

    test('через Новый год', () {
      final p = MonthPeriod.containing(const LocalDate(2027, 1, 3), 20);
      expect(p.start, const LocalDate(2026, 12, 20));
      expect(p.end, const LocalDate(2027, 1, 20));
      expect(p.shift(-1).start, const LocalDate(2026, 11, 20));
    });
  });
}
