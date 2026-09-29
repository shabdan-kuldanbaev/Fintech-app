import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/format.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/dialogs.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/header.dart';
import '../../../core/calendar.dart';
import '../../../core/currencies.dart';
import '../../../core/money.dart';
import '../../accounts/domain/account.dart';
import '../../categories/domain/category.dart';
import '../domain/transaction.dart';
import 'amount_field.dart';
import 'pickers.dart';
import 'quick_add.dart';

/// «Add» (spec.md §8.3, макет «Add expense»): сумма, строка «счёт · дата ·
/// заметка», сетка категорий, чипы частых операций, системная клавиатура.
/// **Тап по категории сохраняет** — кнопки «Save» нет (кроме перевода между
/// валютами).
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({
    super.key,
    this.kind = TxKind.expense,
    this.accountId,
    this.toAccountId,
  });

  final TxKind kind;
  final String? accountId;

  /// Перевод на этот счёт (досрочное погашение кредита).
  final String? toAccountId;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late TxKind _kind = widget.kind;
  final _amount = TextEditingController();
  final _counter = TextEditingController();
  final _amountFocus = FocusNode();
  String? _accountId;

  /// Счёт выбран руками на этом экране — категория его не подменяет.
  bool _accountTouched = false;
  String? _toId;
  LocalDate? _date;
  String? _note;
  bool _busy = false;
  bool _amountError = false;

  @override
  void initState() {
    super.initState();
    _accountId = widget.accountId;
    _accountTouched = widget.accountId != null;
    _toId = widget.toAccountId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _counter.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  List<Account> _usable(List<Account> all) =>
      all.where((a) => !a.isArchived).toList();

  Account? _from(List<Account> accounts, String? lastAccountId) {
    final usable = _usable(accounts);
    if (usable.isEmpty) return null;
    Account? find(String? id) =>
        id == null ? null : usable.where((a) => a.id == id).firstOrNull;
    return find(_accountId) ??
        find(lastAccountId) ??
        usable.firstWhere((a) => a.kind.isAsset, orElse: () => usable.first);
  }

  int? _parsed(String currency) {
    final v = parseAmount(_amount.text, currency);
    return v == null || v == 0 ? null : v;
  }

  void _missingAmount() {
    setState(() => _amountError = true);
    HapticFeedback.mediumImpact();
    _amountFocus.requestFocus();
  }

  Future<void> _saveCategory(
    Category cat,
    List<Account> accounts,
    Account shown,
  ) async {
    if (_busy) return;
    var account = shown;
    if (!_accountTouched && cat.lastAccountId != null) {
      final remembered = _usable(accounts)
          .where((a) => a.id == cat.lastAccountId)
          .firstOrNull;
      if (remembered != null) account = remembered;
    }
    final amount = _parsed(account.currency);
    if (amount == null) return _missingAmount();
    setState(() => _busy = true);
    final today = ref.read(todayProvider);
    final input = TxnInput(
      kind: _kind,
      accountId: account.id,
      amount: amount,
      date: _date ?? today,
      categoryId: cat.id,
      note: _note,
    );
    var label = quickLabel(
      context,
      kind: _kind,
      amount: amount,
      currency: account.currency,
      note: _note,
      category: cat,
      withCurrency: true,
    );
    if (account.id != shown.id) label = '$label · ${account.name}';
    final ok = await saveWithToast(
      context,
      ref,
      input,
      label: label,
      closeScreen: true,
    );
    if (!ok && mounted) setState(() => _busy = false);
  }

  Future<void> _saveTransfer(Account from, Account to) async {
    if (_busy) return;
    final amount = _parsed(from.currency);
    if (amount == null) return _missingAmount();
    int? counter;
    if (from.currency != to.currency) {
      if (_toId != to.id) {
        // Разные валюты: сначала сумма зачисления с подсказкой по курсу.
        final conv = ref.read(converterProvider).value;
        final hint = conv?.convert(amount, from.currency, to.currency);
        setState(() {
          _toId = to.id;
          _counter.text = hint == null
              ? ''
              : amountToInput(hint, to.currency, context.lang);
        });
        return;
      }
      counter = parseAmount(_counter.text, to.currency);
      if (counter == null || counter == 0) return;
    }
    setState(() => _busy = true);
    final input = TxnInput(
      kind: TxKind.transfer,
      accountId: from.id,
      counterAccountId: to.id,
      amount: amount,
      counterAmount: counter,
      date: _date ?? ref.read(todayProvider),
      note: _note,
    );
    final ok = await saveWithToast(
      context,
      ref,
      input,
      label: quickLabel(
        context,
        kind: TxKind.transfer,
        amount: amount,
        currency: from.currency,
        note: _note,
        from: from,
        to: to,
        withCurrency: true,
      ),
      closeScreen: true,
    );
    if (!ok && mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final accounts = ref.watch(accountsProvider).value;
    final categories = ref.watch(categoriesProvider).value;
    final settings = ref.watch(settingsProvider).value;
    final usage = ref.watch(categoryUsageProvider);
    final loading = accounts == null || categories == null || settings == null;
    final from = loading ? null : _from(accounts, settings.lastAccountId);
    final small = MediaQuery.sizeOf(context).height < 700;

    return GlassScaffold(
      header: ScreenHeader(
        leading: HeaderBack(tooltip: l.close, close: true),
        title: l.addTitle,
      ),
      body: (context) {
        if (loading || from == null) return const SizedBox.shrink();
        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + AppSizes.header,
            bottom: AppSpacing.s24,
          ),
          children: [
            Center(
              child: AppSegmented<TxKind>(
                values: TxKind.values,
                labels: [l.kindExpense, l.kindIncome, l.kindTransfer],
                selected: _kind,
                onChanged: (k) => setState(() {
                  _kind = k;
                  _toId = null;
                }),
              ),
            ),
            SizedBox(height: small ? AppSpacing.s2 : AppSpacing.s4),
            AmountField(
              controller: _amount,
              focusNode: _amountFocus,
              currency: from.currency,
              large: !small,
              error: _amountError ? l.addEnterAmount : null,
              onChanged: () {
                if (_amountError) setState(() => _amountError = false);
              },
            ),
            SizedBox(height: small ? AppSpacing.s4 : AppSpacing.s8),
            _metaChips(context, accounts, from),
            if (_kind == TxKind.transfer)
              ..._transfer(context, accounts, from)
            else ...[
              GroupLabel(l.addCategoryHint),
              _CategoryGrid(
                categories: sortByUsage(
                  categories
                      .where((c) => !c.isSystem && c.kind.db == _kind.db)
                      .toList(),
                  usage,
                ),
                onPick: (c) => _saveCategory(c, accounts, from),
                moreLabel: l.more,
                onMore: (all) async {
                  final picked = await pickCategory(
                    context,
                    all,
                    title: l.pickCategory,
                  );
                  if (picked != null) {
                    await _saveCategory(picked, accounts, from);
                  }
                },
              ),
            ],
            QuickAddRow(kinds: {_kind}, label: l.addQuick, closesScreen: true),
          ],
        );
      },
    );
  }

  Widget _metaChips(
    BuildContext context,
    List<Account> accounts,
    Account from,
  ) {
    final l = context.l10n;
    final today = ref.watch(todayProvider);
    final date = _date ?? today;
    // Одна строка: не влезает — прокручивается, а не переносится (§8.0).
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.s8,
          children: [
            AppChip(
              dense: true,
              icon: Icons.account_balance_wallet_outlined,
              label: from.name,
              trailingIcon: Icons.expand_more_rounded,
              onTap: () async {
                final id = await pickAccount(
                  context,
                  _usable(accounts),
                  title: _kind == TxKind.transfer ? l.addFrom : l.pickAccount,
                  selected: from.id,
                );
                if (id != null) {
                  setState(() {
                    _accountId = id;
                    _accountTouched = true;
                    _toId = null;
                  });
                }
              },
            ),
            AppChip(
              dense: true,
              label: context.relativeDay(date, today),
              trailingIcon: Icons.expand_more_rounded,
              onTap: () async {
                final picked = await pickDate(context, date);
                if (picked != null) setState(() => _date = picked);
              },
            ),
            AppChip(
              dense: true,
              muted: _note == null,
              label: _note ?? l.addNote,
              onTap: () async {
                final note = await showInputSheet(
                  context,
                  title: l.addNote,
                  action: l.done,
                  initial: _note ?? '',
                  hint: l.addNoteHint,
                );
                if (note != null) {
                  setState(
                    () => _note = note.trim().isEmpty ? null : note.trim(),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _transfer(
    BuildContext context,
    List<Account> accounts,
    Account from,
  ) {
    final l = context.l10n;
    final targets = _usable(accounts).where((a) => a.id != from.id).toList();
    if (targets.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Text(
            l.addNoOtherAccount,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ];
    }
    final to = targets.where((a) => a.id == _toId).firstOrNull;
    return [
      GroupLabel(l.addToHint),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
        child: Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            for (final a in targets)
              AppChip(
                label: a.name,
                iconKey: a.iconKey,
                colorKey: a.colorKey,
                selected: a.id == _toId,
                onTap: () => _saveTransfer(from, a),
              ),
          ],
        ),
      ),
      if (to != null && to.currency != from.currency) ...[
        const SizedBox(height: AppSpacing.s16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _counter,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l.addCounterAmount(to.currency),
                  suffixText: currencyInfo(to.currency).sign(context.lang),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              FilledButton(
                onPressed: () => _saveTransfer(from, to),
                child: Text(l.save),
              ),
            ],
          ),
        ),
      ],
    ];
  }
}

