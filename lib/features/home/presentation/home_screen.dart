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
import '../../../app/widgets/hero.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/quick_add.dart';
import '../../transactions/presentation/txn_list.dart';
import 'home_providers.dart';
import 'upcoming_section.dart';

/// Главная (spec.md §8.3, макет «Home»): «Safe to spend», быстрый ввод,
/// ближайшие платежи, последние операции.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final today = ref.watch(todayProvider);
    return GlassScaffold(
      header: ScreenHeader(
        leading: GlassIconButton(
          icon: Icons.bar_chart_rounded,
          tooltip: l.homeStats,
          onPressed: () => unawaited(context.push(Routes.stats)),
        ),
        titleWidget: Text(
          context.weekdayDay(today),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: GlassIconButton(
          icon: Icons.settings_outlined,
          tooltip: l.homeSettings,
          onPressed: () => unawaited(context.push(Routes.settings)),
        ),
      ),
      body: (context) => const _HomeBody(),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final summary = ref.watch(homeSummaryProvider);
    final today = ref.watch(todayProvider);
    final txns = ref.watch(txnsProvider(TxnFilter(from: today.addDays(-30), until: today.addDays(1), limit: 60)));
    final cats = ref.watch(categoryMapProvider).value;
    final accounts = ref.watch(accountMapProvider).value;
    final top = MediaQuery.paddingOf(context).top + AppSizes.header;

    final s = summary.value;
    final list = txns.value;
    if (s == null || list == null || cats == null || accounts == null) {
      return const SizedBox.shrink();
    }
    final empty = list.isEmpty && !s.hasObligations;

    return ListView(
      padding: EdgeInsets.only(top: top + AppSpacing.s8, bottom: AppSpacing.scrollBottom(context)),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          child: HeroAmount(
            key: const ValueKey('home-hero'),
            label: l.homeSafeToSpend(context.day(s.periodEnd)),
            minor: s.safeToSpend,
            currency: s.baseCurrency,
            negativeIsAlert: true,
            lines: [
              (l.homeOwnFunds, context.money(s.totals.ownFunds, s.baseCurrency, whole: true, symbol: false)),
              (l.homeToPay, context.money(s.toPay, s.baseCurrency, whole: true, symbol: false)),
            ],
            caption: s.totals.missingRates.isEmpty
                ? null
                : Text(
                    l.homeNoRate,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.of(context).onBlush),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        QuickAddRow(kinds: const {TxKind.expense, TxKind.transfer, TxKind.income}, label: l.homeQuickAdd),
        const SizedBox(height: AppSpacing.s12),
        const UpcomingSection(),
        if (empty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EmptyCard(
                  title: l.homeEmptyTitle,
                  body: l.homeEmptyBody,
                  action: l.actionAddExpense,
                  onAction: () => unawaited(context.push(Routes.newTxn())),
                ),
                const SizedBox(height: AppSpacing.s12),
                Center(
                  child: AppChip(
                    dense: true,
                    label: l.homeCurrency(s.baseCurrency),
                    trailingIcon: Icons.chevron_right_rounded,
                    onTap: () => unawaited(context.push(Routes.rates)),
                  ),
                ),
              ],
            ),
          )
        else if (list.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: SectionHeader(
              title: l.homeRecent,
              action: l.all,
              onAction: () => unawaited(context.push(Routes.transactions)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: TxnDayList(
              txns: list,
              categories: cats,
              accounts: accounts,
              today: today,
              baseCurrency: s.baseCurrency,
              excludeFromDayTotal: {
                for (final c in cats.values)
                  if (c.isSystem) c.id,
              },
            ),
          ),
        ],
      ],
    );
  }
}
