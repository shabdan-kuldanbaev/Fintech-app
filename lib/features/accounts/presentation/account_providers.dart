import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calendar.dart';

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

/// accountId → сведения. Этап 3 наполняет его наступлениями (spec.md §11);
/// до него — пусто.
final obligationInfoProvider = Provider<AsyncValue<Map<String, ObligationInfo>>>(
  (ref) => const AsyncData({}),
);
