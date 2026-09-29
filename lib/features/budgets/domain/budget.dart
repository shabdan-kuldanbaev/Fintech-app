import 'package:flutter/foundation.dart';

/// Строка `budgets` (spec.md §3.1, §9.4): сумма в базовой валюте, действует
/// с месяца [fromMonth] (`YYYY-MM`) до следующей строки той же категории.
/// `amount == 0` — «бюджета нет» с этого месяца.
@immutable
class Budget {
  const Budget({required this.id, required this.categoryId, required this.fromMonth, required this.amount});

  final String id;

  /// `null` — общий бюджет месяца.
  final String? categoryId;
  final String fromMonth;
  final int amount;

  @override
  bool operator ==(Object other) =>
      other is Budget &&
      other.id == id &&
      other.categoryId == categoryId &&
      other.fromMonth == fromMonth &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(id, categoryId, fromMonth, amount);
}

/// Действующая строка для категории [categoryId] в месяце [month] (§9.4):
/// максимальный `from_month ≤ month`. Нет её или сумма 0 — бюджета нет.
Budget? effectiveBudget(Iterable<Budget> rows, String? categoryId, String month) {
  Budget? best;
  for (final b in rows) {
    if (b.categoryId != categoryId || b.fromMonth.compareTo(month) > 0) continue;
    if (best == null || b.fromMonth.compareTo(best.fromMonth) > 0) best = b;
  }
  return best == null || best.amount <= 0 ? null : best;
}

/// Прогресс бюджета: потрачено и лимит; превышение — [over] > 0.
@immutable
class BudgetProgress {
  const BudgetProgress({required this.spent, required this.budget});
  final int spent;
  final int budget;

  int get left => budget - spent;
  int get over => spent > budget ? spent - budget : 0;
  double get ratio => budget <= 0 ? 0 : spent / budget;
}
