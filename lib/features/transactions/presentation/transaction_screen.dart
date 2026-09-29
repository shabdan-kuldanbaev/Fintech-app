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
import '../../../app/widgets/toast.dart';
import '../../../core/calendar.dart';
import '../../../core/money.dart';
import '../../accounts/domain/account.dart';
import '../domain/transaction.dart';
import 'amount_field.dart';
import 'pickers.dart';
import 'transaction_extras.dart';

/// «Transaction» (§8.3): все поля, правка, «Save». «Delete» — без диалога,
/// тост «Deleted · Undo». Оплата наступления — плашка и «Undo payment».
class TransactionScreen extends ConsumerStatefulWidget {
  const TransactionScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends ConsumerState<TransactionScreen> {
  final _amount = TextEditingController();
  final _counter = TextEditingController();
  final _focus = FocusNode();
  Txn? _loaded;
  String? _accountId;
  String? _toId;
  String? _categoryId;
  LocalDate? _date;
  String? _note;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _counter.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _load(Txn t, Map<String, Account> accounts) {
    if (_loaded?.id == t.id) return;
    _loaded = t;
    _accountId = t.accountId;
    _toId = t.counterAccountId;
    _categoryId = t.categoryId;
    _date = t.date;
    _note = t.note;
    final lang = context.lang;
    _amount.text = amountToInput(t.amount, t.currency, lang);
    final to = accounts[t.counterAccountId];
    if (t.counterAmount != null && to != null) {
      _counter.text = amountToInput(t.counterAmount!, to.currency, lang);
    }
  }

  Future<void> _save(Txn t, Map<String, Account> accounts) async {
    final account = accounts[_accountId];
    if (account == null) return;
    final amount = parseAmount(_amount.text, account.currency);
    if (amount == null || amount == 0) {
      _focus.requestFocus();
      return;
    }
    final to = accounts[_toId];
    int? counter;
    if (t.kind == TxKind.transfer && to != null && to.currency != account.currency) {
      counter = parseAmount(_counter.text, to.currency);
      if (counter == null || counter == 0) return;
    }
    setState(() => _busy = true);
    final l = context.l10n;
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    try {
      await ref.read(transactionRepositoryProvider).update(
        t.id,
        TxnInput(
          kind: t.kind,
          accountId: account.id,
          amount: amount,
          date: _date ?? t.date,
          counterAccountId: t.kind == TxKind.transfer ? _toId : null,
          counterAmount: counter,
          categoryId: t.kind == TxKind.transfer ? null : _categoryId,
          note: _note,
        ),
      );
      if (!mounted) return;
      context.closeScreen();
      if (overlay != null) showActionToastOn(overlay, l.changesSaved);
    } on MissingRate catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showActionToast(context, l.addMissingRate(e.currency), icon: Icons.info_outline_rounded);
    } on TxnValidationError {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Txn t) async {
    final l = context.l10n;
    final repo = ref.read(transactionRepositoryProvider);
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    await repo.delete(t.id);
    if (!mounted) return;
    context.closeScreen();
    if (overlay == null) return;
    showActionToastOn(
      overlay,
      l.deletedToast,
      icon: Icons.delete_outline_rounded,
      actions: [ToastAction(l.undo, () => unawaited(repo.restore(t.id)), primary: true)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final txn = ref.watch(txnProvider(widget.id));
    final accounts = ref.watch(accountMapProvider).value;
    final cats = ref.watch(categoryMapProvider).value;
    final t = txn.value;
    if (t != null && accounts != null) _load(t, accounts);

    final title = switch (t?.kind) {
      TxKind.income => l.kindIncome,
      TxKind.transfer => l.kindTransfer,
      _ => l.kindExpense,
    };
    final linked = t?.occurrenceId != null;

    return GlassScaffold(
      header: ScreenHeader(
        leading: HeaderBack(tooltip: l.back),
        title: title,
        trailing: t == null || linked
            ? null
            : GlassIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: l.delete,
                onPressed: () => unawaited(_delete(t)),
              ),
      ),
      bar: t == null || accounts == null
          ? null
          : FilledButton(
              onPressed: _busy ? null : () => unawaited(_save(t, accounts)),
              child: Text(l.save),
            ),
      body: (context) {
        if (txn.isLoading || accounts == null || cats == null) return const SizedBox.shrink();
        if (t == null) {
          return Center(child: Text(l.notFoundTitle, style: Theme.of(context).textTheme.titleMedium));
        }
        final account = accounts[_accountId];
        final to = accounts[_toId];
        final cat = cats[_categoryId];
        final today = ref.watch(todayProvider);
        final usable = accounts.values.where((a) => !a.isArchived || a.id == _accountId || a.id == _toId).toList();
        return ListView(
          padding: AppSpacing.scroll(context, top: AppSpacing.s16),
          children: [
            AmountField(
              controller: _amount,
              focusNode: _focus,
              currency: account?.currency ?? t.currency,
              autofocus: false,
              large: false,
              onChanged: () {},
            ),
            const SizedBox(height: AppSpacing.s20),
            if (linked) ...[
              OccurrenceLinkCard(txn: t),
              const SizedBox(height: AppSpacing.s12),
            ],
            RowsCard(
              children: [
                if (t.kind != TxKind.transfer) ...[
                  ValueRow(
                    label: l.txCategory,
                    value: cat == null ? '' : categoryName(l, cat),
                    leading: cat == null ? null : IconBubble(iconKey: cat.iconKey, colorKey: cat.colorKey, size: 32),
                    onTap: linked
                        ? null
                        : () async {
                            final list = cats.values
                                .where((c) => !c.isSystem && c.kind.db == t.kind.db)
                                .toList();
                            final picked = await pickCategory(context, list, title: l.pickCategory, selected: _categoryId);
                            if (picked != null) setState(() => _categoryId = picked.id);
                          },
                  ),
                  const RowDivider(),
                ],
                ValueRow(
                  label: t.kind == TxKind.transfer ? l.txFrom : l.txAccount,
                  value: account?.name ?? '',
                  onTap: () async {
                    final id = await pickAccount(context, usable, title: l.pickAccount, selected: _accountId);
                    if (id != null) setState(() => _accountId = id);
                  },
                ),
                if (t.kind == TxKind.transfer) ...[
                  const RowDivider(),
                  ValueRow(
                    label: l.txTo,
                    value: to?.name ?? '',
                    onTap: linked
                        ? null
                        : () async {
                            final id = await pickAccount(
                              context,
                              usable.where((a) => a.id != _accountId).toList(),
                              title: l.txTo,
                              selected: _toId,
                            );
                            if (id != null) setState(() => _toId = id);
                          },
                  ),
                  if (to != null && account != null && to.currency != account.currency) ...[
                    const RowDivider(),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      child: TextField(
                        controller: _counter,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: l.addCounterAmount(to.currency)),
                      ),
                    ),
                  ],
                ],
                const RowDivider(),
                ValueRow(
                  label: l.txDate,
                  value: context.relativeDay(_date ?? t.date, today),
                  onTap: () async {
                    final d = await pickDate(context, _date ?? t.date);
                    if (d != null) setState(() => _date = d);
                  },
                ),
                const RowDivider(),
                ValueRow(
                  label: l.txNote,
                  value: _note ?? '',
                  onTap: () async {
                    final note = await showInputSheet(context, title: l.txNote, action: l.done, initial: _note ?? '', hint: l.addNoteHint);
                    if (note != null) setState(() => _note = note.trim().isEmpty ? null : note.trim());
                  },
                ),
              ],
            ),
            if (account != null) ...[
              const SizedBox(height: AppSpacing.s12),
              Center(
                child: TextButton(
                  onPressed: () => unawaited(context.push(Routes.account(account.id))),
                  child: Text(account.name),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
