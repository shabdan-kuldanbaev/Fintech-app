import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/format.dart';
import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../payments/domain/planning.dart';
import '../../payments/domain/rule.dart';
import '../../payments/presentation/due_row.dart';

/// Сколько строк «Upcoming» на Главной (§8.3).
const int homeUpcomingRows = 5;

/// «Upcoming» на Главной (§8.3): `planned` наступления на 30 дней, сначала
/// просроченные, до 5 строк; справа в заголовке «30 days · N» → Payments.
class UpcomingSection extends ConsumerWidget {
  const UpcomingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final items = ref.watch(upcomingProvider).value;
    final converter = ref.watch(converterProvider).value;
    final lastPaid = ref.watch(lastPaidProvider).value;
    final accounts = ref.watch(accountMapProvider).value;
    final today = ref.watch(todayProvider);
    if (items == null || converter == null || lastPaid == null || accounts == null) {
      return const SizedBox.shrink();
    }
    final until = today.addDays(30);
    final soon = [
      for (final i in items)
        if (i.occurrence.status == OccStatus.planned && i.occurrence.dueDate <= until) i,
    ];
    if (soon.isEmpty) return const SizedBox.shrink();
    var total = 0;
    for (final i in soon) {
      if (i.rule.kind == RuleKind.creditLinePayment) continue;
      total += converter.toBase(expectedAmount(i.occurrence, lastPaid: lastPaid[i.rule.id]), i.occurrence.currency) ?? 0;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s4, AppSpacing.s16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: l.homeUpcoming,
            action: l.homeUpcomingTotal(context.money(total, converter.base, whole: true)),
            onAction: () => context.go(Routes.payments),
          ),
          RowsCard(
            children: [
              for (final i in soon.take(homeUpcomingRows))
                DueRow(
                  item: i,
                  total: i.rule.kind == RuleKind.loanPayment ? accounts[i.rule.counterAccountId]?.termMonths : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
