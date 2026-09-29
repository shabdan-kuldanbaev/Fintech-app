import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/format.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/dialogs.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/header.dart';
import '../../../core/calendar.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction.dart';
import 'pickers.dart';
import 'txn_list.dart';

/// «All transactions» (§8.3): поиск по заметке и категории, фильтры
/// чипами (счёт, категория, вид, месяц), лента по дням, итог периода.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key, this.accountId, this.categoryId});

  final String? accountId;
  final String? categoryId;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late String? _accountId = widget.accountId;
  late String? _categoryId = widget.categoryId;
  TxKind? _kind;
  MonthPeriod? _month;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cats = ref.watch(categoryMapProvider).value;
    final accounts = ref.watch(accountMapProvider).value;
    final settings = ref.watch(settingsProvider).value;
    final today = ref.watch(todayProvider);
    final filter = TxnFilter(
      accountId: _accountId,
      categoryId: _categoryId,
      kind: _kind,
      from: _month?.start,
      until: _month?.end,
      limit: _month == null ? 1000 : null,
    );
    final txns = ref.watch(txnsProvider(filter)).value;

    return GlassScaffold(
      header: ScreenHeader(leading: HeaderBack(tooltip: l.back), title: l.txAllTitle),
      body: (context) {
        if (cats == null || accounts == null || settings == null || txns == null) {
          return const SizedBox.shrink();
        }
        final q = _query.trim().toLowerCase();
        final shown = q.isEmpty
            ? txns
            : txns.where((t) {
                final note = (t.note ?? '').toLowerCase();
                final cat = cats[t.categoryId];
                final name = cat == null ? '' : categoryName(l, cat).toLowerCase();
                return note.contains(q) || name.contains(q);
              }).toList();
        var spent = 0;
        var income = 0;
        for (final t in shown) {
          if (cats[t.categoryId]?.isSystem ?? false) continue;
          if (t.kind == TxKind.expense) spent += t.baseAmount;
          if (t.kind == TxKind.income) income += t.baseAmount;
        }
        final account = accounts[_accountId];
        final category = cats[_categoryId];
        return ListView(
          padding: AppSpacing.scroll(context).copyWith(left: 0, right: 0),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: l.txSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            EdgeToEdgeRow(
              height: 34,
              children: [
                AppChip(
                  dense: true,
                  selected: account != null,
                  label: account?.name ?? l.filterAccount,
                  trailingIcon: Icons.expand_more_rounded,
                  onTap: () async {
                    final id = await showPickSheet<String?>(
                      context,
                      title: l.filterAccount,
                      selected: _accountId,
                      items: [
                        PickItem(value: null, label: l.filterAny),
                        for (final a in accounts.values) PickItem(value: a.id, label: a.name, iconKey: a.iconKey, colorKey: a.colorKey),
                      ],
                    );
                    if (context.mounted) setState(() => _accountId = id);
                  },
                ),
                AppChip(
                  dense: true,
                  selected: category != null,
                  label: category == null ? l.filterCategory : categoryName(l, category),
                  trailingIcon: Icons.expand_more_rounded,
                  onTap: () async {
                    if (_categoryId != null) {
                      setState(() => _categoryId = null);
                      return;
                    }
                    final picked = await pickCategory(
                      context,
                      cats.values.where((c) => !c.isSystem).toList(),
                      title: l.filterCategory,
                    );
                    if (picked != null) setState(() => _categoryId = picked.id);
                  },
                ),
                AppChip(
                  dense: true,
                  selected: _kind != null,
                  label: switch (_kind) {
                    TxKind.expense => l.kindExpense,
                    TxKind.income => l.kindIncome,
                    TxKind.transfer => l.kindTransfer,
                    null => l.filterKind,
                  },
                  trailingIcon: Icons.expand_more_rounded,
                  onTap: () async {
                    final k = await showPickSheet<TxKind?>(
                      context,
                      title: l.filterKind,
                      selected: _kind,
                      items: [
                        PickItem(value: null, label: l.filterAny),
                        PickItem(value: TxKind.expense, label: l.kindExpense),
                        PickItem(value: TxKind.income, label: l.kindIncome),
                        PickItem(value: TxKind.transfer, label: l.kindTransfer),
                      ],
                    );
                    if (context.mounted) setState(() => _kind = k);
                  },
                ),
                AppChip(
                  dense: true,
                  selected: _month != null,
                  label: _month == null ? l.filterMonth : context.monthYear(_month!.start),
                  trailingIcon: Icons.expand_more_rounded,
                  onTap: () async {
                    final current = MonthPeriod.containing(today, settings.monthStartDay);
                    final m = await showPickSheet<int?>(
                      context,
                      title: l.filterMonth,
                      items: [
                        PickItem(value: null, label: l.filterAny),
                        for (var i = 0; i < 12; i++)
                          PickItem(value: i, label: context.monthYear(current.shift(-i).start)),
                      ],
                    );
                    if (context.mounted) setState(() => _month = m == null ? null : current.shift(-m));
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s24),
                child: Center(child: Text(l.txEmpty, style: Theme.of(context).textTheme.bodyLarge)),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
                child: Wrap(
                  spacing: AppSpacing.s20,
                  children: [
                    Text('${l.statsSpent}  ${context.money(spent, settings.baseCurrency, whole: true)}', style: Theme.of(context).textTheme.bodyMedium),
                    if (income > 0)
                      Text('${l.statsIncome}  ${context.money(income, settings.baseCurrency, whole: true)}', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                child: TxnDayList(
                  txns: shown,
                  categories: cats,
                  accounts: accounts,
                  today: today,
                  baseCurrency: settings.baseCurrency,
                  scope: _accountId,
                  excludeFromDayTotal: {
                    for (final c in cats.values)
                      if (c.isSystem) c.id,
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

