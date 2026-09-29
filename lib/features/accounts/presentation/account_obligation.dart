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
import '../../../app/widgets/toast.dart';
import '../../payments/domain/rule.dart';
import '../../payments/presentation/due_row.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/account.dart';
import '../domain/balances.dart';
import '../domain/loan_math.dart';
import 'account_providers.dart';

/// Наступления правила, гасящего счёт [accountId], по порядку; `null` —
/// ещё загружаются.
List<DueItem>? _itemsOf(WidgetRef ref, String accountId) {
  final all = ref.watch(obligationItemsProvider).value;
  if (all == null) return null;
  return [
    for (final i in all)
      if (i.rule.counterAccountId == accountId) i,
  ];
}

/// Ряд действий пассива (§8.3 «Account»): кредит — «Pay N» (ближайший
/// платёж на месте), «Extra payment», «Recalculate»; кредитная линия —
/// «Pay…», «Purchase».
class ObligationActions extends ConsumerWidget {
  const ObligationActions({super.key, required this.account});
  final Account account;

  Future<void> _recalculate(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final balance = ref.read(balancesProvider).value?[account.id] ?? account.openingBalance;
    if (debtOf(account, balance) == 0) {
      showActionToast(context, l.loanRecalcNothing, icon: Icons.info_outline_rounded);
      return;
    }
    final mode = await showPickSheet<RecalcMode>(
      context,
      title: l.loanRecalcTitle,
      items: [
        PickItem(value: RecalcMode.keepPayment, label: l.loanRecalcKeepPayment),
        PickItem(value: RecalcMode.keepTerm, label: l.loanRecalcKeepTerm),
      ],
    );
    if (mode == null) return;
    await ref.read(obligationRepositoryProvider).recalculateLoan(account.id, mode);
    if (context.mounted) showActionToast(context, l.changesSaved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final a = account;
    final items = _itemsOf(ref, a.id);
    if (items == null) return const SizedBox.shrink();
    final next = items.where((i) => i.occurrence.status == OccStatus.planned).firstOrNull;
    final base = ref.watch(settingsProvider).value?.baseCurrency;
    if (a.kind == AccountKind.loan) {
      final amount = next?.occurrence.amountExpected;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RoundAction(
            key: const ValueKey('loan-pay'),
            icon: Icons.check_rounded,
            label: amount == null ? l.actionPayEllipsis : l.actionPayAmount(pillAmount(context, amount, a.currency, base: base)),
            onTap: next == null ? null : () => unawaited(payFromRow(context, ref, next)),
          ),
          RoundAction(
            icon: Icons.bolt_rounded,
            label: l.actionExtraPayment,
            primary: false,
            onTap: () => unawaited(context.push(Routes.newTxn(kind: TxKind.transfer, to: a.id))),
          ),
          RoundAction(
            icon: Icons.tune_rounded,
            label: l.actionRecalculate,
            primary: false,
            onTap: () => unawaited(_recalculate(context, ref)),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RoundAction(
          key: const ValueKey('credit-pay'),
          icon: Icons.check_rounded,
          label: l.actionPayEllipsis,
          onTap: () => unawaited(context.push(
            next == null ? Routes.newTxn(kind: TxKind.transfer, to: a.id) : Routes.occurrence(next.occurrence.id),
          )),
        ),
        RoundAction(
          icon: Icons.shopping_bag_outlined,
          label: l.actionAddPurchase,
          primary: false,
          onTap: () => unawaited(context.push(Routes.newTxn(account: a.id))),
        ),
      ],
    );
  }
}

/// «Schedule» кредита: все платежи, оплаченные — галочкой, пропущенные —
/// серым; ближайший — жирнее. Тап — наступление.
class LoanScheduleSection extends ConsumerWidget {
  const LoanScheduleSection({super.key, required this.account});
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final items = _itemsOf(ref, account.id);
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final today = ref.watch(todayProvider);
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final nextId = items.where((i) => i.occurrence.status == OccStatus.planned).firstOrNull?.occurrence.id;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: l.accountSchedule,
            action: account.principal == null
                ? null
                : l.accountScheduleHint(context.money(account.principal!, account.currency, whole: account.principal! % 100 == 0)),
          ),
          RowsCard(
            children: [
              for (final i in items)
                _ScheduleRow(
                  item: i,
                  total: account.termMonths ?? items.length,
                  isNext: i.occurrence.id == nextId,
                  overdue: i.occurrence.isOverdue(today),
                  colors: colors,
                  scheme: scheme,
                  text: text,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.item,
    required this.total,
    required this.isNext,
    required this.overdue,
    required this.colors,
    required this.scheme,
    required this.text,
  });

  final DueItem item;
  final int total;
  final bool isNext;
  final bool overdue;
  final AppColors colors;
  final ColorScheme scheme;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final o = item.occurrence;
    final paid = o.status == OccStatus.paid;
    final skipped = o.status == OccStatus.skipped;
    final muted = paid || skipped;
    final icon = paid
        ? Icon(Icons.check_circle_rounded, color: colors.onMint, size: 22)
        : skipped
        ? Icon(Icons.remove_circle_outline_rounded, color: scheme.onSurfaceVariant, size: 22)
        : Icon(Icons.radio_button_unchecked_rounded, color: overdue ? colors.onBlush : scheme.outline, size: 22);
    final style = (isNext ? text.bodyLarge?.copyWith(fontWeight: FontWeight.w600) : text.bodyLarge)
        ?.copyWith(color: muted ? scheme.onSurfaceVariant : (overdue ? colors.onBlush : null));
    return InkWell(
      key: ValueKey('schedule-${o.id}'),
      onTap: () => unawaited(context.push(Routes.occurrence(o.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s10),
        child: Row(
          children: [
            icon,
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                '${l.seqOf(o.seq, total)} · ${context.day(o.dueDate)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
            const SizedBox(width: AppSpacing.s10),
            if (o.amountExpected != null)
              AmountText(
                context.money(o.amountExpected!, o.currency, symbol: false),
                style: style,
              ),
          ],
        ),
      ),
    );
  }
}
