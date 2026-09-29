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
import '../../accounts/domain/account.dart';
import '../../currencies/domain/converter.dart';
import '../domain/planning.dart';
import '../domain/rule.dart';
import '../domain/schedule.dart';
import 'due_row.dart';

enum _View { upcoming, rules }

/// Вкладка «Payments» (§8.3, макет «Payments»): ближайшие наступления по
/// группам с «Pay» в строке и свайпом «Skip»; правила по видам.
class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  _View _view = _View.upcoming;

  /// Пропущенные свайпом: убираются из списка сразу, не дожидаясь базы
  /// (иначе Dismissible ругается, что убранная строка ещё в дереве).
  final Set<String> _skipped = {};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GlassScaffold(
      header: ScreenHeader(
        titleWidget: AppSegmented<_View>(
          values: _View.values,
          labels: [l.paymentsUpcoming, l.paymentsRules],
          selected: _view,
          onChanged: (v) => setState(() => _view = v),
        ),
        trailing: GlassIconButton(
          icon: Icons.add_rounded,
          tooltip: l.paymentsNewTooltip,
          onPressed: () => unawaited(context.push(Routes.newRule(RuleKind.subscription))),
        ),
      ),
      body: (context) => _view == _View.upcoming ? _upcoming(context) : _rules(context),
    );
  }

  Widget _empty(BuildContext context) {
    final l = context.l10n;
    return ListView(
      padding: AppSpacing.scroll(context).copyWith(left: AppSpacing.s16, right: AppSpacing.s16),
      children: [
        EmptyCard(
          iconKey: 'subscriptions',
          title: l.paymentsEmptyTitle,
          body: l.paymentsEmptyBody,
          action: l.ruleNew,
          onAction: () => unawaited(context.push(Routes.newRule(RuleKind.subscription))),
        ),
      ],
    );
  }

  Widget _upcoming(BuildContext context) {
    final l = context.l10n;
    final items = ref.watch(upcomingProvider).value;
    final rules = ref.watch(rulesProvider).value;
    final converter = ref.watch(converterProvider).value;
    final lastPaid = ref.watch(lastPaidProvider).value;
    final accounts = ref.watch(accountMapProvider).value;
    final today = ref.watch(todayProvider);
    if (items == null || rules == null || converter == null || lastPaid == null || accounts == null) {
      return const SizedBox.shrink();
    }
    if (rules.isEmpty) return _empty(context);
    final shown = items.where((i) => !_skipped.contains(i.occurrence.id)).toList();

    var total30 = 0;
    for (final i in shown) {
      if (i.occurrence.dueDate > today.addDays(30)) continue;
      if (i.rule.kind == RuleKind.creditLinePayment) continue;
      final amount = expectedAmount(i.occurrence, lastPaid: lastPaid[i.rule.id]);
      total30 += converter.toBase(amount, i.occurrence.currency) ?? 0;
    }

    final groups = <(String, Color?), List<DueItem>>{};
    void put(String label, DueItem i, {Color? color}) => (groups[(label, color)] ??= []).add(i);
    final blush = AppColors.of(context).onBlush;
    for (final i in shown) {
      final d = today.daysUntil(i.occurrence.dueDate);
      if (d < 0) {
        put(l.groupOverdue, i, color: blush);
      } else if (d == 0) {
        put(l.groupToday, i);
      } else if (d == 1) {
        put(l.groupTomorrow(context.day(i.occurrence.dueDate)), i);
      } else if (d <= 7) {
        put(l.groupThisWeek, i);
      } else {
        put(l.groupLater, i);
      }
    }

    return ListView(
      padding: AppSpacing.scroll(context).copyWith(left: AppSpacing.s16, right: AppSpacing.s16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s4, AppSpacing.s4, AppSpacing.s4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(l.paymentsNext30, maxLines: 1, style: Theme.of(context).textTheme.headlineSmall),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              AmountText(context.money(total30, converter.base, whole: true), style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
        for (final entry in groups.entries) ...[
          GroupLabel(entry.key.$1, color: entry.key.$2),
          RowsCard(
            children: [
              for (final i in entry.value)
                Dismissible(
                  key: ValueKey('dismiss-${i.occurrence.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppSpacing.s20),
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: Text(l.skip, style: Theme.of(context).textTheme.labelLarge),
                  ),
                  onDismissed: (_) {
                    setState(() => _skipped.add(i.occurrence.id));
                    unawaited(skipFromRow(context, ref, i));
                  },
                  child: DueRow(item: i, total: _total(i, accounts), showWhen: today.daysUntil(i.occurrence.dueDate) > 1),
                ),
            ],
          ),
        ],
      ],
    );
  }

  int? _total(DueItem i, Map<String, Account> accounts) =>
      i.rule.kind == RuleKind.loanPayment ? accounts[i.rule.counterAccountId]?.termMonths : null;

  Widget _rules(BuildContext context) {
    final l = context.l10n;
    final rules = ref.watch(rulesProvider).value;
    final converter = ref.watch(converterProvider).value;
    final lastPaid = ref.watch(lastPaidProvider).value;
    final today = ref.watch(todayProvider);
    if (rules == null || converter == null || lastPaid == null) return const SizedBox.shrink();
    if (rules.isEmpty) return _empty(context);

    final sections = <(String, List<RuleKind>)>[
      (l.rulesLoans, [RuleKind.loanPayment]),
      (l.rulesCreditLines, [RuleKind.creditLinePayment]),
      (l.rulesSubscriptions, [RuleKind.subscription]),
      (l.rulesUtilities, [RuleKind.utility]),
      (l.rulesOther, [RuleKind.other]),
    ];
    return ListView(
      padding: AppSpacing.scroll(context).copyWith(left: AppSpacing.s16, right: AppSpacing.s16),
      children: [
        for (final (title, kinds) in sections)
          if (rules.any((r) => kinds.contains(r.kind))) ...[
            _RuleSectionTitle(
              title: title,
              perMonth: _perMonth(rules.where((r) => kinds.contains(r.kind)), converter, lastPaid, today),
              base: converter.base,
            ),
            RowsCard(
              children: [
                for (final r in rules.where((r) => kinds.contains(r.kind)))
                  _RuleRow(rule: r, lastPaid: lastPaid[r.id], today: today),
              ],
            ),
          ],
      ],
    );
  }

  int _perMonth(Iterable<Rule> rules, Converter converter, Map<String, int> lastPaid, LocalDate today) {
    var sum = 0;
    for (final r in rules) {
      if (r.isPausedOn(today)) continue;
      final m = monthlyEquivalent(r, lastPaid: lastPaid[r.id]);
      if (m == null) continue;
      sum += converter.toBase(m, r.currency) ?? 0;
    }
    return sum;
  }
}

