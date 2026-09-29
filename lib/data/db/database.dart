import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

/// База приложения (spec.md §3.2). В тестах —
/// `AppDatabase(NativeDatabase.memory())`.
///
/// **Одна инициализирующая миграция.** До релиза в App Store история версий
/// схемы не хранится: любое изменение `tables.dart` дописывается прямо в
/// [MigrationStrategy.onCreate], `schemaVersion` остаётся 1, шагов
/// `onUpgrade` нет. Цена: файл от сборки с другой версией схемы не
/// откроется, приложение на устройстве переустанавливается.
@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    RecurringRules,
    Occurrences,
    Budgets,
    ExchangeRates,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: fileName));

  /// Имя файла базы. Резервная копия (§7) заменяет именно его.
  static const String fileName = 'fintech';

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      for (final sql in indexStatements) {
        await customStatement(sql);
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Индексы §3.2 — отдельным списком: тест схемы сверяет их с
  /// `sqlite_master`.
  static const List<String> indexStatements = [
    'CREATE INDEX idx_tx_account_date ON transactions(account_id, date) '
        'WHERE deleted_at IS NULL',
    'CREATE INDEX idx_tx_counter ON transactions(counter_account_id) '
        'WHERE deleted_at IS NULL',
    'CREATE INDEX idx_tx_date ON transactions(date) WHERE deleted_at IS NULL',
    'CREATE INDEX idx_tx_category_date ON transactions(category_id, date) '
        'WHERE deleted_at IS NULL',
    'CREATE INDEX idx_tx_occurrence ON transactions(occurrence_id)',
    'CREATE UNIQUE INDEX idx_occ_rule_due ON occurrences(rule_id, due_date) '
        'WHERE deleted_at IS NULL',
    'CREATE INDEX idx_occ_status_due ON occurrences(status, due_date) '
        'WHERE deleted_at IS NULL',
    'CREATE INDEX idx_budgets_cat_month ON budgets(category_id, from_month) '
        'WHERE deleted_at IS NULL',
  ];
}
