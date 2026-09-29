import 'package:drift/drift.dart';

import '../../../core/clock.dart';
import '../../../core/uuid.dart';
import '../../../data/db/database.dart';
import '../domain/budget.dart';

/// Бюджеты (spec.md §9.4): строка на категорию и месяц начала действия.
/// Прошлые месяцы не переписываются — новая сумма с месяца [set].
class BudgetRepository {
  BudgetRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  Stream<List<Budget>> watchAll() =>
      (_db.select(_db.budgets)..where((b) => b.deletedAt.isNull())).watch().map((rows) => rows.map(_budget).toList());

  Future<List<Budget>> all() async =>
      (await (_db.select(_db.budgets)..where((b) => b.deletedAt.isNull())).get()).map(_budget).toList();

  /// Бюджет [amount] (базовая валюта) для [categoryId] с месяца [fromMonth].
  /// Строка того же месяца уже есть — она правится, а не дублируется.
  Future<void> set(String? categoryId, int amount, String fromMonth) async {
    if (amount < 0) throw ArgumentError.value(amount, 'amount');
    await _db.transaction(() async {
      final now = _clock.now();
      final same = await (_db.select(_db.budgets)
            ..where((b) =>
                b.deletedAt.isNull() &
                b.fromMonth.equals(fromMonth) &
                (categoryId == null ? b.categoryId.isNull() : b.categoryId.equals(categoryId))))
          .getSingleOrNull();
      if (same != null) {
        await (_db.update(_db.budgets)..where((b) => b.id.equals(same.id)))
            .write(BudgetsCompanion(amount: Value(amount), updatedAt: Value(now)));
        return;
      }
      await _db.into(_db.budgets).insert(
        BudgetsCompanion.insert(
          id: newId(),
          createdAt: now,
          updatedAt: now,
          categoryId: Value(categoryId),
          fromMonth: fromMonth,
          amount: amount,
        ),
      );
    });
  }

  /// «Remove budget» с месяца [month]: история прошлых месяцев остаётся.
  Future<void> remove(String? categoryId, String month) => set(categoryId, 0, month);

  static Budget _budget(BudgetRow r) =>
      Budget(id: r.id, categoryId: r.categoryId, fromMonth: r.fromMonth, amount: r.amount);
}
