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
import '../../../app/widgets/toast.dart';
import '../../../core/calendar.dart';
import '../../../core/money.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/domain/balances.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/amount_field.dart';
import '../../transactions/presentation/pickers.dart';
import '../domain/rule.dart';
import 'due_row.dart';
import 'payments_screen.dart';

/// «Occurrence» (§8.3, макет «Utility bill»): сумма (поле в валюте счёта),
/// «Last time», счёт и дата чипами, «Skip» и «Pay N» в стеклянной панели.
class OccurrenceScreen extends ConsumerStatefulWidget {
  const OccurrenceScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<OccurrenceScreen> createState() => _OccurrenceScreenState();
}

class _OccurrenceScreenState extends ConsumerState<OccurrenceScreen> {
  final _amount = TextEditingController();
  final _focus = FocusNode();
  String? _accountId;
  LocalDate? _date;
  bool _prefilled = false;
  bool _busy = false;
  int? _lastPaid;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _prefill(DueItem item, Account account) {
    if (_prefilled) return;
    _prefilled = true;
    unawaited(ref.read(ruleRepositoryProvider).lastPaidAmount(item.rule.id).then((v) {
      if (mounted) setState(() => _lastPaid = v);
    }));
    final expected = item.occurrence.amountExpected;
    if (expected == null || expected == 0) return;
    final conv = ref.read(converterProvider).value;
    final inAccount = conv?.convert(expected, item.occurrence.currency, account.currency);
    if (inAccount != null) _amount.text = amountToInput(inAccount, account.currency, context.lang);
  }

  Future<void> _pay(DueItem item, Account account) async {
    final amount = parseAmount(_amount.text, account.currency);
    if (amount == null || amount == 0) {
      _focus.requestFocus();
      return;
    }
    setState(() => _busy = true);
    final l = context.l10n;
    final repo = ref.read(ruleRepositoryProvider);
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    try {
      await repo.pay(item.occurrence.id, amount: amount, accountId: account.id, date: _date);
      if (mounted) context.closeScreen();
      overlay?.let((o) => showActionToastOn(
        o,
        l.paidToast(item.rule.name),
        actions: [ToastAction(l.undo, () => unawaited(repo.unpay(item.occurrence.id)), primary: true)],
      ));
    } on MissingRate catch (e) {
      if (mounted) setState(() => _busy = false);
      overlay?.let((o) => showActionToastOn(o, l.addMissingRate(e.currency), icon: Icons.info_outline_rounded));
    }
  }

  Future<void> _skip(DueItem item) async {
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    final l = context.l10n;
    final repo = ref.read(ruleRepositoryProvider);
    await repo.skip(item.occurrence.id);
    if (mounted) context.closeScreen();
    overlay?.let((o) => showActionToastOn(
      o,
      l.skippedToast(item.rule.name),
      icon: Icons.redo_rounded,
      actions: [ToastAction(l.undo, () => unawaited(repo.unskip(item.occurrence.id)), primary: true)],
    ));
  }

