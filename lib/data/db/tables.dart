import 'package:drift/drift.dart';

/// Схема spec.md §3.1. Любое изменение здесь до релиза дописывается в
/// `onCreate` (`database.dart`), `schemaVersion` остаётся 1.

mixin SyncableTable on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Счёт. Баланс не хранится (I3): `opening_balance + Σ transactions` (§9.1).
class Accounts extends Table with SyncableTable {
  TextColumn get name => text()();

  /// 'cash' | 'card' | 'credit_line' | 'loan' | 'savings' | 'deposit'
  TextColumn get kind => text()();
  TextColumn get currency => text()();
  IntColumn get openingBalance => integer().withDefault(const Constant(0))();
  IntColumn get creditLimit => integer().nullable()();
  IntColumn get dueDay => integer().nullable()();
  IntColumn get minPayment => integer().nullable()();
  IntColumn get principal => integer().nullable()();
  IntColumn get totalPayable => integer().nullable()();
  IntColumn get monthlyPayment => integer().nullable()();
  IntColumn get termMonths => integer().nullable()();
  IntColumn get rateBp => integer().nullable()();

  /// 'month' | 'year'
  TextColumn get ratePeriod => text().nullable()();
  TextColumn get firstPaymentDate => text().nullable()();
  IntColumn get targetAmount => integer().nullable()();
  TextColumn get targetDate => text().nullable()();
  TextColumn get iconKey => text()();
  TextColumn get colorKey => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get includeInTotal => boolean().withDefault(const Constant(true))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Категория. Предустановленная: `key != null`, `name == null` — имя из ARB.
class Categories extends Table with SyncableTable {
  TextColumn get key => text().nullable()();
  TextColumn get name => text().nullable()();

  /// 'expense' | 'income'
  TextColumn get kind => text()();
  TextColumn get iconKey => text()();
  TextColumn get colorKey => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  TextColumn get lastAccountId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Транзакция: `amount > 0` всегда, знак задаёт `kind`.
class Transactions extends Table with SyncableTable {
  /// 'expense' | 'income' | 'transfer'
  TextColumn get kind => text()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get counterAccountId =>
      text().nullable().references(Accounts, #id)();
  IntColumn get amount => integer()();
  TextColumn get currency => text()();
  IntColumn get counterAmount => integer().nullable()();
  IntColumn get baseAmount => integer()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();

  /// Оплата наступления (I9). FK не объявлен: `occurrences` ссылается сюда.
  TextColumn get occurrenceId => text().nullable()();

  /// YYYY-MM-DD, локальный календарь (I6).
  TextColumn get date => text()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Правило обязательства (§5).
class RecurringRules extends Table with SyncableTable {
  TextColumn get name => text()();

  /// 'subscription' | 'utility' | 'loan_payment' | 'credit_line_payment' | 'other'
  TextColumn get kind => text()();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  TextColumn get counterAccountId =>
      text().nullable().references(Accounts, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  IntColumn get amount => integer().nullable()();
  TextColumn get currency => text()();

  /// 'monthly' | 'weekly' | 'yearly' | 'every_n_days'
  TextColumn get frequency => text()();
  IntColumn get interval => integer().withDefault(const Constant(1))();
  IntColumn get dayOfMonth => integer().nullable()();
  TextColumn get startDate => text()();
  TextColumn get endDate => text().nullable()();

  /// JSON int[]: за сколько дней до `due_date` напоминать.
  TextColumn get remindDaysBefore =>
      text().withDefault(const Constant('[3,0]'))();
  IntColumn get remindMinutes => integer().nullable()();
  IntColumn get notificationBaseId => integer()();
  BoolColumn get autoPay => boolean().withDefault(const Constant(false))();

  /// YYYY-MM-DD; наступлений раньше этой даты нет. null — активно.
  TextColumn get pausedUntil => text().nullable()();
  TextColumn get iconKey => text()();
  TextColumn get colorKey => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Наступление правила.
class Occurrences extends Table with SyncableTable {
  TextColumn get ruleId => text().references(RecurringRules, #id)();
  IntColumn get seq => integer()();
  TextColumn get dueDate => text()();
  IntColumn get amountExpected => integer().nullable()();
  TextColumn get currency => text()();

  /// 'planned' | 'paid' | 'skipped'
  TextColumn get status => text().withDefault(const Constant('planned'))();
  TextColumn get transactionId =>
      text().nullable().references(Transactions, #id)();
  DateTimeColumn get paidAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Бюджет месяца по категории (`category_id = null` — общий), §9.4.
class Budgets extends Table with SyncableTable {
  TextColumn get categoryId => text().nullable().references(Categories, #id)();

  /// YYYY-MM
  TextColumn get fromMonth => text()();
  IntColumn get amount => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Курс: 1 единица `code` = `rate_micro / 10⁶` единиц базовой валюты.
class ExchangeRates extends Table {
  TextColumn get code => text()();
  IntColumn get rateMicro => integer()();

  /// 'manual' | 'nbkr'
  TextColumn get source => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {code};
}

class AppSettings extends Table {
  TextColumn get key => text()();

  /// JSON
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
