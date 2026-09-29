import 'package:flutter/foundation.dart';

import '../../../core/calendar.dart';
import '../../accounts/domain/account.dart';
import '../../currencies/domain/converter.dart';
import '../../transactions/domain/transaction.dart';

/// Ключ группы «платежи по кредитам» в разбивке по категориям: у перевода
/// на `loan` категории нет, но это трата (I15, §9.3).
const String loanPaymentsKey = '#loan';

/// Итоги периода в базовой валюте (spec.md §9.3).
@immutable
class PeriodStats {
  const PeriodStats({
    required this.spent,
    required this.income,
    required this.saved,
    required this.byCategory,
  });

  /// Расходы (кроме `adjustment`) + переводы на кредит.
  final int spent;

  /// Доходы (кроме `adjustment`).
  final int income;

  /// Переводы на накопления/вклады минус переводы с них.
  final int saved;

  /// categoryId (или [loanPaymentsKey]) → потрачено; по убыванию суммы.
  final List<MapEntry<String, int>> byCategory;

  static const empty = PeriodStats(spent: 0, income: 0, saved: 0, byCategory: []);
}

/// §9.3 над операциями [txns]; учитываются только попавшие в [period].
/// [excluded] — системные категории (`adjustment`): правка баланса — не
/// трата и не доход. Переводы на кредитную линию — не трата (I15).
PeriodStats periodStats(
  Iterable<Txn> txns, {
  required MonthPeriod period,
  required Map<String, Account> accounts,
  required Set<String> excluded,
}) {
  var spent = 0;
  var income = 0;
  var saved = 0;
  final byCategory = <String, int>{};
  for (final t in txns) {
    if (!period.contains(t.date)) continue;
    if (t.categoryId != null && excluded.contains(t.categoryId)) continue;
    switch (t.kind) {
      case TxKind.expense:
        spent += t.baseAmount;
        final key = t.categoryId ?? '';
        byCategory[key] = (byCategory[key] ?? 0) + t.baseAmount;
      case TxKind.income:
        income += t.baseAmount;
      case TxKind.transfer:
        final to = accounts[t.counterAccountId]?.kind;
        final from = accounts[t.accountId]?.kind;
        if (to == AccountKind.loan) {
          spent += t.baseAmount;
          byCategory[loanPaymentsKey] = (byCategory[loanPaymentsKey] ?? 0) + t.baseAmount;
        }
        if (to != null && to.isSaving) saved += t.baseAmount;
        if (from != null && from.isSaving) saved -= t.baseAmount;
    }
  }
  final sorted = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return PeriodStats(spent: spent, income: income, saved: saved, byCategory: sorted);
}

/// Изменение баланса счёта [accountId] операцией [t] (как в SQL §9.1).
int deltaOf(Txn t, String accountId) {
  var d = 0;
  if (t.accountId == accountId) d += t.kind == TxKind.income ? t.amount : -t.amount;
  if (t.kind == TxKind.transfer && t.counterAccountId == accountId) d += t.counterAmount ?? t.amount;
  return d;
}

/// Долг по кредитам и кредитным линиям на начало каждого дня из [dates]
/// (в базовой валюте по текущему курсу). [balances] — балансы сейчас (со
/// всеми операциями); [txns] — все операции не раньше самой ранней даты:
/// баланс на день `d` = сейчас − всё, что датировано `d` и позже.
List<int> debtSeries({
  required List<LocalDate> dates,
  required Iterable<Account> accounts,
  required Map<String, int> balances,
  required Iterable<Txn> txns,
  required Converter converter,
}) {
  final liabilities = accounts.where((a) => a.kind.isLiability).toList();
  return [
    for (final d in dates)
      liabilities.fold<int>(0, (sum, a) {
        // Начальный долг кредита без даты: до месяца перед первым платежом
        // кредита ещё не было.
        final opened = a.firstPaymentDate?.addMonths(-1);
        if (opened != null && d < opened) return sum;
        var balance = balances[a.id] ?? a.openingBalance;
        for (final t in txns) {
          if (t.date >= d) balance -= deltaOf(t, a.id);
        }
        final debt = balance < 0 ? -balance : 0;
        return sum + (converter.toBase(debt, a.currency) ?? 0);
      }),
  ];
}