  Account? _chooseAccount(DueItem item, List<Account> accounts, String? lastAccountId) {
    final usable = accounts.where((a) => !a.isArchived && a.id != item.rule.counterAccountId).toList();
    return usable.where((a) => a.id == (_accountId ?? item.rule.accountId ?? lastAccountId)).firstOrNull ??
        usable.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(dueItemProvider(widget.id));
    final item = async.value;
    final accounts = ref.watch(accountsProvider).value;
    final balances = ref.watch(balancesProvider).value;
    final settings = ref.watch(settingsProvider).value;
    final converter = ref.watch(converterProvider).value;
    final today = ref.watch(todayProvider);
    final ready = item != null && accounts != null && balances != null && settings != null && converter != null;

    final account = ready ? _chooseAccount(item, accounts, settings.lastAccountId) : null;
    if (ready && account != null) _prefill(item, account);
    final o = item?.occurrence;
    final planned = o?.status == OccStatus.planned;

    return GlassScaffold(
      header: ScreenHeader(
        leading: HeaderBack(tooltip: l.back),
        title: item?.rule.name,
        trailing: item == null
            ? null
            : GlassMenuButton<String>(
                tooltip: l.more,
                onSelected: (v) {
                  if (v == 'edit') {
                    unawaited(context.push(
                      item.rule.kind.isTransfer && item.rule.counterAccountId != null
                          ? Routes.account(item.rule.counterAccountId!)
                          : Routes.editRule(item.rule.id),
                    ));
                  } else if (v == 'skip') {
                    unawaited(_skip(item));
                  }
                },
                actions: [
                  if (planned) MenuAction(value: 'skip', label: l.skip, icon: Icons.redo_rounded),
                  MenuAction(value: 'edit', label: l.occEditRule, icon: Icons.edit_outlined),
                ],
              ),
      ),
      barHidesForKeyboard: false,
      bar: !ready || account == null
          ? null
          : planned
          ? Row(
              children: [
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(0, AppSizes.button)),
                  onPressed: _busy ? null : () => unawaited(_skip(item)),
                  child: Text(l.skip),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('occurrence-pay'),
                    onPressed: _busy ? null : () => unawaited(_pay(item, account)),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l.payAmount(pillAmount(context, parseAmount(_amount.text, account.currency) ?? 0, account.currency)),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : o?.status == OccStatus.paid
          ? OutlinedButton(
              onPressed: () => unawaited(ref.read(ruleRepositoryProvider).unpay(o!.id)),
              child: Text(l.txUndoPayment),
            )
          : OutlinedButton(
              onPressed: () => unawaited(ref.read(ruleRepositoryProvider).unskip(o!.id)),
              child: Text(l.occRestore),
            ),
      body: (context) {
        if (async.isLoading && item == null) return const SizedBox.shrink();
        if (item == null) {
          return Center(child: Text(l.notFoundTitle, style: Theme.of(context).textTheme.titleMedium));
        }
        if (!ready) return const SizedBox.shrink();
        if (account == null) {
          return Center(child: Text(l.addNoOtherAccount, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium));
        }
        final occ = item.occurrence;
        final rule = item.rule;
        final overdue = occ.isOverdue(today);
        final colors = AppColors.of(context);
        final text = Theme.of(context).textTheme;
        final days = today.daysUntil(occ.dueDate);
        final dueText = overdue
            ? '${l.occDue(context.day(occ.dueDate))} · ${l.overdueDays(-days)}'
            : days <= 1
            ? '${l.occDue(context.day(occ.dueDate))} · ${whenLabel(context, occ.dueDate, today)}'
            : '${l.occDue(context.day(occ.dueDate))} · ${l.inDays(days).toLowerCase()}';
        final creditAccount = accounts.where((a) => a.id == rule.counterAccountId).firstOrNull;
        final debt = creditAccount == null ? 0 : debtOf(creditAccount, balances[creditAccount.id] ?? 0);

        return ListView(
          padding: AppSpacing.scroll(context, top: AppSpacing.s8).copyWith(left: AppSpacing.s16, right: AppSpacing.s16),
          children: [
            SoftCard(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s18, AppSpacing.s20, AppSpacing.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconBubble(iconKey: rule.iconKey, colorKey: overdue ? 'blush' : rule.colorKey),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(frequencyLabel(context, rule), maxLines: 1, overflow: TextOverflow.ellipsis, style: text.rowTitle),
                            const SizedBox(height: AppSpacing.s2),
                            Text(
                              occ.status == OccStatus.paid && occ.paidAt != null
                                  ? l.occPaidOn(context.day(LocalDate.of(occ.paidAt!.toLocal())))
                                  : occ.status == OccStatus.skipped
                                  ? l.occSkipped
                                  : dueText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.rowSubtitle.copyWith(color: overdue ? colors.onBlush : null),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Center(
                    child: Text(
                      occ.amountExpected == null ? l.occAmountOnBill : l.occAmount,
                      style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  AmountField(
                    controller: _amount,
                    focusNode: _focus,
                    currency: account.currency,
                    autofocus: planned && occ.amountExpected == null,
                    large: false,
                    onChanged: () {},
                  ),
                  if (occ.currency != account.currency && occ.amountExpected != null) ...[
                    const SizedBox(height: AppSpacing.s6),
                    Center(
                      child: Text(
                        l.occApprox(
                          context.money(occ.amountExpected!, occ.currency),
                          context.money(converter.convert(occ.amountExpected!, occ.currency, account.currency) ?? 0, account.currency),
                          context.rate(converter.crossRateMicro(occ.currency, account.currency) ?? 0),
                        ),
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s8,
                    children: [
                      if (rule.kind == RuleKind.creditLinePayment && debt > 0) ...[
                        AppChip(
                          dense: true,
                          label: l.occFull(pillAmount(context, debt, account.currency)),
                          onTap: () => _amount.text = amountToInput(debt, account.currency, context.lang),
                        ),
                        if (creditAccount?.minPayment != null)
                          AppChip(
                            dense: true,
                            label: l.occMinimum(pillAmount(context, creditAccount!.minPayment!, account.currency)),
                            onTap: () => _amount.text = amountToInput(creditAccount.minPayment!, account.currency, context.lang),
                          ),
                      ] else if (_lastPaid != null && rule.kind != RuleKind.loanPayment)
                        AppChip(
                          dense: true,
                          muted: true,
                          label: l.occLastTime(pillAmount(context, _lastPaid!, rule.currency)),
                          onTap: () => _amount.text = amountToInput(_lastPaid!, rule.currency, context.lang),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s8,
                    children: [
                      AppChip(
                        dense: true,
                        icon: Icons.account_balance_wallet_outlined,
                        label: l.occFrom(account.name),
                        trailingIcon: Icons.expand_more_rounded,
                        onTap: () async {
                          final id = await pickAccount(
                            context,
                            accounts.where((a) => !a.isArchived && a.id != rule.counterAccountId).toList(),
                            title: l.occChooseAccount,
                            selected: account.id,
                          );
                          if (id != null) {
                            setState(() {
                              _accountId = id;
                              _prefilled = false;
                            });
                          }
                        },
                      ),
                      AppChip(
                        dense: true,
                        label: context.relativeDay(_date ?? today, today),
                        trailingIcon: Icons.expand_more_rounded,
                        onTap: () async {
                          final d = await pickDate(context, _date ?? today);
                          if (d != null) setState(() => _date = d);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

extension _Let<T> on T {
  void let(void Function(T) f) => f(this);
}
