import 'package:flutter/foundation.dart';

import 'currencies.dart';

/// Деньги (spec.md I4, §4.1): целое число минимальных единиц валюты
/// (тыйыны, центы) и код ISO 4217. `double` здесь не живёт: сумма
/// 0,1 + 0,2 в `double` уже не 0,3, а у бухгалтерии округлений «примерно» нет.
@immutable
class Money {
  const Money(this.minor, this.currency);

  final int minor;
  final String currency;

  Money operator +(Money other) {
    _same(other);
    return Money(minor + other.minor, currency);
  }

  Money operator -(Money other) {
    _same(other);
    return Money(minor - other.minor, currency);
  }

  Money operator -() => Money(-minor, currency);

  void _same(Money other) {
    if (other.currency != currency) {
      throw ArgumentError('currency mismatch: $currency vs ${other.currency}');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() => '$minor $currency';
}

/// Наибольшая сумма, которую примет форма: 10¹⁵ минимальных единиц —
/// десять триллионов долларов, с запасом до переполнения `int` при
/// умножении на курс (оно идёт в `BigInt`, но хранится в `int`).
const int maxAmountMinor = 1000000000000000;

final _spaces = RegExp(r'[\s  ]');
final _allowed = RegExp(r'^[0-9.,]+$');

/// Разбор введённой суммы в минимальные единицы [currency] без `double`.
///
/// Принимает `1234`, `1 234,50`, `1,234.50`, `1234.5`. Десятичный
/// разделитель — последний из `.` и `,`, если после него не больше
/// [minorUnits] цифр; ровно три цифры после него при `minorUnits < 3`
/// значат разделитель групп («1,234» — тысяча двести тридцать четыре). Иначе,
/// как и при пустой строке, букве или минусе, — `null`.
int? parseAmount(String text, String currency) {
  final raw = text.replaceAll(_spaces, '');
  if (raw.isEmpty || !_allowed.hasMatch(raw)) return null;
  final digitsOnly = raw.replaceAll(RegExp('[.,]'), '');
  if (digitsOnly.isEmpty) return null;
  final mu = minorUnits(currency);
  final sep = raw.lastIndexOf(RegExp('[.,]'));
  String whole;
  String fraction;
  if (sep < 0) {
    whole = raw;
    fraction = '';
  } else {
    final after = raw.length - sep - 1;
    if (after <= mu) {
      whole = raw.substring(0, sep).replaceAll(RegExp('[.,]'), '');
      fraction = raw.substring(sep + 1);
    } else if (after == 3 && mu < 3) {
      whole = digitsOnly;
      fraction = '';
    } else {
      return null;
    }
  }
  if (whole.isEmpty) whole = '0';
  if (whole.length > 16) return null;
  final value = int.parse(whole) * _pow10(mu) +
      (fraction.isEmpty ? 0 : int.parse(fraction.padRight(mu, '0')));
  return value > maxAmountMinor ? null : value;
}

/// Сумма для поля ввода: без знака валюты и групп, дробная часть — только
/// если она не нулевая («1340», «2584,31»).
String amountToInput(int minor, String currency, String languageCode) {
  final mu = minorUnits(currency);
  final p = _pow10(mu);
  final whole = minor.abs() ~/ p;
  final frac = minor.abs() % p;
  final sign = minor < 0 ? '-' : '';
  if (frac == 0) return '$sign$whole';
  final dec = languageCode == 'ru' ? ',' : '.';
  return '$sign$whole$dec${frac.toString().padLeft(mu, '0')}';
}

/// Сумма по частям — для hero, где дробная часть мельче целой.
@immutable
class AmountParts {
  const AmountParts({
    required this.negative,
    required this.whole,
    required this.fraction,
    required this.sign,
    required this.signBefore,
  });

  final bool negative;

  /// Целая часть с разделителями групп: «2 584».
  final String whole;

  /// Дробная часть с десятичным разделителем («,31») или пустая строка.
  final String fraction;

  /// Знак валюты («сом», «$») или пустая строка.
  final String sign;

  /// Знак стоит перед числом ($9.99).
  final bool signBefore;

  String get number => '${negative ? '−' : ''}$whole$fraction';

  @override
  String toString() {
    if (sign.isEmpty) return number;
    final minus = negative ? '−' : '';
    return signBefore
        ? '$minus$sign$whole$fraction'
        : '$number $sign';
  }
}

/// Раскладка суммы по правилам языка [languageCode]: группы по три через
/// неразрывный пробел и запятая в русском («2 584,31 сом»), запятая и точка
/// в английском («2,584.31 som», «$9.99»). Неразрывные пробелы не дают
/// числу переноситься посередине (spec.md §8.0).
///
/// [whole] — округлить до целых единиц (hero и итоги секций); [symbol] —
/// со знаком валюты; [plus] — «+» перед положительной суммой (доход).
AmountParts amountParts(
  int minor,
  String currency,
  String languageCode, {
  bool whole = false,
  bool symbol = true,
}) {
  final info = currencyInfo(currency);
  final mu = info.minorUnits;
  final p = _pow10(mu);
  final negative = minor < 0;
  var abs = minor.abs();
  final ru = languageCode == 'ru';
  String fraction = '';
  int units;
  if (whole || mu == 0) {
    units = (abs + p ~/ 2) ~/ p;
    if (mu == 0) units = abs;
  } else {
    units = abs ~/ p;
    abs = abs % p;
    fraction = '${ru ? ',' : '.'}${abs.toString().padLeft(mu, '0')}';
  }
  return AmountParts(
    negative: negative && (units != 0 || fraction.replaceAll(RegExp('[^1-9]'), '').isNotEmpty),
    whole: _group(units, ru ? ' ' : ','),
    fraction: fraction,
    sign: symbol ? info.sign(languageCode) : '',
    signBefore: info.prefix && !ru,
  );
}

/// Сумма строкой: `formatAmount(258431, 'KGS', 'ru')` → «2 584,31 сом».
String formatAmount(
  int minor,
  String currency,
  String languageCode, {
  bool whole = false,
  bool symbol = true,
  bool plus = false,
}) {
  final text = amountParts(
    minor,
    currency,
    languageCode,
    whole: whole,
    symbol: symbol,
  ).toString();
  return plus && minor > 0 ? '+$text' : text;
}

String _group(int value, String separator) {
  final s = value.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(separator);
    out.write(s[i]);
  }
  return out.toString();
}

int _pow10(int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}

/// `a × b / c`, округление половины от нуля, без переполнения: произведение
/// считается в `BigInt`.
int mulDivRound(int a, int b, int c) {
  if (c == 0) throw ArgumentError('division by zero');
  final num = BigInt.from(a) * BigInt.from(b);
  final den = BigInt.from(c);
  final negative = (num.isNegative) != (den.isNegative);
  final n = num.abs();
  final d = den.abs();
  final q = (n * BigInt.two + d) ~/ (d * BigInt.two);
  final r = q.toInt();
  return negative ? -r : r;
}

/// Масштаб курса: курс хранится как «единиц базовой валюты за 1 единицу
/// валюты × 10⁶» (`exchange_rates.rate_micro`, spec.md §3.1).
const int rateScale = 1000000;

/// [amount] в минимальных единицах [currency] → минимальные единицы
/// базовой валюты [base] по курсу [rateMicro] (spec.md §4.2).
int toBaseMinor(int amount, String currency, String base, int rateMicro) {
  if (currency == base) return amount;
  return mulDivRound(
    amount * _pow10(minorUnits(base)),
    rateMicro,
    _pow10(minorUnits(currency)) * rateScale,
  );
}

/// Обратное [toBaseMinor]: минимальные единицы базовой → минимальные
/// единицы [currency].
int fromBaseMinor(int baseAmount, String currency, String base, int rateMicro) {
  if (currency == base) return baseAmount;
  return mulDivRound(
    baseAmount * _pow10(minorUnits(currency)),
    rateScale,
    rateMicro * _pow10(minorUnits(base)),
  );
}

/// Курс строкой («87,45», «0.011435») → ×10⁶, без `double` (I4). Больше
/// шести знаков после запятой отбрасываются; ноль и мусор — `null`.
int? parseRateMicro(String text) {
  final t = text.trim().replaceAll(',', '.').replaceAll(RegExp(r'\s'), '');
  final m = RegExp(r'^(\d+)(?:\.(\d{1,6})\d*)?$').firstMatch(t);
  if (m == null) return null;
  final v = int.parse(m.group(1)!) * rateScale + int.parse((m.group(2) ?? '').padRight(6, '0'));
  return v > 0 ? v : null;
}
