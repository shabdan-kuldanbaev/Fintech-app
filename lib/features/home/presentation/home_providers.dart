import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/calendar.dart';
import '../../accounts/domain/balances.dart';
import '../../payments/domain/planning.dart';

/// Сколько уже обещано платежами до конца расчётного месяца (§9.7) и есть
/// ли обязательства вообще.
final homeToPayProvider = Provider<AsyncValue<(int, bool)>>((ref) {
  final settings = ref.watch(settingsProvider).value;
  final items = ref.watch(upcomingProvider).value;
  final rules = ref.watch(rulesProvider).value;
  final lastPaid = ref.watch(lastPaidProvider).value;
  final converter = ref.watch(converterProvider).value;
  final accounts = ref.watch(accountMapProvider).value;
  final today = ref.watch(todayProvider);
  if (settings == null || items == null || rules == null || lastPaid == null || converter == null || accounts == null) {
    return const AsyncLoading();
  }
  final period = MonthPeriod.containing(today, settings.monthStartDay);
  final sum = toPayUntil(
    items,
    periodEnd: period.end,
    lastPaid: lastPaid,
    converter: converter,
    inOwnFunds: (id) {
      final a = accounts[id];
      return a != null && a.kind.isAsset && a.includeInTotal && !a.isArchived;
    },
  );
  return AsyncData((sum, rules.isNotEmpty));
});

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
