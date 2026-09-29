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
import '../../../core/calendar.dart';
import '../../transactions/presentation/pickers.dart';
import '../domain/rule.dart';
import 'due_row.dart';
import 'payments_screen.dart';

/// «Payment rule» (§8.3): сумма и расписание, ближайшее наступление с
/// «Pay», история наступлений; меню — изменить, пауза, удалить.
class RuleScreen extends ConsumerWidget {
  const RuleScreen({super.key, required this.id});

  final String id;

  Future<void> _menu(BuildContext context, WidgetRef ref, Rule rule, String action) async {
    final l = context.l10n;
    final repo = ref.read(ruleRepositoryProvider);
    final today = ref.read(todayProvider);
    switch (action) {
      case 'edit':
        unawaited(context.push(Routes.editRule(rule.id)));
      case 'pause':
        final until = await showPickSheet<int>(
          context,
          title: l.rulePauseUntil,
          items: [
            PickItem(value: 1, label: context.monthYearUntil(today.addMonths(1))),
            PickItem(value: 3, label: context.monthYearUntil(today.addMonths(3))),
            PickItem(value: 0, label: l.pickDate),
            PickItem(value: -1, label: l.rulePauseForever),
          ],
        );
        if (until == null || !context.mounted) return;
        LocalDate? date;
        if (until == -1) {
          date = Rule.pausedForever;
        } else if (until == 0) {
          date = await pickDate(context, today.addMonths(1), first: today.addDays(1));
        } else {
          date = today.addMonths(until);
        }
        if (date == null) return;
        await repo.pause(rule.id, date);
        await ref.read(occurrencePlannerProvider).replan();
      case 'resume':
        await repo.resume(rule.id);
        await ref.read(occurrencePlannerProvider).replan();
      case 'delete':
        final ok = await showConfirm(
          context,
          title: l.ruleDeleteTitle,
          body: l.ruleDeleteBody,
          cancel: l.cancel,
          confirm: l.delete,
          destructive: true,
        );
        if (!ok) return;
        await repo.delete(rule.id);
        if (context.mounted) context.closeScreen();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(ruleProvider(id));
    final rule = async.value;
    final today = ref.watch(todayProvider);
    return GlassScaffold(
      header: ScreenHeader(
        leading: HeaderBack(tooltip: l.back),
        title: rule?.name,
        trailing: rule == null
            ? null
            : GlassMenuButton<String>(
                tooltip: l.more,
                onSelected: (v) => unawaited(_menu(context, ref, rule, v)),
                actions: [
                  MenuAction(value: 'edit', label: l.edit, icon: Icons.edit_outlined),
                  if (rule.pausedUntil != null && rule.pausedUntil! >= today)
                    MenuAction(value: 'resume', label: l.ruleResume, icon: Icons.play_arrow_rounded)
                  else
                    MenuAction(value: 'pause', label: l.rulePauseUntil, icon: Icons.pause_rounded),
                  MenuAction(value: 'delete', label: l.delete, icon: Icons.delete_outline_rounded, destructive: true),
                ],
              ),
      ),
      body: (context) {
        if (async.isLoading && rule == null) return const SizedBox.shrink();
        if (rule == null) {
          return Center(child: Text(l.notFoundTitle, style: Theme.of(context).textTheme.titleMedium));
        }
        return _RuleBody(rule: rule);
      },
    );
  }
}

class _RuleBody extends ConsumerWidget {
  const _RuleBody({required this.rule});

  final Rule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final occurrences = ref.watch(ruleOccurrencesProvider(rule.id)).value;
    final accounts = ref.watch(accountMapProvider).value;
    final categories = ref.watch(categoryMapProvider).value;
    final lastPaid = ref.watch(lastPaidProvider).value;
    final today = ref.watch(todayProvider);
    if (occurrences == null || accounts == null || categories == null || lastPaid == null) {
      return const SizedBox.shrink();
    }
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final paused = rule.isPausedOn(today);
    final next = occurrences.where((o) => o.status == OccStatus.planned).firstOrNull;
    final history = occurrences.where((o) => o.status != OccStatus.planned).toList().reversed.toList();
    final category = categories[rule.categoryId];
    final account = accounts[rule.accountId];
    final amount = rule.amount ?? lastPaid[rule.id];

    return ListView(
      padding: AppSpacing.scroll(context, top: AppSpacing.s16).copyWith(left: AppSpacing.s16, right: AppSpacing.s16),
      children: [
        HeroAmount(
          label: paused
              ? (rule.pausedUntil == Rule.pausedForever ? l.paused : l.pausedUntil(context.day(rule.pausedUntil!)))
              : frequencyLabel(context, rule),
          minor: amount ?? 0,
          currency: rule.currency,
          whole: (amount ?? 0) % 100 == 0,
          lines: [
            if (rule.amount == null) (l.occAmount, l.ruleAmountVaries),
            if (category != null) (l.txCategory, categoryName(l, category)),
            (l.fieldPayFrom, account?.name ?? l.none),
            if (rule.endDate != null) (l.ruleEnds, context.dayYear(rule.endDate!)),
          ],
        ),
        if (next != null) ...[
          const SizedBox(height: AppSpacing.s20),
          GroupLabel(l.homeUpcoming),
          RowsCard(children: [DueRow(item: DueItem(next, rule))]),
        ],
        if (history.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s12),
          GroupLabel(l.ruleHistory),
          RowsCard(
            children: [
              for (final o in history)
                AppRow(
                  key: ValueKey('history-${o.id}'),
                  leading: Icon(
                    o.status == OccStatus.paid ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                    color: o.status == OccStatus.paid ? colors.onMint : scheme.onSurfaceVariant,
                  ),
                  title: context.day(o.dueDate),
                  subtitle: o.status == OccStatus.paid ? null : l.occSkipped,
                  trailing: o.amountExpected == null
                      ? null
                      : AmountText(
                          pillAmount(context, o.amountExpected!, o.currency),
                          color: o.status == OccStatus.paid ? null : scheme.onSurfaceVariant,
                          style: text.bodyLarge,
                        ),
                  onTap: () => unawaited(context.push(Routes.occurrence(o.id))),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
