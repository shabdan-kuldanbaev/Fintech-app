import 'package:drift/native.dart';
import 'package:fintech/core/calendar.dart';
import 'package:fintech/core/clock.dart';
import 'package:fintech/data/db/database.dart';
import 'package:fintech/features/accounts/data/account_repository.dart';
import 'package:fintech/features/accounts/domain/account.dart';
import 'package:fintech/features/categories/data/category_repository.dart';
import 'package:fintech/features/categories/domain/category.dart';
import 'package:fintech/features/currencies/data/rates_repository.dart';
import 'package:fintech/features/settings/data/bootstrap.dart';
import 'package:fintech/features/settings/data/settings_repository.dart';
import 'package:fintech/features/transactions/data/transaction_repository.dart';
import 'package:fintech/features/transactions/domain/transaction.dart';

/// Общая обвязка тестов репозиториев: база в памяти после первого запуска,
/// часы на 2026-09-29 12:00 UTC, базовая валюта — сом.
class Harness {
  Harness._(this.db, this.clock)
    : settings = SettingsRepository(db),
      accounts = AccountRepository(db, clock),
      categories = CategoryRepository(db, clock),
      rates = RatesRepository(db, clock) {
    transactions = TransactionRepository(db, clock, rates);
  }

  static Future<Harness> create({String country = 'KG'}) async {
    final db = AppDatabase(NativeDatabase.memory());
    final clock = FakeClock(DateTime.utc(2026, 9, 29, 12));
    await bootstrapIfNeeded(db, clock, countryCode: country, cashName: 'Cash');
    return Harness._(db, clock);
  }

  final AppDatabase db;
  final FakeClock clock;
  final SettingsRepository settings;
  final AccountRepository accounts;
  final CategoryRepository categories;
  final RatesRepository rates;
  late final TransactionRepository transactions;

  LocalDate get today => LocalDate.today(clock);

  Future<void> dispose() => db.close();

  Future<String> cashId() async =>
      (await accounts.all()).firstWhere((a) => a.kind == AccountKind.cash).id;

  Future<String> categoryId(String key) async =>
      (await categories.all()).firstWhere((c) => c.key == key).id;

  Future<String> card({String currency = 'KGS', int balance = 0, String name = 'Card'}) =>
      accounts.create(
        AccountInput(
          name: name,
          kind: AccountKind.card,
          currency: currency,
          openingBalance: balance,
        ),
      );

  Future<String> expense(
    String accountId,
    int amount, {
    String category = 'groceries',
    LocalDate? date,
    String? note,
  }) async => transactions.create(
    TxnInput(
      kind: TxKind.expense,
      accountId: accountId,
      amount: amount,
      date: date ?? today,
      categoryId: await categoryId(category),
      note: note,
    ),
  );

  Future<String> income(String accountId, int amount, {LocalDate? date}) async =>
      transactions.create(
        TxnInput(
          kind: TxKind.income,
          accountId: accountId,
          amount: amount,
          date: date ?? today,
          categoryId: await categoryId('salary'),
        ),
      );

  Future<TxnInput> expenseInput(String accountId, String categoryId, {int amount = 100}) async =>
      TxnInput(kind: TxKind.expense, accountId: accountId, amount: amount, date: today, categoryId: categoryId);

  Future<int> balance(String accountId) async =>
      (await accounts.balances())[accountId]!;
}

/// Удобство: категория по ключу из списка.
Category byKey(List<Category> list, String key) =>
    list.firstWhere((c) => c.key == key);
