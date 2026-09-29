import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/format.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/header.dart';
import '../../../app/widgets/toast.dart';
import '../../../core/calendar.dart';
import '../../../core/currencies.dart';
import '../../../core/money.dart';
import '../../transactions/presentation/pickers.dart';
import '../domain/account.dart';
import 'style_pickers.dart';

/// «New account» / «Edit account» (§8.3). Кредит и кредитная линия
/// создаются своими формами; здесь их можно только поправить.
class AccountEditScreen extends ConsumerStatefulWidget {
  const AccountEditScreen({super.key, this.id, this.kind = AccountKind.card});

  final String? id;
  final AccountKind kind;

  @override
  ConsumerState<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends ConsumerState<AccountEditScreen> {
  final _name = TextEditingController();
  final _balance = TextEditingController();
  final _target = TextEditingController();
  final _limit = TextEditingController();
  final _minPayment = TextEditingController();
  late AccountKind _kind = widget.kind;
  String? _currency;
  String? _iconKey;
  String? _colorKey;
  bool _include = true;
  LocalDate? _targetDate;
  int? _dueDay;
  Account? _loaded;
  bool _busy = false;
  bool _nameError = false;

  bool get _isNew => widget.id == null;

  @override
  void dispose() {
    for (final c in [_name, _balance, _target, _limit, _minPayment]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(Account a, int balance) {
    if (_loaded != null) return;
    _loaded = a;
    final lang = context.lang;
    _kind = a.kind;
    _name.text = a.name;
    _currency = a.currency;
    _iconKey = a.iconKey;
    _colorKey = a.colorKey;
    _include = a.includeInTotal;
    _targetDate = a.targetDate;
    _dueDay = a.dueDay;
    if (!a.kind.isLiability) _balance.text = amountToInput(balance, a.currency, lang);
    if (a.targetAmount != null) _target.text = amountToInput(a.targetAmount!, a.currency, lang);
    if (a.creditLimit != null) _limit.text = amountToInput(a.creditLimit!, a.currency, lang);
    if (a.minPayment != null) _minPayment.text = amountToInput(a.minPayment!, a.currency, lang);
  }

  Future<void> _save(String currency, int? currentBalance) async {
    final l = context.l10n;
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = true);
      return;
    }
    int? amount(TextEditingController c) => c.text.trim().isEmpty ? null : parseAmount(c.text, currency);
    final old = _loaded;
    final input = AccountInput(
      name: _name.text,
      kind: _kind,
      currency: currency,
      openingBalance: _isNew ? (amount(_balance) ?? 0) : (old?.openingBalance ?? 0),
      iconKey: _iconKey ?? _kind.defaultIcon,
      colorKey: _colorKey ?? _kind.defaultColor,
      includeInTotal: _include,
      targetAmount: _kind == AccountKind.savings ? amount(_target) : null,
      targetDate: _kind.isSaving ? _targetDate : null,
      creditLimit: _kind == AccountKind.creditLine ? amount(_limit) : old?.creditLimit,
      dueDay: _kind == AccountKind.creditLine ? _dueDay : old?.dueDay,
      minPayment: _kind == AccountKind.creditLine ? amount(_minPayment) : old?.minPayment,
      totalPayable: old?.totalPayable,
      monthlyPayment: old?.monthlyPayment,
      termMonths: old?.termMonths,
      firstPaymentDate: old?.firstPaymentDate,
      principal: old?.principal,
      rateBp: old?.rateBp,
      ratePeriod: old?.ratePeriod,
    );
    setState(() => _busy = true);
    final repo = ref.read(accountRepositoryProvider);
    try {
      if (_isNew) {
        await repo.create(input);
      } else {
        await repo.update(widget.id!, input);
        if (_kind.isLiability) {
          await ref.read(obligationRepositoryProvider).syncRule(widget.id!);
          await ref.read(occurrencePlannerProvider).replan();
        }
        final target = amount(_balance);
        if (!_kind.isLiability && target != null && currentBalance != null && target != currentBalance) {
          if (await repo.hasTransactions(widget.id!)) {
            await ref.read(transactionRepositoryProvider).adjustBalance(
              accountId: widget.id!,
              currentBalance: currentBalance,
              targetBalance: target,
              date: ref.read(todayProvider),
            );
          } else {
            await repo.setOpeningBalance(widget.id!, target);
          }
        }
      }
      if (mounted) context.closeScreen();
    } on AccountValidationError catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showActionToast(
        context,
        e.reason == 'currency_locked' ? l.currencyLocked : l.amountRequired,
        icon: Icons.info_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final account = _isNew ? null : ref.watch(accountProvider(widget.id!)).value;
    final balances = ref.watch(balancesProvider).value;
    final settings = ref.watch(settingsProvider).value;
    if (account != null && balances != null) _load(account, balances[account.id] ?? account.openingBalance);
    final currency = _currency ?? settings?.baseCurrency ?? 'USD';
    final currentBalance = account == null ? null : balances?[account.id];
    final colorKey = _colorKey ?? _kind.defaultColor;
    final iconKey = _iconKey ?? _kind.defaultIcon;
    final ready = settings != null && (_isNew || account != null);

    return GlassScaffold(
      header: ScreenHeader(
        leading: HeaderBack(tooltip: l.back),
        title: _isNew ? l.accountNew : l.accountEdit,
      ),
      bar: !ready
          ? null
          : FilledButton(
              onPressed: _busy ? null : () => unawaited(_save(currency, currentBalance)),
              child: Text(_isNew ? l.create : l.save),
            ),
      body: (context) {
        if (!ready) return const SizedBox.shrink();
        final sign = currencyInfo(currency).sign(context.lang);
        return ListView(
          padding: AppSpacing.scroll(context, top: AppSpacing.s16).copyWith(left: AppSpacing.s16, right: AppSpacing.s16),
          children: [
            Center(child: IconBubble(iconKey: iconKey, colorKey: colorKey, size: 64)),
            const SizedBox(height: AppSpacing.s16),
            if (_isNew && _kind.isEveryday) ...[
              Center(
                child: AppSegmented<AccountKind>(
                  values: const [AccountKind.cash, AccountKind.card],
                  labels: [l.accountKindCash, l.accountKindCard],
                  selected: _kind,
                  onChanged: (k) => setState(() => _kind = k),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
            ],
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.fieldName, errorText: _nameError ? l.nameRequired : null),
              onChanged: (_) {
                if (_nameError) setState(() => _nameError = false);
              },
            ),
            const SizedBox(height: AppSpacing.s12),
            if (!_kind.isLiability) ...[
              TextField(
                controller: _balance,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l.fieldBalance, suffixText: sign),
              ),
              const SizedBox(height: AppSpacing.s12),
            ],
            if (_kind == AccountKind.savings) ...[
              TextField(
                controller: _target,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: '${l.fieldTarget} · ${l.optional}', suffixText: sign),
              ),
              const SizedBox(height: AppSpacing.s12),
            ],
            if (_kind == AccountKind.creditLine) ...[
              TextField(
                controller: _limit,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l.fieldLimit, suffixText: sign),
              ),
              const SizedBox(height: AppSpacing.s12),
              TextField(
                controller: _minPayment,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: '${l.fieldMinPayment} · ${l.optional}', suffixText: sign),
              ),
              const SizedBox(height: AppSpacing.s12),
            ],
            RowsCard(
              children: [
                ValueRow(
                  label: l.fieldCurrency,
                  value: currency,
                  onTap: _kind == AccountKind.loan
                      ? null
                      : () async {
                          final picked = await pickCurrency(context, selected: currency);
                          if (picked != null) setState(() => _currency = picked);
                        },
                ),
                if (_kind.isSaving) ...[
                  const RowDivider(),
                  ValueRow(
                    label: _kind == AccountKind.deposit ? l.fieldEndDate : l.fieldTargetDate,
                    value: _targetDate == null ? l.none : context.dayYear(_targetDate!),
                    onTap: () async {
                      final d = await pickDate(context, _targetDate ?? ref.read(todayProvider).addMonths(6));
                      if (d != null) setState(() => _targetDate = d);
                    },
                  ),
                ],
                if (_kind == AccountKind.creditLine) ...[
                  const RowDivider(),
                  ValueRow(
                    label: l.fieldDueDay,
                    value: _dueDay == null ? l.none : l.dayOfMonth(_dueDay!),
                    onTap: () async {
                      final d = await pickDayOfMonth(context, title: l.fieldDueDay, selected: _dueDay);
                      if (d != null) setState(() => _dueDay = d);
                    },
                  ),
                ],
                const RowDivider(),
                ValueRow(
                  label: l.fieldIcon,
                  value: '',
                  trailing: Icon(appIconOf(iconKey), color: Theme.of(context).colorScheme.onSurface),
                  onTap: () async {
                    final k = await pickIcon(context, title: l.fieldIcon, colorKey: colorKey, selected: iconKey);
                    if (k != null) setState(() => _iconKey = k);
                  },
                ),
                const RowDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s18, AppSpacing.s12, AppSpacing.s18, AppSpacing.s14),
                  child: ColorRow(selected: colorKey, onChanged: (k) => setState(() => _colorKey = k)),
                ),
                if (_kind.isAsset) ...[
                  const RowDivider(),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s18),
                    title: Text(l.fieldIncludeInTotal),
                    value: _include,
                    onChanged: (v) => setState(() => _include = v),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}
