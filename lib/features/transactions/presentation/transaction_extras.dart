import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/format.dart';
import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/toast.dart';
import '../domain/transaction.dart';

/// Плашка «Payment for `rule` · `date`» с «Undo payment» (§8.3
/// «Transaction»): операция оплаты удаляется только так — вместе с
/// возвратом наступления в `planned` (I9). Тост с «Undo» платит заново.
class OccurrenceLinkCard extends ConsumerWidget {
  const OccurrenceLinkCard({super.key, required this.txn});

  final Txn txn;

  Future<void> _undo(BuildContext context, WidgetRef ref, String occurrenceId, String name) async {
    final l = context.l10n;
    final repo = ref.read(ruleRepositoryProvider);
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    final t = txn;
    await repo.unpay(occurrenceId);
    if (!context.mounted) return;
    context.closeScreen();
    if (overlay == null) return;
    showActionToastOn(
      overlay,
      l.unpaidToast(name),
      icon: Icons.undo_rounded,
      actions: [
        ToastAction(
          l.undo,
          () => unawaited(repo.pay(
            occurrenceId,
            amount: t.amount,
            accountId: t.accountId,
            date: t.date,
            counterAmount: t.counterAmount,
          )),
          primary: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final id = txn.occurrenceId;
    if (id == null) return const SizedBox.shrink();
    final item = ref.watch(dueItemProvider(id)).value;
    if (item == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s8, AppSpacing.s12),
        child: Row(
          children: [
            IconBubble(iconKey: item.rule.iconKey, colorKey: item.rule.colorKey, size: 36),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(context.push(Routes.occurrence(id))),
                child: Text(
                  l.txPaymentFor(item.rule.name, context.day(item.occurrence.dueDate)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            TextButton(
              key: const ValueKey('undo-payment'),
              style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => unawaited(_undo(context, ref, id, item.rule.name)),
              child: Text(l.txUndoPayment, maxLines: 1, softWrap: false),
            ),
          ],
        ),
      ),
    );
  }
}
