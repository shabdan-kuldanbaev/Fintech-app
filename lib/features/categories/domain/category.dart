import 'package:flutter/foundation.dart';

enum CategoryKind {
  expense('expense'),
  income('income');

  const CategoryKind(this.db);
  final String db;

  static CategoryKind fromDb(String value) => values.firstWhere(
    (k) => k.db == value,
    orElse: () => throw ArgumentError.value(value, 'category kind'),
  );
}

/// Категория. Предустановленная: [key] задан, [name] пуст — имя из ARB по
/// ключу; переименованная пользователем — [name] задан (spec.md §3.1).
@immutable
class Category {
  const Category({
    required this.id,
    required this.kind,
    required this.iconKey,
    required this.colorKey,
    this.key,
    this.name,
    this.sortOrder = 0,
    this.isSystem = false,
    this.lastAccountId,
  });

  final String id;
  final String? key;
  final String? name;
  final CategoryKind kind;
  final String iconKey;
  final String colorKey;
  final int sortOrder;
  final bool isSystem;

  /// Счёт последней операции в этой категории (§8.3 «Add»).
  final String? lastAccountId;

  @override
  bool operator ==(Object other) =>
      other is Category &&
      other.id == id &&
      other.key == key &&
      other.name == name &&
      other.kind == kind &&
      other.iconKey == iconKey &&
      other.colorKey == colorKey &&
      other.sortOrder == sortOrder &&
      other.lastAccountId == lastAccountId;

  @override
  int get hashCode =>
      Object.hash(id, key, name, kind, iconKey, colorKey, sortOrder, lastAccountId);
}

/// Предустановленная категория (§3.5): ключ имени, иконка, пастель.
@immutable
class CategoryPreset {
  const CategoryPreset(this.key, this.kind, this.iconKey, this.colorKey);
  final String key;
  final CategoryKind kind;
  final String iconKey;
  final String colorKey;
}

/// Ключ системной категории «Корректировка» (§3.4): правка баланса.
const String adjustmentKey = 'adjustment';

/// Порядок — как в §3.5.
const List<CategoryPreset> categoryPresets = [
  CategoryPreset('groceries', CategoryKind.expense, 'groceries', 'mint'),
  CategoryPreset('cafe', CategoryKind.expense, 'cafe', 'butter'),
  CategoryPreset('transport', CategoryKind.expense, 'transport', 'sky'),
  CategoryPreset('taxi', CategoryKind.expense, 'taxi', 'sky'),
  CategoryPreset('housing', CategoryKind.expense, 'housing', 'lavender'),
  CategoryPreset('utilities', CategoryKind.expense, 'utilities', 'lavender'),
  CategoryPreset('phone', CategoryKind.expense, 'phone', 'sky'),
  CategoryPreset('subscriptions', CategoryKind.expense, 'subscriptions', 'lavender'),
  CategoryPreset('health', CategoryKind.expense, 'health', 'blush'),
  CategoryPreset('clothes', CategoryKind.expense, 'clothes', 'butter'),
  CategoryPreset('entertainment', CategoryKind.expense, 'entertainment', 'butter'),
  CategoryPreset('education', CategoryKind.expense, 'education', 'sky'),
  CategoryPreset('gifts', CategoryKind.expense, 'gifts', 'blush'),
  CategoryPreset('travel', CategoryKind.expense, 'travel', 'mint'),
  CategoryPreset('kids', CategoryKind.expense, 'kids', 'butter'),
  CategoryPreset('pets', CategoryKind.expense, 'pets', 'mint'),
  CategoryPreset('other_expense', CategoryKind.expense, 'other', 'lavender'),
  CategoryPreset('salary', CategoryKind.income, 'salary', 'mint'),
  CategoryPreset('freelance', CategoryKind.income, 'freelance', 'sky'),
  CategoryPreset('gift_income', CategoryKind.income, 'gifts', 'blush'),
  CategoryPreset('interest', CategoryKind.income, 'interest', 'mint'),
  CategoryPreset('other_income', CategoryKind.income, 'other', 'lavender'),
];
