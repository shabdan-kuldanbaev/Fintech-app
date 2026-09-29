import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calendar.dart';
import '../core/clock.dart';
import '../data/db/database.dart';
import '../features/accounts/data/account_repository.dart';
import '../features/accounts/domain/account.dart';
import '../features/categories/data/category_repository.dart';
import '../features/categories/domain/category.dart';
import '../features/currencies/data/rates_repository.dart';
import '../features/currencies/domain/converter.dart';
import '../features/currencies/domain/rate.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/settings/domain/settings.dart';
import '../features/transactions/data/transaction_repository.dart';
import '../features/transactions/domain/transaction.dart';

/// Композиционный корень: база и репозитории собираются здесь, экраны
/// получают их через провайдеры (I13 — presentation не видит drift).

/// База — подставляется в `startup.dart` (и в тестах) через override.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider is overridden at startup'),
);

final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// Сегодня по локальному календарю. Экран вкладок сбрасывает его при
/// возвращении приложения из фона — дата могла смениться.
final todayProvider = Provider<LocalDate>(
  (ref) => LocalDate.today(ref.watch(clockProvider)),
);

final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);

final accountRepositoryProvider = Provider(
  (ref) => AccountRepository(ref.watch(appDatabaseProvider), ref.watch(clockProvider)),
);

final categoryRepositoryProvider = Provider(
  (ref) => CategoryRepository(ref.watch(appDatabaseProvider), ref.watch(clockProvider)),
);

final ratesRepositoryProvider = Provider(
  (ref) => RatesRepository(ref.watch(appDatabaseProvider), ref.watch(clockProvider)),
);

final transactionRepositoryProvider = Provider(
  (ref) => TransactionRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(ratesRepositoryProvider),
  ),
);

// --------------------------------------------------------------- потоки

final settingsProvider = StreamProvider<Settings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

final accountsProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(accountRepositoryProvider).watchAll(),
);

final accountProvider = StreamProvider.family<Account?, String>(
  (ref, id) => ref.watch(accountRepositoryProvider).watch(id),
);

final balancesProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(accountRepositoryProvider).watchBalances(),
);

final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAll(),
);

final converterProvider = StreamProvider<Converter>(
  (ref) => ref.watch(ratesRepositoryProvider).watchConverter(),
);

final ratesProvider = StreamProvider<List<Rate>>(
  (ref) => ref.watch(ratesRepositoryProvider).watchRates(),
);

final txnsProvider = StreamProvider.family<List<Txn>, TxnFilter>(
  (ref, filter) => ref.watch(transactionRepositoryProvider).watch(filter),
);

final txnProvider = StreamProvider.family<Txn?, String>(
  (ref, id) => ref.watch(transactionRepositoryProvider).watchOne(id),
);

/// Изменение балансов счетов за период `[from, to)`.
final accountDeltaProvider =
    StreamProvider.family<Map<String, int>, (LocalDate, LocalDate)>(
      (ref, range) =>
          ref.watch(accountRepositoryProvider).watchDelta(range.$1, range.$2),
    );

/// Операции за 60 дней — для «Quick add» (§9.8) и ленты «Recent».
final recentTxnsProvider = StreamProvider<List<Txn>>((ref) {
  final today = ref.watch(todayProvider);
  return ref
      .watch(transactionRepositoryProvider)
      .watch(TxnFilter(from: today.addDays(-60), until: today.addDays(1)));
});

/// Категории по id — для строк ленты.
final categoryMapProvider = Provider<AsyncValue<Map<String, Category>>>(
  (ref) => ref.watch(categoriesProvider).whenData(
    (list) => {for (final c in list) c.id: c},
  ),
);

/// Счета по id.
final accountMapProvider = Provider<AsyncValue<Map<String, Account>>>(
  (ref) => ref.watch(accountsProvider).whenData(
    (list) => {for (final a in list) a.id: a},
  ),
);