/// Сетка 4 × 2: семь частых категорий и «More» с остальными.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.onPick,
    required this.onMore,
    required this.moreLabel,
  });

  final List<Category> categories;
  final ValueChanged<Category> onPick;
  final ValueChanged<List<Category>> onMore;
  final String moreLabel;

  @override
  Widget build(BuildContext context) {
    // Маленький экран (iPhone SE): ячейки ниже, чтобы первый ряд категорий
    // был виден над клавиатурой.
    final compact = MediaQuery.sizeOf(context).height < 700;
    final shown = categories.length <= 8
        ? categories
        : categories.take(7).toList();
    final hasMore = categories.length > 8;
    final l = context.l10n;
    Widget cell({
      required Widget icon,
      required String label,
      required VoidCallback onTap,
      Key? key,
    }) => InkWell(
      key: key,
      borderRadius: BorderRadius.circular(AppRadius.row),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.s4,
          horizontal: AppSpacing.s2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: AppSpacing.s6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.gridLabel,
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
      child: GridView(
        // Высота ячейки фиксирована: при пропорции от ширины на 320 pt
        // подпись не влезала (кадр add-expense-*-320, 2026-09-29).
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisExtent: compact ? 76 : 84,
        ),
        // Без padding вложенная сетка берёт отступы безопасной зоны из
        // MediaQuery и отодвигается от подписи на высоту статус-бара.
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final c in shown)
            cell(
              key: ValueKey('cat-${c.key ?? c.id}'),
              icon: IconBubble(
                iconKey: c.iconKey,
                colorKey: c.colorKey,
                size: compact ? 44 : 52,
              ),
              label: categoryName(l, c),
              onTap: () => onPick(c),
            ),
          if (hasMore)
            cell(
              key: const ValueKey('cat-more'),
              icon: IconBubble(
                iconKey: 'other',
                colorKey: 'lavender',
                size: compact ? 44 : 52,
              ),
              label: moreLabel,
              onTap: () => onMore(categories),
            ),
        ],
      ),
    );
  }
}

/// Порядок категорий: по частоте за 60 дней, затем по `sort_order` (§8.3).
List<Category> sortByUsage(List<Category> list, Map<String, int> usage) {
  final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
  indexed.sort((a, b) {
    final byUse = (usage[b.$2.id] ?? 0).compareTo(usage[a.$2.id] ?? 0);
    return byUse != 0 ? byUse : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// Сколько раз категория встречалась за 60 дней.
final categoryUsageProvider = Provider<Map<String, int>>((ref) {
  final txns = ref.watch(recentTxnsProvider).value;
  if (txns == null) return const {};
  final counts = <String, int>{};
  for (final t in txns) {
    final id = t.categoryId;
    if (id != null) counts[id] = (counts[id] ?? 0) + 1;
  }
  return counts;
});
