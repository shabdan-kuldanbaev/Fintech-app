import 'package:drift/drift.dart';

import '../../../core/clock.dart';
import '../../../core/uuid.dart';
import '../../../data/db/database.dart';
import '../domain/category.dart';

/// Категории (spec.md §3.4, §3.5).
class CategoryRepository {
  CategoryRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  SimpleSelectStatement<$CategoriesTable, CategoryRow> _alive() =>
      _db.select(_db.categories)
        ..where((c) => c.deletedAt.isNull())
        ..orderBy([
          (c) => OrderingTerm(expression: c.kind),
          (c) => OrderingTerm(expression: c.sortOrder),
          (c) => OrderingTerm(expression: c.createdAt),
        ]);

  /// Все живые категории, включая системную «Корректировку».
  Stream<List<Category>> watchAll() =>
      _alive().watch().map((rows) => rows.map(toCategory).toList());

  Future<List<Category>> all() async =>
      (await _alive().get()).map(toCategory).toList();

  Future<Category?> get(String id) async {
    final row = await (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    return row == null ? null : toCategory(row);
  }

  /// id системной категории «Корректировка» (создаётся при первом запуске).
  Future<String> adjustmentId() async {
    final row = await (_db.select(_db.categories)
          ..where((c) => c.key.equals(adjustmentKey) & c.deletedAt.isNull()))
        .getSingleOrNull();
    if (row != null) return row.id;
    final id = newId();
    final now = _clock.now();
    await _db.into(_db.categories).insert(
      CategoriesCompanion.insert(
        id: id,
        createdAt: now,
        updatedAt: now,
        key: const Value(adjustmentKey),
        kind: CategoryKind.expense.db,
        iconKey: 'adjustment',
        colorKey: 'lavender',
        isSystem: const Value(true),
        sortOrder: const Value(1000),
      ),
    );
    return id;
  }

  /// Предустановленные категории §3.5 — внутри транзакции первого запуска.
  Future<void> seedPresets() async {
    final now = _clock.now();
    var order = 0;
    for (final p in categoryPresets) {
      await _db.into(_db.categories).insert(
        CategoriesCompanion.insert(
          id: newId(),
          createdAt: now,
          updatedAt: now,
          key: Value(p.key),
          kind: p.kind.db,
          iconKey: p.iconKey,
          colorKey: p.colorKey,
          sortOrder: Value(order++),
        ),
      );
    }
    await adjustmentId();
  }

  Future<String> create({
    required String name,
    required CategoryKind kind,
    required String iconKey,
    required String colorKey,
  }) async {
    final id = newId();
    await _db.transaction(() async {
      final now = _clock.now();
      final order = await _db
          .customSelect(
            'SELECT COALESCE(MAX(sort_order), -1) + 1 AS o FROM categories '
            'WHERE kind = ? AND is_system = 0',
            variables: [Variable(kind.db)],
          )
          .getSingle();
      await _db.into(_db.categories).insert(
        CategoriesCompanion.insert(
          id: id,
          createdAt: now,
          updatedAt: now,
          name: Value(name.trim()),
          kind: kind.db,
          iconKey: iconKey,
          colorKey: colorKey,
          sortOrder: Value(order.read<int>('o')),
        ),
      );
    });
    return id;
  }

  /// Правка. Пустое имя у предустановленной — вернуть имя из ARB.
  Future<void> update(
    String id, {
    required String? name,
    required String iconKey,
    required String colorKey,
  }) async {
    final trimmed = name?.trim();
    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
        iconKey: Value(iconKey),
        colorKey: Value(colorKey),
        updatedAt: Value(_clock.now()),
      ),
    );
  }

  /// Порядок в списке: [ids] — категории одного вида в новом порядке.
  Future<void> reorder(List<String> ids) async {
    await _db.transaction(() async {
      final now = _clock.now();
      for (var i = 0; i < ids.length; i++) {
        await (_db.update(_db.categories)..where((c) => c.id.equals(ids[i])))
            .write(CategoriesCompanion(sortOrder: Value(i), updatedAt: Value(now)));
      }
    });
  }

  Future<int> transactionCount(String id) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM transactions WHERE category_id = ? '
          'AND deleted_at IS NULL',
          variables: [Variable(id)],
        )
        .getSingle();
    return row.read<int>('n');
  }

  /// Удаление (§8.3 «Categories»): операции и правила переходят в
  /// [moveTo], бюджеты категории снимаются. Одна транзакция БД.
  Future<void> delete(String id, {String? moveTo}) async {
    await _db.transaction(() async {
      final now = _clock.now();
      final count = await transactionCount(id);
      if (count > 0 && moveTo == null) {
        throw StateError('category has transactions: move them first');
      }
      if (moveTo != null) {
        await (_db.update(_db.transactions)..where((t) => t.categoryId.equals(id)))
            .write(TransactionsCompanion(categoryId: Value(moveTo), updatedAt: Value(now)));
        await (_db.update(_db.recurringRules)..where((r) => r.categoryId.equals(id)))
            .write(RecurringRulesCompanion(categoryId: Value(moveTo), updatedAt: Value(now)));
      }
      await (_db.update(_db.budgets)
            ..where((b) => b.categoryId.equals(id) & b.deletedAt.isNull()))
          .write(BudgetsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
      await (_db.update(_db.categories)..where((c) => c.id.equals(id)))
          .write(CategoriesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
    });
  }

  static Category toCategory(CategoryRow r) => Category(
    id: r.id,
    key: r.key,
    name: r.name,
    kind: CategoryKind.fromDb(r.kind),
    iconKey: r.iconKey,
    colorKey: r.colorKey,
    sortOrder: r.sortOrder,
    isSystem: r.isSystem,
    lastAccountId: r.lastAccountId,
  );
}
