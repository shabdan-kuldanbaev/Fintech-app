import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/calendar.dart';
import '../../accounts/domain/balances.dart';

/// Сколько уже обещано платежами до конца расчётного месяца (§9.7).
/// Этап 3 подставляет сюда наступления; до него — ноль.
final homeToPayProvider = Provider<AsyncValue<(int, bool)>>(
  (ref) => const AsyncData((0, false)),
);

/// Сводка Главной: свои деньги, к оплате, «можно тратить до».
final homeSummaryProvider = Provider<AsyncValue<HomeSummary>>((ref) {
  final settings = ref.watch(settingsProvider);
  final accounts = ref.watch(accountsProvider);
  final balances = ref.watch(balancesProvider);
  final converter = ref.watch(converterProvider);
  final toPay = ref.watch(homeToPayProvider);
  final today = ref.watch(todayProvider);
  final s = settings.value;
  final a = accounts.value;
  final b = balances.value;
  final c = converter.value;
  final p = toPay.value;
  if (s == null || a == null || b == null || c == null || p == null) {
    return const AsyncLoading();
  }
  final period = MonthPeriod.containing(today, s.monthStartDay);
  return AsyncData(
    HomeSummary(
      baseCurrency: c.base,
      totals: computeTotals(a, b, c),
      toPay: p.$1,
      periodEnd: period.end,
      hasObligations: p.$2,
    ),
  );
});

/// Сводка Главной (§9.7).
class HomeSummary {
  const HomeSummary({
    required this.baseCurrency,
    required this.totals,
    required this.toPay,
    required this.periodEnd,
    required this.hasObligations,
  });

  final String baseCurrency;
  final Totals totals;
  final int toPay;
  final LocalDate periodEnd;
  final bool hasObligations;

  int get safeToSpend => totals.ownFunds - toPay;
}
