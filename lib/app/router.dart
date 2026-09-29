import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/accounts/domain/account.dart';
import '../features/accounts/presentation/account_edit_screen.dart';
import '../features/accounts/presentation/account_screen.dart';
import '../features/accounts/presentation/accounts_screen.dart';
import '../features/accounts/presentation/credit_line_screen.dart';
import '../features/accounts/presentation/loan_screen.dart';
import '../features/budgets/presentation/budgets_screen.dart';
import '../features/categories/presentation/categories_screen.dart';
import '../features/categories/presentation/category_edit_screen.dart';
import '../features/categories/domain/category.dart';
import '../features/currencies/presentation/rates_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/payments/presentation/occurrence_screen.dart';
import '../features/payments/presentation/payments_screen.dart';
import '../features/payments/presentation/rule_edit_screen.dart';
import '../features/payments/presentation/rule_screen.dart';
import '../features/payments/domain/rule.dart';
import '../features/settings/presentation/backup_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/stats/presentation/stats_screen.dart';
import '../features/transactions/domain/transaction.dart';
import '../features/transactions/presentation/add_transaction_screen.dart';
import '../features/transactions/presentation/transaction_screen.dart';
import '../features/transactions/presentation/transactions_screen.dart';
import 'tab_shell.dart';

/// Маршруты spec.md §8.2.
abstract final class Routes {
  static const String home = '/';
  static const String payments = '/payments';
  static const String accounts = '/accounts';
  static const String transactions = '/transactions';
  static const String stats = '/stats';
  static const String budgets = '/budgets';
  static const String categories = '/categories';
  static const String settings = '/settings';
  static const String rates = '/settings/currencies';
  static const String backup = '/settings/backup';
  static const String newLoan = '/loan/new';
  static const String newCreditLine = '/credit-line/new';

  static String newTxn({
    TxKind kind = TxKind.expense,
    String? account,
    String? to,
  }) => Uri(
    path: '/transaction/new',
    queryParameters: {
      'kind': kind.db,
      'account': ?account,
      'to': ?to,
    },
  ).toString();

  static String txn(String id) => '/transaction/$id';

  static String transactionsFor({String? account, String? category}) => Uri(
    path: transactions,
    queryParameters: {'account': ?account, 'category': ?category},
  ).toString();

  static String newAccount(AccountKind kind) =>
      Uri(path: '/account/new', queryParameters: {'kind': kind.db}).toString();
  static String account(String id) => '/account/$id';
  static String editAccount(String id) => '/account/$id/edit';

  static String newRule(RuleKind kind) =>
      Uri(path: '/rule/new', queryParameters: {'kind': kind.db}).toString();
  static String rule(String id) => '/rule/$id';
  static String editRule(String id) => '/rule/$id/edit';
  static String occurrence(String id) => '/occurrence/$id';

  static String newCategory(CategoryKind kind) =>
      Uri(path: '/category/new', queryParameters: {'kind': kind.db}).toString();
  static String category(String id) => '/category/$id';
}

GoRouter createRouter({String initialLocation = Routes.home}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => TabShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.payments,
                pageBuilder: (context, state) => const NoTransitionPage(child: PaymentsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.accounts,
                pageBuilder: (context, state) => const NoTransitionPage(child: AccountsScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/transaction/new',
        pageBuilder: (context, state) {
          final q = state.uri.queryParameters;
          return _page(
            state,
            AddTransactionScreen(
              kind: TxKind.values.firstWhere((k) => k.db == q['kind'], orElse: () => TxKind.expense),
              accountId: q['account'],
              toAccountId: q['to'],
            ),
            fullscreen: true,
          );
        },
      ),
      GoRoute(
        path: '/transaction/:id',
        pageBuilder: (context, state) =>
            _page(state, TransactionScreen(id: state.pathParameters['id']!)),
      ),
      GoRoute(
        path: Routes.transactions,
        pageBuilder: (context, state) => _page(
          state,
          TransactionsScreen(
            accountId: state.uri.queryParameters['account'],
            categoryId: state.uri.queryParameters['category'],
          ),
        ),
      ),
      GoRoute(
        path: '/account/new',
        pageBuilder: (context, state) => _page(
          state,
          AccountEditScreen(
            kind: AccountKind.values.firstWhere(
              (k) => k.db == state.uri.queryParameters['kind'],
              orElse: () => AccountKind.card,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/account/:id',
        pageBuilder: (context, state) =>
            _page(state, AccountScreen(id: state.pathParameters['id']!)),
        routes: [
          GoRoute(
            path: 'edit',
            pageBuilder: (context, state) =>
                _page(state, AccountEditScreen(id: state.pathParameters['id']!)),
          ),
        ],
      ),
      GoRoute(
        path: Routes.newLoan,
        pageBuilder: (context, state) => _page(state, const NewLoanScreen()),
      ),
      GoRoute(
        path: Routes.newCreditLine,
        pageBuilder: (context, state) => _page(state, const NewCreditLineScreen()),
      ),
      GoRoute(
        path: '/rule/new',
        pageBuilder: (context, state) => _page(
          state,
          RuleEditScreen(
            kind: RuleKind.values.firstWhere(
              (k) => k.db == state.uri.queryParameters['kind'],
              orElse: () => RuleKind.subscription,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/rule/:id',
        pageBuilder: (context, state) => _page(state, RuleScreen(id: state.pathParameters['id']!)),
        routes: [
          GoRoute(
            path: 'edit',
            pageBuilder: (context, state) =>
                _page(state, RuleEditScreen(id: state.pathParameters['id']!)),
          ),
        ],
      ),
      GoRoute(
        path: '/occurrence/:id',
        pageBuilder: (context, state) =>
            _page(state, OccurrenceScreen(id: state.pathParameters['id']!)),
      ),
      GoRoute(
        path: Routes.stats,
        pageBuilder: (context, state) => _page(state, const StatsScreen()),
      ),
      GoRoute(
        path: Routes.budgets,
        pageBuilder: (context, state) => _page(state, const BudgetsScreen()),
      ),
      GoRoute(
        path: Routes.categories,
        pageBuilder: (context, state) => _page(state, const CategoriesScreen()),
      ),
      GoRoute(
        path: '/category/new',
        pageBuilder: (context, state) => _page(
          state,
          CategoryEditScreen(
            kind: CategoryKind.values.firstWhere(
              (k) => k.db == state.uri.queryParameters['kind'],
              orElse: () => CategoryKind.expense,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/category/:id',
        pageBuilder: (context, state) =>
            _page(state, CategoryEditScreen(id: state.pathParameters['id']!)),
      ),
      GoRoute(
        path: Routes.settings,
        pageBuilder: (context, state) => _page(state, const SettingsScreen()),
        routes: [
          GoRoute(
            path: 'currencies',
            pageBuilder: (context, state) => _page(state, const RatesScreen()),
          ),
          GoRoute(
            path: 'backup',
            pageBuilder: (context, state) => _page(state, const BackupScreen()),
          ),
        ],
      ),
    ],
  );
}

/// Страница с переходами из темы (Cupertino на iOS — свайп «назад»).
MaterialPage<void> _page(GoRouterState state, Widget child, {bool fullscreen = false}) =>
    MaterialPage<void>(
      key: state.pageKey,
      name: state.path,
      fullscreenDialog: fullscreen,
      child: child,
    );

/// Закрыть экран: назад, если есть куда; иначе — на Главную (экран открыли
/// первым: ссылка из уведомления, холодный старт).
extension CloseScreen on BuildContext {
  void closeScreen() {
    final router = GoRouter.of(this);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(Routes.home);
    }
  }
}
