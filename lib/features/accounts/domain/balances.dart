import 'package:flutter/foundation.dart';

import '../../currencies/domain/converter.dart';
import 'account.dart';

/// Итоги по счетам в базовой валюте (spec.md §9.1–9.2). Без I/O.
@immutable
class Totals {
  const Totals({
    required this.ownFunds,
    required this.creditAvailable,
    required this.debt,
    required this.missingRates,
  });

  /// Σ балансов активов (`include_in_total`, не в архиве) — «Own funds».
  final int ownFunds;

  /// Σ доступного по кредитным линиям.
  final int creditAvailable;

  /// Σ долгов по кредитам и кредитным линиям.
  final int debt;

  /// Валюты счетов без курса: такие счета в итоги не вошли.
  final Set<String> missingRates;
}

/// Долг пассива: −баланс, не меньше нуля. Для актива — 0.
int debtOf(Account account, int balance) =>
    account.kind.isLiability && balance < 0 ? -balance : 0;

/// Доступно по кредитной линии: лимит + баланс (баланс ≤ 0).
int availableOf(Account account, int balance) {
  final limit = account.creditLimit ?? 0;
  final v = limit + balance;
  return v < 0 ? 0 : v;
}

Totals computeTotals(
  List<Account> accounts,
  Map<String, int> balances,
  Converter converter,
) {
  var own = 0;
  var available = 0;
  var debt = 0;
  final missing = <String>{};
  for (final a in accounts) {
    if (a.isArchived) continue;
    final balance = balances[a.id] ?? a.openingBalance;
    int? inBase(int v) {
      final r = converter.toBase(v, a.currency);
      if (r == null) missing.add(a.currency);
      return r;
    }

    if (a.kind.isAsset) {
      if (!a.includeInTotal) continue;
      own += inBase(balance) ?? 0;
    } else {
      debt += inBase(debtOf(a, balance)) ?? 0;
      if (a.kind == AccountKind.creditLine) {
        available += inBase(availableOf(a, balance)) ?? 0;
      }
    }
  }
  return Totals(
    ownFunds: own,
    creditAvailable: available,
    debt: debt,
    missingRates: missing,
  );
}