class _RuleSectionTitle extends StatelessWidget {
  const _RuleSectionTitle({required this.title, required this.perMonth, required this.base});

  final String title;
  final int perMonth;
  final String base;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s14, AppSpacing.s16, AppSpacing.s6),
    child: Row(
      children: [
        Expanded(child: GroupLabel(title, padding: EdgeInsets.zero)),
        if (perMonth > 0)
          Text(
            context.l10n.perMonth(context.money(perMonth, base, whole: true)).toUpperCase(),
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.groupLabel,
          ),
      ],
    ),
  );
}

/// Строка правила: имя, расписание или пауза, сумма за период.
class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule, required this.lastPaid, required this.today});

  final Rule rule;
  final int? lastPaid;
  final LocalDate today;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final paused = rule.isPausedOn(today);
    final scheme = Theme.of(context).colorScheme;
    final amount = rule.amount ?? lastPaid;
    final subtitle = paused
        ? (rule.pausedUntil == Rule.pausedForever ? l.paused : l.pausedUntil(context.day(rule.pausedUntil!)))
        : frequencyLabel(context, rule);
    final row = AppRow(
      key: ValueKey('rule-${rule.id}'),
      leading: IconBubble(iconKey: rule.iconKey, colorKey: rule.colorKey),
      title: rule.name,
      subtitle: subtitle,
      trailing: amount == null
          ? null
          : AmountText(
              context.money(amount, rule.currency, symbol: false, whole: amount % 100 == 0),
              color: paused ? scheme.onSurfaceVariant : null,
            ),
      onTap: () => unawaited(context.push(
        rule.kind.isTransfer && rule.counterAccountId != null
            ? Routes.account(rule.counterAccountId!)
            : Routes.rule(rule.id),
      )),
    );
    return paused ? Opacity(opacity: 0.6, child: row) : row;
  }
}

/// «Каждый месяц · 3-е число», «Каждую неделю», «Каждые 10 дн.».
String frequencyLabel(BuildContext context, Rule rule) {
  final l = context.l10n;
  final base = switch (rule.frequency) {
    Frequency.monthly => rule.interval == 1 ? l.freqMonthly : l.freqEveryNMonths(rule.interval),
    Frequency.weekly => l.freqWeekly,
    Frequency.yearly => l.freqYearly,
    Frequency.everyNDays => l.freqEveryNDays(rule.interval),
  };
  final day = rule.dayOfMonth ?? rule.startDate.day;
  return rule.frequency == Frequency.monthly ? '$base · ${l.dayOfMonth(day)}' : base;
}
