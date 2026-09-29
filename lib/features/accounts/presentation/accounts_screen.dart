import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/format.dart';
import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/header.dart';
import '../../../core/calendar.dart';
import '../domain/account.dart';
import '../domain/balances.dart';
import 'account_providers.dart';
import 'account_tile.dart';

/// Вкладка «Accounts» (§8.3): деньги и кредиты плитками, итоги секций,
/// архив строкой-ссылкой; «+» в шапке — меню видов счёта.
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _showArchived = false;

  void _new(String kind) {
    final route = switch (kind) {
      'loan' => Routes.newLoan,
      'credit_line' => Routes.newCreditLine,
      'savings' => Routes.newAccount(AccountKind.savings),
      'deposit' => Routes.newAccount(AccountKind.deposit),
      _ => Routes.newAccount(AccountKind.card),
    };
    unawaited(context.push(route));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GlassScaffold(
      header: ScreenHeader(
        title: l.accountsTitle,
        trailing: GlassMenuButton<String>(
          tooltip: l.accountsNewMenu,
          icon: Icons.add_rounded,
          onSelected: _new,
          actions: [
            MenuAction(value: 'card', label: l.accountsNewCashOrCard, icon: Icons.account_balance_wallet_outlined),
            MenuAction(value: 'savings', label: l.accountKindSavings, icon: Icons.savings_outlined),
            MenuAction(value: 'deposit', label: l.accountKindDeposit, icon: Icons.lock_clock_outlined),
            MenuAction(value: 'loan', label: l.accountKindLoan, icon: Icons.request_quote_outlined),
            MenuAction(value: 'credit_line', label: l.accountKindCreditLine, icon: Icons.credit_score_outlined),
          ],
        ),
      ),
      body: (context) => _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final l = context.l10n;
    final accounts = ref.watch(accountsProvider).value;
    final balances = ref.watch(balancesProvider).value;
    final converter = ref.watch(converterProvider).value;
    final settings = ref.watch(settingsProvider).value;
    final info = ref.watch(obligationInfoProvider).value;
    final today = ref.watch(todayProvider);
    if (accounts == null || balances == null || converter == null || settings == null || info == null) {
      return const SizedBox.shrink();
    }
    final period = MonthPeriod.containing(today, settings.monthStartDay);
    final delta = ref.watch(accountDeltaProvider((period.start, period.end))).value;
    if (delta == null) return const SizedBox.shrink();
    final live = accounts.where((a) => !a.isArchived).toList();
    final archived = accounts.where((a) => a.isArchived).toList();
    final totals = computeTotals(accounts, balances, converter);
    final base = converter.base;

    Widget tile(Account a, {bool compact = false}) => AccountTile(
      account: a,
      compact: compact,
      facts: AccountFacts.of(
        context,
        a,
        balance: balances[a.id] ?? a.openingBalance,
        monthDelta: delta[a.id],
        today: today,
        info: info[a.id],
      ),
      onTap: () => unawaited(context.push(Routes.account(a.id))),
    );

    final everyday = live.where((a) => a.kind.isEveryday).toList();
    final saving = live.where((a) => a.kind.isSaving).toList();
    final credit = live.where((a) => a.kind.isLiability).toList();

    List<Widget> pairs(List<Account> list) => [
      for (var i = 0; i < list.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tile(list[i], compact: true)),
                const SizedBox(width: AppSpacing.s12),
                Expanded(child: i + 1 < list.length ? tile(list[i + 1], compact: true) : const SizedBox()),
              ],
            ),
          ),
        ),
    ];

    return ListView(
      padding: AppSpacing.scroll(context).copyWith(left: AppSpacing.s16, right: AppSpacing.s16),
      children: [
        _SectionTitle(left: l.accountsMoney, right: context.money(totals.ownFunds, base, whole: true)),
        ...pairs(everyday),
        for (final a in saving)
          Padding(padding: const EdgeInsets.only(bottom: AppSpacing.s12), child: tile(a)),
        if (credit.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s8),
          _SectionTitle(left: l.accountsCredit, right: l.accountDebtTotal(context.money(totals.debt, base, whole: true))),
          for (final a in credit)
            Padding(padding: const EdgeInsets.only(bottom: AppSpacing.s12), child: tile(a)),
        ],
        if (archived.isNotEmpty) ...[
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.row),
            onTap: () => setState(() => _showArchived = !_showArchived),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s18, vertical: AppSpacing.s14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.accountsArchived(archived.length),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Icon(
                    _showArchived ? Icons.expand_less_rounded : Icons.chevron_right_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_showArchived)
            for (final a in archived)
              Padding(padding: const EdgeInsets.only(bottom: AppSpacing.s12), child: Opacity(opacity: 0.6, child: tile(a))),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.left, required this.right});

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s8, AppSpacing.s4, AppSpacing.s10),
    child: Row(
      children: [
        Expanded(child: GroupLabel(left, padding: EdgeInsets.zero)),
        Text(
          right.toUpperCase(),
          maxLines: 1,
          softWrap: false,
          style: Theme.of(context).textTheme.groupLabel,
        ),
      ],
    ),
  );
}
