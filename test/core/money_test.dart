import 'package:fintech/core/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseAmount', () {
    test('форматы ввода', () {
      expect(parseAmount('1234', 'KGS'), 123400);
      expect(parseAmount('1 234,50', 'KGS'), 123450);
      expect(parseAmount('1 234,5', 'KGS'), 123450);
      expect(parseAmount('1,234.50', 'USD'), 123450);
      expect(parseAmount('1234.5', 'USD'), 123450);
      expect(parseAmount('0,99', 'USD'), 99);
      expect(parseAmount(',5', 'USD'), 50);
      expect(parseAmount('1234.', 'USD'), 123400);
    });

    test('три цифры после разделителя — разделитель групп', () {
      expect(parseAmount('1,234', 'KGS'), 123400);
      expect(parseAmount('1.234.567', 'KGS'), 123456700);
      expect(parseAmount('1,234', 'JPY'), 1234);
    });

    test('лишние знаки после запятой — отказ, а не округление', () {
      expect(parseAmount('12,3456', 'KGS'), isNull);
      expect(parseAmount('12.5', 'JPY'), isNull);
    });

    test('мусор — отказ', () {
      for (final bad in ['', ' ', 'abc', '-5', '1e3', '12a', ',', '.']) {
        expect(parseAmount(bad, 'KGS'), isNull, reason: bad);
      }
    });

    test('слишком большая сумма — отказ', () {
      expect(parseAmount('99999999999999999', 'KGS'), isNull);
    });

    test('иена без дробной части, динар с тремя знаками', () {
      expect(parseAmount('500', 'JPY'), 500);
      expect(parseAmount('1.234', 'KWD'), 1234);
    });
  });

  group('formatAmount', () {
    test('русский: неразрывные пробелы в группах, запятая, знак после', () {
      expect(formatAmount(258431, 'KGS', 'ru'), '2 584,31 сом');
      expect(formatAmount(999, 'USD', 'ru'), '9,99 \$');
      expect(formatAmount(-500000, 'KGS', 'ru'), '−5 000,00 сом');
    });

    test('английский: запятая в группах, точка, \$ перед числом', () {
      expect(formatAmount(258431, 'KGS', 'en'), '2,584.31 som');
      expect(formatAmount(999, 'USD', 'en'), r'$9.99');
      expect(formatAmount(-999, 'USD', 'en'), '−\$9.99');
    });

    test('whole округляет половину вверх', () {
      expect(formatAmount(258450, 'KGS', 'ru', whole: true), '2 585 сом');
      expect(formatAmount(258449, 'KGS', 'ru', whole: true), '2 584 сом');
    });

    test('без знака валюты и с плюсом', () {
      expect(formatAmount(1700, 'KGS', 'ru', symbol: false), '17,00');
      expect(formatAmount(4500000, 'KGS', 'ru', symbol: false, plus: true), '+45 000,00');
      expect(formatAmount(0, 'KGS', 'ru', symbol: false, plus: true), '0,00');
    });

    test('иена без дробной части', () {
      expect(formatAmount(1234567, 'JPY', 'en'), '¥1,234,567');
    });

    test('ноль после округления не отрицательный', () {
      expect(formatAmount(-40, 'KGS', 'ru', whole: true, symbol: false), '0');
    });

    test('части для hero', () {
      final p = amountParts(258431, 'KGS', 'ru');
      expect(p.whole, '2 584');
      expect(p.fraction, ',31');
      expect(p.sign, 'сом');
      expect(p.signBefore, isFalse);
    });
  });

  group('amountToInput', () {
    test('целое без дробной части, дробное — с запятой в русском', () {
      expect(amountToInput(134000, 'KGS', 'ru'), '1340');
      expect(amountToInput(258431, 'KGS', 'ru'), '2584,31');
      expect(amountToInput(258431, 'KGS', 'en'), '2584.31');
      expect(amountToInput(5, 'KGS', 'en'), '0.05');
    });
  });

  group('Money', () {
    test('сложение одной валюты', () {
      expect(const Money(100, 'KGS') + const Money(250, 'KGS'), const Money(350, 'KGS'));
    });

    test('разные валюты не складываются', () {
      expect(() => const Money(100, 'KGS') + const Money(1, 'USD'), throwsArgumentError);
    });
  });

  group('курсы', () {
    // 1 USD = 87,45 сом.
    const usd = 87450000;

    test(r'toBaseMinor: $9.99 → 873,63 сом (половина вверх)', () {
      // 999 × 87,45 = 87 362,55 тыйына → 87 363.
      expect(toBaseMinor(999, 'USD', 'KGS', usd), 87363);
    });

    test('та же валюта — без пересчёта', () {
      expect(toBaseMinor(12345, 'KGS', 'KGS', 1), 12345);
    });

    test('fromBaseMinor обратен toBaseMinor с точностью до единицы', () {
      final base = toBaseMinor(40000, 'USD', 'KGS', usd);
      expect(base, 3498000);
      expect(fromBaseMinor(base, 'USD', 'KGS', usd), 40000);
    });

    test('иена в сомы: разные минимальные единицы', () {
      // 1 JPY = 0,59 сом; 1000 JPY = 590 сом = 59 000 тыйынов.
      expect(toBaseMinor(1000, 'JPY', 'KGS', 590000), 59000);
    });

    test('mulDivRound без переполнения и со знаком', () {
      expect(mulDivRound(1000000000000000, 2500000000, 1000000), 2500000000000000000);
      expect(mulDivRound(-5, 1, 2), -3);
      expect(mulDivRound(5, 1, 2), 3);
    });
  });

  group('parseRateMicro', () {
    test('запятая и точка, до 6 знаков, лишние отбрасываются', () {
      expect(parseRateMicro('87,45'), 87450000);
      expect(parseRateMicro(' 0.011435 '), 11435);
      expect(parseRateMicro('1.23456789'), 1234567);
      expect(parseRateMicro('100'), 100000000);
    });
    test('ноль, минус и мусор — null', () {
      for (final bad in ['', '0', '0,000', '-1', 'abc', '1,2,3', '1e3']) {
        expect(parseRateMicro(bad), isNull, reason: bad);
      }
    });
  });
}
