import 'package:fintech/features/accounts/domain/loan_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estimatePayment', () {
    test('рассрочка Simbank: 5 000 сом, 2 месяца, 2,24 % в месяц', () {
      // Скриншот заказчика 2026-09-29: «2 месяца по 2 584,31 с», итого 5 168,60.
      final e = estimateLoan(principal: 500000, months: 2, rateBp: 224);
      expect(e.payment, 258431);
      // Банк округляет итог по-своему: формула даёт 5 168,62.
      expect((e.total - 516860).abs(), lessThanOrEqualTo(5));
    });

    test('годовая ставка делится на 12', () {
      // 100 000 на 12 месяцев под 24 % годовых = 2 % в месяц → 9 455,96.
      expect(
        estimatePayment(
          principal: 10000000,
          months: 12,
          rateBp: 2400,
          period: RatePeriod.year,
        ),
        945596,
      );
      expect(
        estimatePayment(principal: 10000000, months: 12, rateBp: 200),
        945596,
      );
    });

    test('без ставки и при нулевой — равные доли с округлением вверх', () {
      expect(estimatePayment(principal: 1000000, months: 3), 333334);
      expect(estimatePayment(principal: 1000000, months: 3, rateBp: 0), 333334);
      final e = estimateLoan(principal: 1000000, months: 3);
      expect(e.total, 1000000);
    });

    test('вырожденные входы — ноль', () {
      expect(estimatePayment(principal: 0, months: 3, rateBp: 100), 0);
      expect(estimatePayment(principal: 1000, months: 0), 0);
    });
  });

  group('paymentSchedule', () {
    test('сумма графика равна итого тыйын в тыйын', () {
      final s = paymentSchedule(total: 516860, payment: 258431, months: 2);
      expect(s, [258431, 258429]);
      expect(s.reduce((a, b) => a + b), 516860);
    });

    test('рассрочка 0 %: последний платёж меньше', () {
      final s = paymentSchedule(total: 1000000, payment: 333334, months: 3);
      expect(s, [333334, 333334, 333332]);
    });

    test('слишком большой платёж пересчитывается', () {
      final s = paymentSchedule(total: 1000, payment: 900, months: 3);
      expect(s.reduce((a, b) => a + b), 1000);
      expect(s.every((p) => p > 0), isTrue);
    });

    test('paymentForTotal — половина вверх', () {
      expect(paymentForTotal(516860, 2), 258430);
      expect(paymentForTotal(1000001, 2), 500001);
    });
  });

  group('recalculate', () {
    test('keepTerm: тот же срок, платёж меньше, последний добирает', () {
      final s = recalculate(remaining: 1000000, count: 3, payment: 500000, mode: RecalcMode.keepTerm);
      expect(s, [333333, 333333, 333334]);
    });

    test('keepPayment: тот же платёж, платежей меньше', () {
      final s = recalculate(remaining: 1000000, count: 5, payment: 300000, mode: RecalcMode.keepPayment);
      expect(s, [300000, 300000, 300000, 100000]);
    });

    test('долга нет — графика нет', () {
      expect(recalculate(remaining: 0, count: 3, payment: 1, mode: RecalcMode.keepTerm), isEmpty);
    });
  });
}
