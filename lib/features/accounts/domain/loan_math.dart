import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Кредитная математика, простая модель (spec.md §4.3, I19). Без I/O.
///
/// Всё, что здесь считается, — предложение для формы: банки считают дни и
/// комиссии по-своему, и в базу ложится то, что в полях, а не этот расчёт.
/// `double` живёт только в [estimatePayment] и сразу округляется до
/// минимальной единицы (I4).

enum RatePeriod { month, year }

/// Месячная ставка из базисных пунктов: 224 б. п. в месяц — 0,0224;
/// годовая делится на 12.
double monthlyRate(int rateBp, RatePeriod period) {
  final r = rateBp / 10000;
  return period == RatePeriod.year ? r / 12 : r;
}

/// Ежемесячный платёж: аннуитет при ставке, `ceil(P / n)` без неё.
/// [principal] — в минимальных единицах, результат тоже.
int estimatePayment({
  required int principal,
  required int months,
  int? rateBp,
  RatePeriod period = RatePeriod.month,
}) {
  if (principal <= 0 || months <= 0) return 0;
  if (rateBp == null || rateBp == 0) {
    return (principal + months - 1) ~/ months;
  }
  final r = monthlyRate(rateBp, period);
  final payment = principal * r / (1 - math.pow(1 + r, -months));
  return (payment + 0.5).floor();
}

/// Итого к возврату при равных платежах.
int totalForPayment(int payment, int months) => payment * months;

/// Платёж из итого: равные доли, округление половины вверх; последний
/// платёж графика добирает разницу ([paymentSchedule]).
int paymentForTotal(int total, int months) {
  if (months <= 0) return 0;
  return (total * 2 + months) ~/ (months * 2);
}

/// График из [months] платежей по [payment], последний добирает так, чтобы
/// сумма графика равнялась [total] тыйын в тыйын (spec.md §3.4, createLoan).
///
/// Если [payment] слишком велик и последнему не остаётся ничего, платёж
/// пересчитывается равными долями.
List<int> paymentSchedule({
  required int total,
  required int payment,
  required int months,
}) {
  if (months <= 0 || total <= 0) return const [];
  var p = payment;
  if (p <= 0 || p * (months - 1) >= total) {
    p = total ~/ months;
  }
  return [
    for (var i = 0; i < months - 1; i++) p,
    total - p * (months - 1),
  ];
}

enum RecalcMode {
  /// Платёж прежний, платежей меньше.
  keepPayment,

  /// Срок прежний, платёж меньше.
  keepTerm,
}

/// Пересчёт оставшихся платежей после досрочного погашения (§4.3).
/// [remaining] — остаток долга, [count] — сколько платежей осталось,
/// [payment] — текущий платёж.
List<int> recalculate({
  required int remaining,
  required int count,
  required int payment,
  required RecalcMode mode,
}) {
  if (remaining <= 0) return const [];
  switch (mode) {
    case RecalcMode.keepTerm:
      if (count <= 0) return [remaining];
      final p = remaining ~/ count;
      if (p == 0) return [remaining];
      return [for (var i = 0; i < count - 1; i++) p, remaining - p * (count - 1)];
    case RecalcMode.keepPayment:
      if (payment <= 0) return [remaining];
      final n = (remaining + payment - 1) ~/ payment;
      return [for (var i = 0; i < n - 1; i++) payment, remaining - payment * (n - 1)];
  }
}

/// Оценка для формы «New loan»: платёж и итого.
@immutable
class LoanEstimate {
  const LoanEstimate(this.payment, this.total);
  final int payment;
  final int total;
}

LoanEstimate estimateLoan({
  required int principal,
  required int months,
  int? rateBp,
  RatePeriod period = RatePeriod.month,
}) {
  final payment = estimatePayment(
    principal: principal,
    months: months,
    rateBp: rateBp,
    period: period,
  );
  final total = (rateBp == null || rateBp == 0)
      ? principal
      : totalForPayment(payment, months);
  return LoanEstimate(payment, total);
}
