import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/calendar.dart';
import '../../payments/domain/rule.dart';
import '../domain/account.dart';

/// Сведения о платежах по счёту-пассиву: сколько оплачено из скольких,
/// ближайшее наступление (кредит, кредитная линия).
@immutable
class ObligationInfo {
  const ObligationInfo({
    required this.paid,
    required this.total,
    this.next,
    this.nextAmount,
    this.nextOccurrenceId,
  });

  final int paid;
  final int total;
  final LocalDate? next;
  final int? nextAmount;
  final String? nextOccurrenceId;
}

/// accountId → сведения по наступлениям правил-переводов на этот счёт.
final obligationInfoProvider = Provider<AsyncValue<Map<String, ObligationInfo>>>((ref) {
  final items = ref.watch(obligationItemsProvider).value;
  final accounts = ref.watch(accountMapProvider).value;
  if (items == null || accounts == null) return const AsyncLoading();
  final byAccount = <String, List<DueItem>>{};
  for (final i in items) {
    (byAccount[i.rule.counterAccountId!] ??= []).add(i);
  }
  return AsyncData({
    for (final MapEntry(key: id, value: list) in byAccount.entries)
      id: _info(accounts[id], list),
  });
});

ObligationInfo _info(Account? account, List<DueItem> list) {
  final paid = list.where((i) => i.occurrence.status == OccStatus.paid).length;
  final counted = list.where((i) => i.occurrence.status != OccStatus.skipped).length;
  final next = list.where((i) => i.occurrence.status == OccStatus.planned).firstOrNull?.occurrence;
  return ObligationInfo(
    paid: paid,
    total: account?.kind == AccountKind.loan ? (account?.termMonths ?? counted) : counted,
    next: next?.dueDate,
    nextAmount: next?.amountExpected,
    nextOccurrenceId: next?.id,
  );
}

final obligationItemsProvider = StreamProvider<List<DueItem>>(
  (ref) => ref.watch(ruleRepositoryProvider).watchObligationItems(),
);
