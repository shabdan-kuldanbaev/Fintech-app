import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/format.dart';
import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/dialogs.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/header.dart';
import '../../../app/widgets/hero.dart';
import '../../../app/widgets/toast.dart';
import '../../../core/calendar.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/txn_list.dart';
import '../domain/account.dart';
import '../domain/balances.dart';
import 'account_obligation.dart';
import 'account_providers.dart';

/// «Account» (§8.3): hero по виду счёта, ряд круглых действий, лента
/// операций счёта; меню «⋯» — изменить, архив, удалить.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key, required this.id});

  final String id;

  Future<void> _menu(BuildContext context, WidgetRef ref, Account a, String action) async {
    final l = context.l10n;
    final repo = ref.read(accountRepositoryProvider);
    switch (action) {
      case 'edit':
        unawaited(context.push(Routes.editAccount(a.id)));
      case 'archive':
        await repo.setArchived(a.id, !a.isArchived);
      case 'delete':
        if (await repo.hasTransactions(a.id)) {
          if (context.mounted) showActionToast(context, l.accountDeleteBlocked, icon: Icons.info_outline_rounded);
          return;
        }
        if (!context.mounted) return;
        final ok = await showConfirm(
          context,
          title: l.accountDeleteTitle,
          body: l.accountDeleteBody,
          cancel: l.cancel,
          confirm: l.delete,
          destructive: true,
        );
        if (!ok) return;
        await repo.delete(a.id);
        if (context.mounted) context.closeScreen();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final account = ref.watch(accountProvider(id));
    final a = account.value;
    return GlassScaffold(
      header: ScreenHeader(
        leading: HeaderBack(tooltip: l.back),
        title: a?.name,
        trailing: a == null
            ? null
            : GlassMenuButton<String>(
                tooltip: l.more,
                onSelected: (v) => unawaited(_menu(context, ref, a, v)),
                actions: [
                  MenuAction(value: 'edit', label: l.edit, icon: Icons.edit_outlined),
                  MenuAction(
                    value: 'archive',
                    label: a.isArchived ? l.accountUnarchive : l.accountArchive,
                    icon: Icons.archive_outlined,
                  ),
                  MenuAction(value: 'delete', label: l.delete, icon: Icons.delete_outline_rounded, destructive: true),
                ],
              ),
      ),
      body: (context) {
        if (account.isLoading) return const SizedBox.shrink();
        if (a == null) {
          return Center(child: Text(l.notFoundTitle, style: Theme.of(context).textTheme.titleMedium));
        }
        return _AccountBody(account: a);
      },
    );
  }
}

class _AccountBody extends ConsumerWidget {
  const _AccountBody({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final a = account;
    final balances = ref.watch(balancesProvider).value;
    final settings = ref.watch(settingsProvider).value;
    final cats = ref.watch(categoryMapProvider).value;
    final accounts = ref.watch(accountMapProvider).value;
    final info = ref.watch(obligationInfoProvider).value?[a.id];
    final today = ref.watch(todayProvider);
    final txns = ref.watch(txnsProvider(TxnFilter(accountId: a.id, limit: 300))).value;
    if (balances == null || settings == null || cats == null || accounts == null || txns == null) {
      return const SizedBox.shrink();
    }
    final balance = balances[a.id] ?? a.openingBalance;
    final period = MonthPeriod.containing(today, settings.monthStartDay);
    var spent = 0;
    var received = 0;
    for (final t in txns) {
      if (!period.contains(t.date) || (cats[t.categoryId]?.isSystem ?? false)) continue;
      if (t.accountId == a.id && t.kind != TxKind.income) spent += t.amount;
      if (t.accountId == a.id && t.kind == TxKind.income) received += t.amount;
      if (t.counterAccountId == a.id) received += t.counterAmount ?? t.amount;
    }
    String m(int v) => context.money(v, a.currency, symbol: false);

    final (String label, int value, List<(String, String)> lines) = switch (a.kind) {
      AccountKind.cash || AccountKind.card => (
        l.accountBalance,
        balance,
        [(l.accountSpentMonth, m(spent)), (l.accountIncomeMonth, m(received))],
      ),
      AccountKind.savings => (
        l.accountBalance,
        balance,
        [
          if (a.targetAmount != null) (l.accountGoal, m(a.targetAmount!)),
          if (a.targetAmount != null) (l.accountLeft, m((a.targetAmount! - balance).clamp(0, 1 << 62))),
          if (a.targetDate != null) (l.accountEnds, context.monthYearUntil(a.targetDate!)),
        ],
      ),
      AccountKind.deposit => (
        l.accountBalance,
        balance,
        [if (a.targetDate != null) (l.accountEnds, context.dayYear(a.targetDate!))],
      ),
      AccountKind.creditLine => (
        l.accountDebt,
        debtOf(a, balance),
        [
          (l.accountLimit, m(a.creditLimit ?? 0)),
          (l.accountAvailable, m(availableOf(a, balance))),
          if (a.dueDay != null) (l.accountDueDay, l.dayOfMonth(a.dueDay!)),
        ],
      ),
      AccountKind.loan => (
        l.accountRemaining,
        debtOf(a, balance),
        [
          if (info != null) (l.accountPaid, l.accountPaidOf(info.paid, info.total)),
          if (info?.next != null) (l.accountNext, context.day(info!.next!)),
          (l.accountMonthly, m(a.monthlyPayment ?? 0)),
        ],
      ),
    };

    final overpaid = a.kind.isLiability && balance > 0;
    return ListView(
      padding: AppSpacing.scroll(context, top: AppSpacing.s16).copyWith(left: AppSpacing.s16, right: AppSpacing.s16),
      children: [
        HeroAmount(
          label: label,
          minor: value,
          currency: a.currency,
          whole: false,
          lines: lines,
          caption: overpaid
              ? Text(l.accountOverpaid(m(balance)), style: Theme.of(context).textTheme.bodySmall)
              : null,
        ),
        if (a.kind == AccountKind.savings && (a.targetAmount ?? 0) > 0) ...[
          const SizedBox(height: AppSpacing.s14),
          Center(
            child: SizedBox(
              width: 220,
              child: ProgressBar(value: balance / a.targetAmount!, color: AppColors.of(context).onButter),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s20),
        if (a.kind.isLiability)
          ObligationActions(account: a)
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RoundAction(
                icon: Icons.remove_rounded,
                label: l.actionExpense,
                onTap: () => unawaited(context.push(Routes.newTxn(account: a.id))),
              ),
              RoundAction(
                icon: Icons.add_rounded,
                label: a.kind.isSaving ? l.actionTopUp : l.actionAddIncome,
                primary: false,
                onTap: () => unawaited(context.push(
                  a.kind.isSaving
                      ? Routes.newTxn(kind: TxKind.transfer, to: a.id)
                      : Routes.newTxn(kind: TxKind.income, account: a.id),
                )),
              ),
              RoundAction(
                icon: Icons.swap_horiz_rounded,
                label: l.actionTransfer,
                primary: false,
                onTap: () => unawaited(context.push(Routes.newTxn(kind: TxKind.transfer, account: a.id))),
              ),
            ],
          ),
        if (a.kind == AccountKind.loan) LoanScheduleSection(account: a),
        if (txns.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s16),
          SectionHeader(title: l.accountTransactions),
          TxnDayList(
            txns: txns,
            categories: cats,
            accounts: accounts,
            today: today,
            baseCurrency: settings.baseCurrency,
            scope: a.id,
            excludeFromDayTotal: {
              for (final c in cats.values)
                if (c.isSystem) c.id,
            },
          ),
        ],
      ],
    );
  }
}
