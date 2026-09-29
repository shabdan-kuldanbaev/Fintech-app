import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/format.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/header.dart';
import '../../../core/calendar.dart';
import '../../../core/currencies.dart';
import '../../../core/money.dart';
import '../../categories/domain/category.dart';
import '../../stats/domain/stats.dart';
import '../../transactions/data/transaction_repository.dart';
import '../domain/budget.dart';

/// «Budgets» (§8.3, §9.4): общий бюджет месяца сверху, ниже категории с
/// бюджетом, затем «Categories without a budget» с «Set budget». Тап —
/// шторка суммы (с этого месяца или со следующего), «Remove budget».
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return GlassScaffold(
      header: ScreenHeader(leading: HeaderBack(tooltip: l.back), title: l.budgetsTitle),
      body: (context) => const _BudgetsBody(),
    );
  }
}

class _BudgetsBody extends ConsumerWidget {
  const _BudgetsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider).value;
    final today = ref.watch(todayProvider);
    final budgets = ref.watch(budgetsProvider).value;
    final cats = ref.watch(categoriesProvider).value;
    final accounts = ref.watch(accountMapProvider).value;
    if (settings == null || budgets == null || cats == null || accounts == null) return const SizedBox.shrink();
    final period = MonthPeriod.containing(today, settings.monthStartDay);
    final txns = ref.watch(txnsProvider(TxnFilter(from: period.start, until: period.end))).value;
    if (txns == null) return const SizedBox.shrink();
    final excluded = {
      for (final c in cats)
        if (c.isSystem) c.id,
    };
    final stats = periodStats(txns, period: period, accounts: accounts, excluded: excluded);
    final spentBy = {for (final e in stats.byCategory) e.key: e.value};
    final month = period.monthKey;
    final base = settings.baseCurrency;
    final expenseCats = cats.where((c) => c.kind == CategoryKind.expense && !c.isSystem).toList();
    final withBudget = [
      for (final c in expenseCats)
        if (effectiveBudget(budgets, c.id, month) != null) c,
    ];
    final without = [
      for (final c in expenseCats)
        if (effectiveBudget(budgets, c.id, month) == null) c,
    ];
    final total = effectiveBudget(budgets, null, month);

    Future<void> edit(String? categoryId, String title) =>
        _editBudget(context, ref, categoryId: categoryId, title: title, current: effectiveBudget(budgets, categoryId, month), period: period, base: base);

    return ListView(
      padding: AppSpacing.scroll(context, top: AppSpacing.s8).copyWith(left: AppSpacing.s16, right: AppSpacing.s16),
      children: [
        Center(
          child: Text(
            context.monthYear(period.start),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        RowsCard(
          children: [
            _BudgetRow(
              key: const ValueKey('budget-total'),
              iconKey: 'wallet',
              colorKey: 'lavender',
              title: l.budgetWholeMonth,
              spent: stats.spent,
              budget: total?.amount,
              base: base,
              onTap: () => unawaited(edit(null, l.budgetWholeMonth)),
            ),
          ],
        ),
        if (withBudget.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s12),
          RowsCard(
            children: [
              for (final c in withBudget)
                _BudgetRow(
                  key: ValueKey('budget-${c.key ?? c.id}'),
                  iconKey: c.iconKey,
                  colorKey: c.colorKey,
                  title: categoryName(l, c),
                  spent: spentBy[c.id] ?? 0,
                  budget: effectiveBudget(budgets, c.id, month)!.amount,
                  base: base,
                  onTap: () => unawaited(edit(c.id, categoryName(l, c))),
                ),
            ],
          ),
        ],
        if (without.isNotEmpty) ...[
          GroupLabel(l.budgetNoCategories),
          RowsCard(
            children: [
              for (final c in without)
                AppRow(
                  key: ValueKey('budget-${c.key ?? c.id}'),
                  leading: IconBubble(iconKey: c.iconKey, colorKey: c.colorKey, size: 36),
                  title: categoryName(l, c),
                  subtitle: (spentBy[c.id] ?? 0) == 0 ? null : context.money(spentBy[c.id]!, base, whole: true),
                  trailing: Icon(Icons.add_circle_outline_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  onTap: () => unawaited(edit(c.id, categoryName(l, c))),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

Future<void> _editBudget(
  BuildContext context,
  WidgetRef ref, {
  required String? categoryId,
  required String title,
  required Budget? current,
  required MonthPeriod period,
  required String base,
}) async {
  final result = await showModalBottomSheet<(int?, bool)>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _BudgetSheet(title: title, current: current?.amount, currency: base),
  );
  if (result == null) return;
  final (amount, nextMonth) = result;
  final month = (nextMonth ? period.shift(1) : period).monthKey;
  final repo = ref.read(budgetRepositoryProvider);
  if (amount == null) {
    await repo.remove(categoryId, month);
  } else {
    await repo.set(categoryId, amount, month);
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    super.key,
    required this.iconKey,
    required this.colorKey,
    required this.title,
    required this.spent,
    required this.budget,
    required this.base,
    required this.onTap,
  });

  final String iconKey;
  final String colorKey;
  final String title;
  final int spent;
  final int? budget;
  final String base;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final b = budget;
    final progress = b == null ? null : BudgetProgress(spent: spent, budget: b);
    final over = progress != null && progress.over > 0;
    String m(int v) => context.money(v, base, whole: true, symbol: false);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
        child: Row(
          children: [
            IconBubble(iconKey: iconKey, colorKey: over ? 'blush' : colorKey, size: 36),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.rowTitle),
                  if (progress != null) ...[
                    const SizedBox(height: AppSpacing.s6),
                    ProgressBar(value: progress.ratio, color: over ? colors.onBlush : colors.onMint, height: 6),
                    const SizedBox(height: AppSpacing.s4),
                    // Сумма не обрезается (§8.0): не влезает в строку — «осталось»
                    // уходит на следующую.
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: AppSpacing.s8,
                      children: [
                        Text(
                          l.budgetOf(m(spent), m(b!)),
                          maxLines: 1,
                          style: text.bodySmall?.copyWith(color: over ? colors.onBlush : null, fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                        Text(
                          over ? l.budgetOver(m(progress.over)) : l.budgetLeft(m(progress.left)),
                          maxLines: 1,
                          style: text.bodySmall?.copyWith(color: over ? colors.onBlush : scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      spent == 0 ? l.budgetSet : '${m(spent)} · ${l.budgetSet}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Шторка суммы бюджета: поле, «со следующего месяца», «Сохранить»,
/// «Убрать бюджет» (если он есть). Результат: (сумма или `null` — убрать,
/// со следующего месяца).
class _BudgetSheet extends StatefulWidget {
  const _BudgetSheet({required this.title, required this.current, required this.currency});

  final String title;
  final int? current;
  final String currency;

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  late final _controller = TextEditingController();
  bool _next = false;
  bool _error = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final c = widget.current;
    if (c != null) _controller.text = amountToInput(c, widget.currency, context.lang);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final v = parseAmount(_controller.text, widget.currency);
    if (v == null || v <= 0) {
      setState(() => _error = true);
      return;
    }
    Navigator.of(context).pop((v, _next));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s20,
        0,
        AppSpacing.s20,
        AppSpacing.s20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleLarge),
          const SizedBox(height: AppSpacing.s16),
          TextField(
            key: const ValueKey('budget-amount'),
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l.budgetAmount,
              suffixText: currencyInfo(widget.currency).sign(context.lang),
              errorText: _error ? l.amountRequired : null,
            ),
            onSubmitted: (_) => _save(),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.budgetFromNextMonth),
            value: _next,
            onChanged: (v) => setState(() => _next = v),
          ),
          const SizedBox(height: AppSpacing.s8),
          FilledButton(key: const ValueKey('budget-save'), onPressed: _save, child: Text(l.save)),
          if (widget.current != null) ...[
            const SizedBox(height: AppSpacing.s8),
            TextButton(
              onPressed: () => Navigator.of(context).pop((null, _next)),
              child: Text(l.budgetRemove),
            ),
          ],
        ],
      ),
    );
  }
}
