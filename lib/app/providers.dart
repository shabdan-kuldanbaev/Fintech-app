import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calendar.dart';
import '../core/clock.dart';
import '../data/db/database.dart';
import '../features/accounts/data/account_repository.dart';
import '../features/accounts/domain/account.dart';
import '../data/backup/backup_files.dart';
import '../data/rates/nbkr_client.dart';
import '../features/budgets/data/budget_repository.dart';
import '../features/budgets/domain/budget.dart';
import '../features/categories/data/category_repository.dart';
import '../features/categories/domain/category.dart';
import '../features/currencies/data/rates_repository.dart';
import '../features/currencies/data/rates_updater.dart';
import '../features/currencies/domain/converter.dart';
import '../features/currencies/domain/rate.dart';
import '../features/notifications/domain/reminder_plan.dart';
import '../features/notifications/notification_gateway.dart';
import '../features/notifications/reminder_service.dart';
import '../features/notifications/reminder_sync.dart';
import '../features/payments/data/obligation_repository.dart';
import '../features/payments/data/occurrence_planner.dart';
import '../features/payments/data/rule_repository.dart';
import '../features/payments/domain/rule.dart';
import '../features/security/app_lock.dart';
import '../features/settings/data/backup_service.dart';
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

// ------------------------------------------------------------ обязательства

final ruleRepositoryProvider = Provider(
  (ref) => RuleRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(settingsRepositoryProvider),
    ref.watch(transactionRepositoryProvider),
    ref.watch(ratesRepositoryProvider),
  ),
);

final occurrencePlannerProvider = Provider(
  (ref) => OccurrencePlanner(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(ruleRepositoryProvider),
    ref.watch(accountRepositoryProvider),
    ref.watch(ratesRepositoryProvider),
  ),
);

final obligationRepositoryProvider = Provider(
  (ref) => ObligationRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(accountRepositoryProvider),
    ref.watch(ruleRepositoryProvider),
  ),
);

/// В приложении — плагин (подставляется в `startup.dart`); по умолчанию —
/// шлюз без разрешения: тесты и экраны без уведомлений ничего не планируют.
final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => const DisabledGateway(),
);

final reminderServiceProvider = Provider(
  (ref) => ReminderService(
    rules: ref.watch(ruleRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    rates: ref.watch(ratesRepositoryProvider),
    clock: ref.watch(clockProvider),
    gateway: ref.watch(notificationGatewayProvider),
    deviceLanguage: () => PlatformDispatcher.instance.locale.languageCode,
  ),
);

/// Слежение за данными для уведомлений; запускает `completeStartup`.
final reminderSyncProvider = Provider((ref) {
  final sync = ReminderSync(ref.watch(appDatabaseProvider), ref.watch(reminderServiceProvider));
  ref.onDispose(() => unawaited(sync.dispose()));
  return sync;
});

/// Разрешение на уведомления — для переключателя в настройках.
final notificationPermissionProvider = FutureProvider<bool>(
  (ref) => ref.watch(notificationGatewayProvider).hasPermission(),
);

final rulesProvider = StreamProvider<List<Rule>>(
  (ref) => ref.watch(ruleRepositoryProvider).watchRules(),
);

final ruleProvider = StreamProvider.family<Rule?, String>(
  (ref, id) => ref.watch(ruleRepositoryProvider).watchRule(id),
);

final ruleOccurrencesProvider = StreamProvider.family<List<Occurrence>, String>(
  (ref, ruleId) => ref.watch(ruleRepositoryProvider).watchOfRule(ruleId),
);

final dueItemProvider = StreamProvider.family<DueItem?, String>(
  (ref, occurrenceId) => ref.watch(ruleRepositoryProvider).watchItem(occurrenceId),
);

/// Запланированные наступления до `сегодня + 92` (включая просроченные).
final upcomingProvider = StreamProvider<List<DueItem>>((ref) {
  final today = ref.watch(todayProvider);
  return ref.watch(ruleRepositoryProvider).watchItems(until: today.addDays(92));
});

final lastPaidProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(ruleRepositoryProvider).watchLastPaid(),
);

// ------------------------------------------------------ бюджеты и курсы

final budgetRepositoryProvider = Provider(
  (ref) => BudgetRepository(ref.watch(appDatabaseProvider), ref.watch(clockProvider)),
);

final budgetsProvider = StreamProvider<List<Budget>>(
  (ref) => ref.watch(budgetRepositoryProvider).watchAll(),
);

/// Курсы НБКР; в тестах подменяется — сети в тестах нет (I12).
final kgsRatesSourceProvider = Provider<KgsRatesSource>((ref) => NbkrClient());

final ratesUpdaterProvider = Provider(
  (ref) => RatesUpdater(
    ref.watch(kgsRatesSourceProvider),
    ref.watch(ratesRepositoryProvider),
    ref.watch(settingsRepositoryProvider),
    ref.watch(clockProvider),
  ),
);

/// Валюты счетов и правил, кроме базовой: им нужен курс (§8.3 «Currencies»).
final foreignCurrenciesProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(ratesRepositoryProvider).watchForeignCurrencies(),
);

// ------------------------------------------------- замок и резервная копия

/// Face ID / код-пароль; в тестах подменяется.
final authenticatorProvider = Provider<Authenticator>((ref) => LocalAuthenticator());

/// Файлы копий; в тестах — в памяти.
final backupFileSystemProvider = Provider<BackupFileSystem>((ref) => const BackupFiles());

final backupServiceProvider = Provider(
  (ref) => BackupService(ref.watch(appDatabaseProvider), ref.watch(clockProvider), ref.watch(backupFileSystemProvider)),
);

final backupListProvider = FutureProvider<List<String>>((ref) => ref.watch(backupServiceProvider).files());

/// Перезапуск состояния приложения (§7, восстановление копии): `StartupGate`
/// снимает экраны и контейнер, выполняет [work] (подмена файла базы — когда
/// ни один поток уже не читает старую), запускает приложение заново и
/// показывает [toast]; ошибка [work] — тост [failToast].
typedef AppRestart = Future<void> Function({
  Future<void> Function()? work,
  String? toast,
  String Function(Object error)? failToast,
});

final appRestartProvider = Provider<AppRestart>(
  (ref) => ({work, toast, failToast}) async => work?.call(),
);

/// Шлюз без уведомлений: разрешения нет, ничего не планирует.
class DisabledGateway implements NotificationGateway {
  const DisabledGateway();

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> schedule(PlannedNotification n) async {}

  @override
  Future<List<int>> pendingIds() async => const [];
}
