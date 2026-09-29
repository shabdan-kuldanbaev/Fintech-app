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
import '../../../core/currencies.dart';
import '../../../core/money.dart';
import '../../notifications/reminder_permission.dart';
import '../../payments/data/obligation_repository.dart';
import '../../payments/presentation/remind_picker.dart';
import '../../transactions/presentation/pickers.dart';
import '../domain/account.dart';
import 'style_pickers.dart';

/// «New credit line» (§8.3): имя, лимит, валюта, текущий долг, день оплаты,
/// счёт списания, напоминания. Создаются счёт и правило погашения (§3.4).
class NewCreditLineScreen extends ConsumerStatefulWidget {
  const NewCreditLineScreen({super.key});

  @override
  ConsumerState<NewCreditLineScreen> createState() => _NewCreditLineScreenState();
}

class _NewCreditLineScreenState extends ConsumerState<NewCreditLineScreen> {
  final _name = TextEditingController();
  final _limit = TextEditingController();
  final _debt = TextEditingController();
  final _min = TextEditingController();
  String? _currency;
  int? _dueDay;
  String? _payFrom;
  List<int> _remind = const [3, 0];
  bool _busy = false;
  bool _nameError = false;
  bool _limitError = false;
  bool _dayError = false;

  @override
  void dispose() {
    for (final c in [_name, _limit, _debt, _min]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _create(String currency, String? payFrom) async {
    final limit = parseAmount(_limit.text, currency);
    setState(() {
      _nameError = _name.text.trim().isEmpty;
      _limitError = limit == null || limit <= 0;
      _dayError = _dueDay == null;
    });
    if (_nameError || _limitError || _dayError) return;
    setState(() => _busy = true);
    int? optional(TextEditingController c) => c.text.trim().isEmpty ? null : parseAmount(c.text, currency);
    final id = await ref.read(obligationRepositoryProvider).createCreditLine(
      CreditLineInput(
        name: _name.text.trim(),
        currency: currency,
        creditLimit: limit!,
        dueDay: _dueDay!,
        currentDebt: optional(_debt) ?? 0,
        minPayment: optional(_min),
        payFromAccountId: payFrom,
        remindDaysBefore: _remind,
      ),
    );
    await ref.read(occurrencePlannerProvider).replan();
    if (!mounted) return;
    unawaited(requestRemindersIfNeeded(ref.read(notificationGatewayProvider), ref.read(reminderServiceProvider), _remind));
    context.pushReplacement(Routes.account(id));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider).value;
    final accounts = ref.watch(accountsProvider).value;
    final ready = settings != null && accounts != null;
    final currency = _currency ?? settings?.baseCurrency ?? 'USD';
    final payable = [
      for (final a in accounts ?? const <Account>[])
        if (!a.isArchived && a.kind.isAsset) a,
    ];
    final payFrom = _payFrom ??
        payable.where((a) => a.id == settings?.lastAccountId).firstOrNull?.id ??
        payable.firstOrNull?.id;

    return GlassScaffold(
      header: ScreenHeader(leading: HeaderBack(tooltip: l.back), title: l.creditLineNew),
      bar: !ready
          ? null
          : FilledButton(
              key: const ValueKey('credit-line-create'),
              onPressed: _busy ? null : () => unawaited(_create(currency, payFrom)),
              child: Text(l.create),
            ),
      body: (context) {
        if (!ready) return const SizedBox.shrink();
        final sign = currencyInfo(currency).sign(context.lang);
        final account = payable.where((a) => a.id == payFrom).firstOrNull;
        final colors = AppColors.of(context);
        TextField money(TextEditingController c, String label, {bool error = false, Key? key}) => TextField(
          key: key,
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, suffixText: sign, errorText: error ? l.amountRequired : null),
          onChanged: (_) {
            if (_limitError) setState(() => _limitError = false);
          },
        );
        return ListView(
          padding: AppSpacing.scroll(context, top: AppSpacing.s16).copyWith(left: AppSpacing.s16, right: AppSpacing.s16),
          children: [
            Center(child: IconBubble(iconKey: AccountKind.creditLine.defaultIcon, colorKey: AccountKind.creditLine.defaultColor, size: 64)),
            const SizedBox(height: AppSpacing.s16),
            TextField(
              key: const ValueKey('credit-line-name'),
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.fieldName, errorText: _nameError ? l.nameRequired : null),
              onChanged: (_) {
                if (_nameError) setState(() => _nameError = false);
              },
            ),
            const SizedBox(height: AppSpacing.s12),
            money(_limit, l.fieldLimit, error: _limitError, key: const ValueKey('credit-line-limit')),
            const SizedBox(height: AppSpacing.s12),
            money(_debt, '${l.fieldCurrentDebt} · ${l.optional}'),
            const SizedBox(height: AppSpacing.s12),
            money(_min, '${l.fieldMinPayment} · ${l.optional}'),
            const SizedBox(height: AppSpacing.s12),
            RowsCard(
              children: [
                ValueRow(
                  label: l.fieldCurrency,
                  value: currency,
                  onTap: () async {
                    final c = await pickCurrency(context, selected: currency);
                    if (c != null) setState(() => _currency = c);
                  },
                ),
                const RowDivider(),
                ValueRow(
                  key: const ValueKey('credit-line-day'),
                  label: l.fieldDueDay,
                  value: _dueDay == null ? l.none : l.dayOfMonth(_dueDay!),
                  valueColor: _dayError ? colors.onBlush : null,
                  onTap: () async {
                    final d = await pickDayOfMonth(context, title: l.fieldDueDay, selected: _dueDay);
                    if (d != null) {
                      setState(() {
                        _dueDay = d;
                        _dayError = false;
                      });
                    }
                  },
                ),
                const RowDivider(),
                ValueRow(
                  label: l.fieldPayFrom,
                  value: account?.name ?? l.none,
                  onTap: () async {
                    final id = await pickAccount(context, payable, title: l.fieldPayFrom, selected: payFrom);
                    if (id != null) setState(() => _payFrom = id);
                  },
                ),
                const RowDivider(),
                ValueRow(
                  label: l.ruleRemind,
                  value: remindText(context, _remind),
                  onTap: () async {
                    final days = await pickRemindDays(context);
                    if (days != null) setState(() => _remind = days);
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
