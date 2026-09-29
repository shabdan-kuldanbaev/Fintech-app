import 'package:flutter/foundation.dart';

import '../../../core/calendar.dart';
import 'transaction.dart';

/// Частая операция для чипа «Quick add» (spec.md §9.8).
@immutable
class QuickAdd {
  const QuickAdd({
    required this.kind,
    required this.accountId,
    required this.amount,
    required this.count,
    required this.lastDate,
    this.categoryId,
    this.counterAccountId,
    this.counterAmount,
    this.note,
  });

  final TxKind kind;
  final String accountId;
  final String? categoryId;
  final String? counterAccountId;
  final int amount;
  final int? counterAmount;

  /// Заметка в том виде, в каком её ввели в последний раз.
  final String? note;
  final int count;
  final LocalDate lastDate;

  TxnInput toInput(LocalDate date) => TxnInput(
    kind: kind,
    accountId: accountId,
    amount: amount,
    date: date,
    categoryId: categoryId,
    counterAccountId: counterAccountId,
    counterAmount: counterAmount,
    note: note,
  );

  @override
  bool operator ==(Object other) =>
      other is QuickAdd &&
      other.kind == kind &&
      other.accountId == accountId &&
      other.categoryId == categoryId &&
      other.counterAccountId == counterAccountId &&
      other.amount == amount &&
      other.note == note &&
      other.count == count &&
      other.lastDate == lastDate;

  @override
  int get hashCode => Object.hash(
    kind,
    accountId,
    categoryId,
    counterAccountId,
    amount,
    note,
    count,
    lastDate,
  );
}

/// Частые операции за 60 дней до [today]: группы с двумя и более
/// повторениями, по числу повторений, затем по свежести; не больше [limit].
/// Оплаты наступлений и корректировки ([excludedCategoryIds]) не в счёт.
/// [kinds] — какие виды операций брать (на экране «Income» — только доходы).
List<QuickAdd> frequentOps(
  Iterable<Txn> txns, {
  required LocalDate today,
  Set<String> excludedCategoryIds = const {},
  Set<TxKind> kinds = const {TxKind.expense, TxKind.income, TxKind.transfer},
  int limit = 6,
  int days = 60,
}) {
  final from = today.addDays(-days);
  final groups = <String, List<Txn>>{};
  for (final t in txns) {
    if (!kinds.contains(t.kind)) continue;
    if (t.occurrenceId != null) continue;
    if (t.categoryId != null && excludedCategoryIds.contains(t.categoryId)) {
      continue;
    }
    if (t.date < from || t.date > today) continue;
    final note = (t.note ?? '').trim().toLowerCase();
    final key = [
      t.kind.db,
      t.categoryId ?? t.counterAccountId ?? '',
      t.accountId,
      t.amount,
      note,
    ].join('\u0000');
    (groups[key] ??= []).add(t);
  }
  final result = <QuickAdd>[];
  for (final list in groups.values) {
    if (list.length < 2) continue;
    list.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    });
    final last = list.first;
    final note = last.note?.trim();
    result.add(
      QuickAdd(
        kind: last.kind,
        accountId: last.accountId,
        categoryId: last.categoryId,
        counterAccountId: last.counterAccountId,
        amount: last.amount,
        counterAmount: last.counterAmount,
        note: note == null || note.isEmpty ? null : note,
        count: list.length,
        lastDate: last.date,
      ),
    );
  }
  result.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    return byCount != 0 ? byCount : b.lastDate.compareTo(a.lastDate);
  });
  return result.take(limit).toList();
}
