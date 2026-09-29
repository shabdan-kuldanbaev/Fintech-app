import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../core/currencies.dart';
import '../../../core/money.dart';
import '../../notifications/reminder_permission.dart';
import '../../payments/data/obligation_repository.dart';
import '../../payments/presentation/remind_picker.dart';
import '../../transactions/presentation/amount_field.dart';
import '../../transactions/presentation/pickers.dart';
import '../domain/account.dart';
import '../domain/loan_math.dart';
import 'month_ruler.dart';
import 'style_pickers.dart';

/// «New loan» (§8.3, приём Simbank): сумма, шкала месяцев, ставка —
/// платёж и итого считаются сами, но оба редактируемы (§4.3): в базу
/// ложится то, что в полях, а не оценка.
class NewLoanScreen extends ConsumerStatefulWidget {
  const NewLoanScreen({super.key});

  @override
  ConsumerState<NewLoanScreen> createState() => _NewLoanScreenState();
}

class _NewLoanScreenState extends ConsumerState<NewLoanScreen> {
  final _amount = TextEditingController();
  final _amountFocus = FocusNode();
  final _rate = TextEditingController();
  final _payment = TextEditingController();
  final _total = TextEditingController();
  final _name = TextEditingController();
  int _months = 12;
  RatePeriod _period = RatePeriod.month;
  String? _currency;
  LocalDate? _first;
  String? _payFrom;
  List<int> _remind = const [3, 0];
  bool _more = false;
  bool _busy = false;
  bool _amountError = false;

  @override
  void dispose() {
    for (final c in [_amount, _rate, _payment, _total, _name]) {
      c.dispose();
    }
    _amountFocus.dispose();
    super.dispose();
  }

  /// Ставка в базисных пунктах: «2,24» → 224. Пусто — без ставки.
  int? get _rateBp => _rate.text.trim().isEmpty ? null : parseAmount(_rate.text, 'USD');

  /// Сумма, срок или ставка поменялись — платёж и итого снова из оценки.
  void _estimate(String currency) {
    final p = parseAmount(_amount.text, currency) ?? 0;
    final e = estimateLoan(principal: p, months: _months, rateBp: _rateBp, period: _period);
    final lang = context.lang;
    _payment.text = e.payment == 0 ? '' : amountToInput(e.payment, currency, lang);
    _total.text = e.total == 0 ? '' : amountToInput(e.total, currency, lang);
  }

  void _paymentEdited(String currency) {
    final p = parseAmount(_payment.text, currency);
    if (p == null) return;
    setState(() => _total.text = amountToInput(totalForPayment(p, _months), currency, context.lang));
  }

  void _totalEdited(String currency) {
    final t = parseAmount(_total.text, currency);
    if (t == null) return;
    setState(() => _payment.text = amountToInput(paymentForTotal(t, _months), currency, context.lang));
  }

  Future<void> _create(String currency, String? payFrom, LocalDate first) async {
    final l = context.l10n;
    final principal = parseAmount(_amount.text, currency);
    final payment = parseAmount(_payment.text, currency);
    final total = parseAmount(_total.text, currency);
    if (principal == null || principal <= 0 || payment == null || payment <= 0 || total == null || total <= 0) {
      setState(() => _amountError = true);
      return;
    }
    setState(() => _busy = true);
    final rate = _rateBp;
    final name = _name.text.trim().isEmpty
        ? l.loanDefaultName(context.money(principal, currency, whole: principal % 100 == 0))
        : _name.text.trim();
    final id = await ref.read(obligationRepositoryProvider).createLoan(
      LoanInput(
        name: name,
        currency: currency,
        principal: principal,
        totalPayable: total,
        monthlyPayment: payment,
        termMonths: _months,
        firstPaymentDate: first,
        rateBp: rate == null || rate == 0 ? null : rate,
        ratePeriod: rate == null || rate == 0 ? null : _period,
        payFromAccountId: payFrom,
        remindDaysBefore: _remind,
      ),
    );
    if (!mounted) return;
    unawaited(requestRemindersIfNeeded(ref.read(notificationGatewayProvider), ref.read(reminderServiceProvider), _remind));
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    context.pushReplacement(Routes.account(id));
    if (overlay != null) showActionToastOn(overlay, l.accountLoanOpened);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider).value;
    final accounts = ref.watch(accountsProvider).value;
    final today = ref.watch(todayProvider);
    final ready = settings != null && accounts != null;
    final currency = _currency ?? settings?.baseCurrency ?? 'USD';
    final payable = [
      for (final a in accounts ?? const <Account>[])
        if (!a.isArchived && a.kind.isAsset) a,
    ];
    final payFrom = _payFrom ??
        payable.where((a) => a.id == settings?.lastAccountId).firstOrNull?.id ??
        payable.firstOrNull?.id;
    final first = _first ?? today.addMonths(1);

