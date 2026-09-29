import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/format.dart';
import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/header.dart';
import '../../../core/calendar.dart';
import '../../accounts/domain/balances.dart';
import '../../transactions/data/transaction_repository.dart';
import '../domain/stats.dart';

/// «Statistics» (§8.3): месяц ← →, плитки Spent / Income / Saved / Debt,
/// категории полосами (тап — операции категории), 6 месяцев столбиками,
/// долг за 12 месяцев линией. Диаграммы — `CustomPaint`, цвета из темы.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  /// 0 — текущий месяц, −1 — прошлый.
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GlassScaffold(
      header: ScreenHeader(leading: HeaderBack(tooltip: l.back), title: l.statsTitle),
      body: (context) => _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider).value;
    final today = ref.watch(todayProvider);
    if (settings == null) return const SizedBox.shrink();
    final current = MonthPeriod.containing(today, settings.monthStartDay);
    final first = current.shift(-11);
    final txns = ref.watch(txnsProvider(TxnFilter(from: first.start))).value;
    final accounts = ref.watch(accountsProvider).value;
    final balances = ref.watch(balancesProvider).value;
    final cats = ref.watch(categoryMapProvider).value;
    final converter = ref.watch(converterProvider).value;
    if (txns == null || accounts == null || balances == null || cats == null || converter == null) {
      return const SizedBox.shrink();
    }
    final accountMap = {for (final a in accounts) a.id: a};
    final excluded = {
      for (final c in cats.values)
        if (c.isSystem) c.id,
    };
    PeriodStats of(MonthPeriod p) => periodStats(txns, period: p, accounts: accountMap, excluded: excluded);
    final period = current.shift(_offset);
    final s = of(period);
    final base = converter.base;
    final debt = computeTotals(accounts, balances, converter).debt;
    final six = [for (var i = 5; i >= 0; i--) period.shift(-i)];
    final sixStats = [for (final p in six) of(p)];
    final twelve = [for (var i = 11; i >= 0; i--) current.shift(-i)];
    final debtLine = debtSeries(
      dates: [for (final p in twelve) p.end > today ? today.addDays(1) : p.end],
      accounts: accounts,
      balances: balances,
      txns: txns,
      converter: converter,
    );
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors.of(context);
    String whole(int v) => context.money(v, base, whole: true);

    return ListView(
      padding: AppSpacing.scroll(context, top: AppSpacing.s8).copyWith(left: AppSpacing.s16, right: AppSpacing.s16),
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('stats-prev'),
              tooltip: l.statsPrevMonth,
              onPressed: _offset <= -11 ? null : () => setState(() => _offset--),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                context.monthYear(period.start),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium,
              ),
            ),
            IconButton(
              key: const ValueKey('stats-next'),
              tooltip: l.statsNextMonth,
              onPressed: _offset >= 0 ? null : () => setState(() => _offset++),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _Tile(label: l.statsSpent, value: whole(s.spent))),
              const SizedBox(width: AppSpacing.s12),
              Expanded(child: _Tile(label: l.statsIncome, value: whole(s.income))),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _Tile(label: l.statsSaved, value: whole(s.saved))),
              const SizedBox(width: AppSpacing.s12),
              Expanded(child: _Tile(label: l.statsDebt, value: whole(debt))),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s20),
        SectionHeader(
          title: l.statsByCategory,
          action: l.statsBudgets,
          onAction: () => unawaited(context.push(Routes.budgets)),
        ),
        if (s.byCategory.isEmpty)
          SoftCard(
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: Text(l.statsEmpty, textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          )
        else
          RowsCard(
            children: [
              for (final e in s.byCategory)
                _CategoryBar(
                  key: ValueKey('stats-cat-${e.key}'),
                  name: e.key == loanPaymentsKey ? l.statsLoanPayments : (cats[e.key] == null ? '' : categoryName(l, cats[e.key]!)),
                  iconKey: e.key == loanPaymentsKey ? 'loan' : (cats[e.key]?.iconKey ?? 'other'),
                  colorKey: e.key == loanPaymentsKey ? 'sky' : (cats[e.key]?.colorKey ?? 'lavender'),
                  amount: whole(e.value),
                  share: s.spent == 0 ? 0 : e.value / s.spent,
                  onTap: e.key == loanPaymentsKey || cats[e.key] == null
                      ? null
                      : () => unawaited(context.push(Routes.transactionsFor(category: e.key))),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.s20),
        SectionHeader(title: l.statsSixMonths),
        SoftCard(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, AppSpacing.s12),
          child: Column(
            children: [
              Row(
                children: [
                  _Legend(color: colors.onBlush, label: l.statsSpent),
                  const SizedBox(width: AppSpacing.s16),
                  _Legend(color: colors.onMint, label: l.statsIncome),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              SizedBox(
                height: 120,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _BarsPainter(
                    spent: [for (final p in sixStats) p.spent],
                    income: [for (final p in sixStats) p.income],
                    spentColor: colors.onBlush,
                    incomeColor: colors.onMint,
                    grid: scheme.outlineVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              Row(
                children: [
                  for (final p in six)
                    Expanded(
                      child: Text(
                        DateFormat.MMM(context.lang).format(p.start.toLocalDateTime()),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: text.bodySmall?.copyWith(
                          color: p == period ? scheme.onSurface : scheme.onSurfaceVariant,
                          fontWeight: p == period ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (debtLine.any((v) => v > 0)) ...[
          const SizedBox(height: AppSpacing.s20),
          SectionHeader(title: l.statsDebtTrend, action: whole(debtLine.last)),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, AppSpacing.s12),
            child: Column(
              children: [
                SizedBox(
                  height: 96,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _LinePainter(values: debtLine, color: colors.onSky, grid: scheme.outlineVariant),
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                Row(
                  children: [
                    Text(context.monthYear(twelve.first.start), style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    const Spacer(),
                    Text(context.monthYear(twelve.last.start), style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s14, AppSpacing.s16, AppSpacing.s14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.s4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AmountText(value, style: text.tileAmount),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    super.key,
    required this.name,
    required this.iconKey,
    required this.colorKey,
    required this.amount,
    required this.share,
    this.onTap,
  });

  final String name;
  final String iconKey;
  final String colorKey;
  final String amount;
  final double share;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s10),
        child: Row(
          children: [
            IconBubble(iconKey: iconKey, colorKey: colorKey, size: 36),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.rowTitle)),
                      const SizedBox(width: AppSpacing.s8),
                      AmountText(amount, style: text.rowAmount),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  Row(
                    children: [
                      Expanded(child: ProgressBar(value: share, color: colors.onPastel(colorKey), height: 6)),
                      const SizedBox(width: AppSpacing.s8),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${(share * 100).round()}%',
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: AppSpacing.s6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

/// Столбики «потрачено / доход» по месяцам, общая шкала.
class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.spent,
    required this.income,
    required this.spentColor,
    required this.incomeColor,
    required this.grid,
  });

  final List<int> spent;
  final List<int> income;
  final Color spentColor;
  final Color incomeColor;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final max = [...spent, ...income, 1].reduce(math.max).toDouble();
    final line = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), line);
    final slot = size.width / spent.length;
    final bar = math.min(14.0, slot / 4);
    for (var i = 0; i < spent.length; i++) {
      final cx = slot * i + slot / 2;
      void draw(int v, double x, Color c) {
        final h = v <= 0 ? 0.0 : math.max(2.0, size.height * v / max);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, size.height - h, bar, h),
            topLeft: Radius.circular(bar / 2),
            topRight: Radius.circular(bar / 2),
          ),
          Paint()..color = c,
        );
      }

      draw(spent[i], cx - bar - 1.5, spentColor);
      draw(income[i], cx + 1.5, incomeColor);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      !_same(old.spent, spent) || !_same(old.income, income) || old.spentColor != spentColor;
}

/// Линия остатка долга по месяцам.
class _LinePainter extends CustomPainter {
  _LinePainter({required this.values, required this.color, required this.grid});

  final List<int> values;
  final Color color;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final max = [...values, 1].reduce(math.max).toDouble();
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );
    if (values.length < 2) return;
    final dx = size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p = Offset(dx * i, size.height - (size.height - 4) * values[i] / max);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final last = Offset(size.width, size.height - (size.height - 4) * values.last / max);
    canvas.drawCircle(last, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LinePainter old) => !_same(old.values, values) || old.color != color;
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
