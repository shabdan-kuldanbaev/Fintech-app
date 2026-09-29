import 'package:flutter/foundation.dart';

import '../../../core/money.dart';

/// Пересчёт по текущим курсам (spec.md §4.2). Курс — единиц базовой валюты
/// за 1 единицу валюты × 10⁶. Нет курса — `null`, а не ноль и не 1:1.
@immutable
class Converter {
  const Converter(this.base, this.rates);

  final String base;

  /// code → rate_micro.
  final Map<String, int> rates;

  bool has(String currency) => currency == base || rates.containsKey(currency);

  int? rateOf(String currency) => currency == base ? rateScale : rates[currency];

  int? toBase(int amount, String currency) {
    final rate = rateOf(currency);
    if (rate == null) return null;
    return toBaseMinor(amount, currency, base, rate);
  }

  int? fromBase(int baseAmount, String currency) {
    final rate = rateOf(currency);
    if (rate == null) return null;
    return fromBaseMinor(baseAmount, currency, base, rate);
  }

  /// Подсказка для формы: сумма в другой валюте через базовую.
  int? convert(int amount, String from, String to) {
    if (from == to) return amount;
    final inBase = toBase(amount, from);
    return inBase == null ? null : fromBase(inBase, to);
  }

  /// Курс «1 [from] = x [to]» × 10⁶ — для подписи «по 87,45».
  int? crossRateMicro(String from, String to) {
    final a = rateOf(from);
    final b = rateOf(to);
    if (a == null || b == null) return null;
    return mulDivRound(a, rateScale, b);
  }

  @override
  bool operator ==(Object other) =>
      other is Converter && other.base == base && mapEquals(other.rates, rates);

  @override
  int get hashCode => Object.hash(base, Object.hashAllUnordered(rates.entries.map((e) => '${e.key}=${e.value}')));
}