    return GlassScaffold(
      header: ScreenHeader(leading: HeaderBack(tooltip: l.back), title: l.loanNew),
      bar: !ready
          ? null
          : FilledButton(
              key: const ValueKey('loan-create'),
              onPressed: _busy ? null : () => unawaited(_create(currency, payFrom, first)),
              child: Text(l.loanCreate),
            ),
      body: (context) {
        if (!ready) return const SizedBox.shrink();
        final text = Theme.of(context).textTheme;
        final scheme = Theme.of(context).colorScheme;
        final payment = parseAmount(_payment.text, currency);
        final sign = currencyInfo(currency).sign(context.lang);
        final account = payable.where((a) => a.id == payFrom).firstOrNull;
        return ListView(
          padding: AppSpacing.scroll(context, top: AppSpacing.s16).copyWith(left: AppSpacing.s16, right: AppSpacing.s16),
          children: [
            Center(child: Text(l.loanAmount, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))),
            const SizedBox(height: AppSpacing.s6),
            AmountField(
              controller: _amount,
              focusNode: _amountFocus,
              currency: currency,
              error: _amountError ? l.amountRequired : null,
              onChanged: () => setState(() {
                _amountError = false;
                _estimate(currency);
              }),
            ),
            const SizedBox(height: AppSpacing.s8),
            Center(
              child: AppChip(
                dense: true,
                label: currency,
                trailingIcon: Icons.expand_more_rounded,
                onTap: () async {
                  final c = await pickCurrency(context, selected: currency);
                  if (c != null) {
                    setState(() {
                      _currency = c;
                      _estimate(c);
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: AppSpacing.s20),
            Center(child: Text(l.loanMonths(_months), style: text.titleMedium)),
            const SizedBox(height: AppSpacing.s4),
            MonthRuler(
              value: _months,
              onChanged: (m) => setState(() {
                _months = m;
                _estimate(currency);
              }),
            ),
            const SizedBox(height: AppSpacing.s8),
            Center(child: Text(l.loanDrag, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
            const SizedBox(height: AppSpacing.s20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('loan-rate'),
                    controller: _rate,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: InputDecoration(labelText: l.loanRate, suffixText: '%'),
                    onChanged: (_) => setState(() => _estimate(currency)),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                AppSegmented<RatePeriod>(
                  values: RatePeriod.values,
                  labels: [l.loanPerMonth, l.loanPerYear],
                  selected: _period,
                  onChanged: (p) => setState(() {
                    _period = p;
                    _estimate(currency);
                  }),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            if (payment != null && payment > 0) ...[
              Center(
                child: Text(
                  '${l.loanMonths(_months)} ${l.loanTimes(context.money(payment, currency))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.s10),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('loan-payment'),
                    controller: _payment,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l.loanPayment, suffixText: sign),
                    onChanged: (_) => _paymentEdited(currency),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: TextField(
                    key: const ValueKey('loan-total'),
                    controller: _total,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l.loanTotal, suffixText: sign),
                    onChanged: (_) => _totalEdited(currency),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            RowsCard(
              children: [
                ValueRow(
                  label: l.loanFirstPayment,
                  value: context.dayYear(first),
                  onTap: () async {
                    final d = await pickDate(context, first, first: today.addMonths(-60));
                    if (d != null) setState(() => _first = d);
                  },
                ),
                if (_more) ...[
                  const RowDivider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.s18, AppSpacing.s10, AppSpacing.s18, AppSpacing.s10),
                    child: TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(labelText: '${l.fieldName} · ${l.optional}'),
                    ),
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
              ],
            ),
            if (!_more) ...[
              const SizedBox(height: AppSpacing.s8),
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _more = true),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.expand_more_rounded),
                  label: Text(l.loanMoreFields, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
