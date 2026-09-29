import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../../core/icons.dart';
import '../../../core/money.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/style_pickers.dart';
import '../../categories/domain/category.dart';
import '../../notifications/reminder_permission.dart';
import '../../transactions/presentation/pickers.dart';
import '../domain/rule.dart';
import '../domain/schedule.dart';
import 'remind_picker.dart';

/// «New payment» / «Edit payment» (§8.3, макет «New payment»): сегмент
/// вида, три поля сверху (имя, сумма, следующее списание), ниже —
/// умолчания (категория, счёт, напоминания, автосписание).
class RuleEditScreen extends ConsumerStatefulWidget {
  const RuleEditScreen({super.key, this.id, this.kind = RuleKind.subscription});

  final String? id;
  final RuleKind kind;

  @override
  ConsumerState<RuleEditScreen> createState() => _RuleEditScreenState();
}

class _RuleEditScreenState extends ConsumerState<RuleEditScreen> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  late RuleKind _kind = widget.kind;
  String? _currency;
  bool _varies = false;
  LocalDate? _next;
  Frequency _frequency = Frequency.monthly;
  int _interval = 1;
  LocalDate? _end;
  String? _categoryId;
  String? _accountId;
  List<int> _remind = const [3, 0];
  int? _remindMinutes;
  bool? _autoPay;
  String? _iconKey;
  String? _colorKey;
  Rule? _loaded;
  bool _busy = false;
  bool _nameError = false;
  bool _amountError = false;

  bool get _isNew => widget.id == null;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _load(Rule r) {
    if (_loaded != null) return;
    _loaded = r;
    _kind = r.kind;
    _name.text = r.name;
    _currency = r.currency;
    _varies = r.amount == null;
    if (r.amount != null) _amount.text = amountToInput(r.amount!, r.currency, context.lang);
    _frequency = r.frequency;
    _interval = r.interval;
    _end = r.endDate;
    _categoryId = r.categoryId;
    _accountId = r.accountId;
    _remind = r.remindDaysBefore;
    _remindMinutes = r.remindMinutes;
    _autoPay = r.autoPay;
    _iconKey = r.iconKey;
    _colorKey = r.colorKey;
  }

  bool get _autoPayValue => _autoPay ?? _kind == RuleKind.subscription;

  /// Следующая дата с тем же днём: для новой — через месяц от сегодня
  /// ближайшая подходящая; для правки — ближайшее будущее наступление.
  LocalDate _nextDate(LocalDate today) {
    if (_next != null) return _next!;
    final r = _loaded;
    if (r != null) return nextDateAfter(r.spec, today.addDays(-1)) ?? r.startDate;
    return today.addDays(1);
  }

  Future<void> _save(List<Category> categories, String base, String? defaultAccount) async {
    final l = context.l10n;
    final currency = _currency ?? base;
    final amount = _varies ? null : parseAmount(_amount.text, currency);
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = true);
      return;
    }
    if (!_varies && (amount == null || amount == 0)) {
      setState(() => _amountError = true);
      return;
    }
    final today = ref.read(todayProvider);
    final next = _nextDate(today);
    final category = _categoryId ??
        categories.where((c) => c.key == _kind.defaultCategoryKey).firstOrNull?.id ??
        categories.firstWhere((c) => c.kind == CategoryKind.expense && !c.isSystem).id;
    final input = RuleInput(
      name: _name.text,
      kind: _kind,
      currency: currency,
      amount: amount,
      frequency: _frequency,
      interval: _interval,
      dayOfMonth: _frequency == Frequency.monthly || _frequency == Frequency.yearly ? next.day : null,
      startDate: _isNew ? next : _startFor(next),
      endDate: _end,
      categoryId: category,
      accountId: _accountId ?? defaultAccount,
      remindDaysBefore: _remind,
      remindMinutes: _remindMinutes,
      autoPay: _autoPayValue,
      iconKey: _iconKey,
      colorKey: _colorKey,
    );
    setState(() => _busy = true);
    final repo = ref.read(ruleRepositoryProvider);
    if (_isNew) {
      await repo.insert(input);
    } else {
      await repo.update(widget.id!, input);
    }
    await ref.read(occurrencePlannerProvider).replan();
    if (!mounted) return;
    unawaited(requestRemindersIfNeeded(ref.read(notificationGatewayProvider), ref.read(reminderServiceProvider), _remind));
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    context.closeScreen();
    if (overlay != null) showActionToastOn(overlay, l.changesSaved);
  }

  /// Правка: история начинается там, где была; меняется только будущее.
  LocalDate _startFor(LocalDate next) {
    final r = _loaded!;
    if (_next == null && r.frequency == _frequency && r.interval == _interval) return r.startDate;
    return next;
  }

  Future<void> _pickNext(LocalDate today) async {
    final l = context.l10n;
    final d = await pickDate(context, _nextDate(today), first: today.addDays(-365));
    if (d == null || !mounted) return;
    setState(() => _next = d);
    final f = await showPickSheet<(Frequency, int)>(
      context,
      title: l.ruleRepeat,
      selected: (_frequency, _interval),
      items: [
        PickItem(value: (Frequency.monthly, 1), label: l.freqMonthly),
        PickItem(value: (Frequency.monthly, 3), label: l.freqEveryNMonths(3)),
        PickItem(value: (Frequency.weekly, 1), label: l.freqWeekly),
        PickItem(value: (Frequency.yearly, 1), label: l.freqYearly),
        PickItem(value: (Frequency.everyNDays, 30), label: l.freqEveryNDays(30)),
      ],
    );
    if (f != null) {
      setState(() {
        _frequency = f.$1;
        _interval = f.$2;
      });
    }
  }

  String _frequencyText() {
    final l = context.l10n;
    return switch (_frequency) {
      Frequency.monthly => _interval == 1 ? l.freqMonthly : l.freqEveryNMonths(_interval),
      Frequency.weekly => l.freqWeekly,
      Frequency.yearly => l.freqYearly,
      Frequency.everyNDays => l.freqEveryNDays(_interval),
    };
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final ok = await showConfirm(
      context,
      title: l.ruleDeleteTitle,
      body: l.ruleDeleteBody,
      cancel: l.cancel,
      confirm: l.delete,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(ruleRepositoryProvider).delete(widget.id!);
    if (mounted) context.closeScreen();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rule = _isNew ? null : ref.watch(ruleProvider(widget.id!)).value;
    final categories = ref.watch(categoriesProvider).value;
    final accounts = ref.watch(accountsProvider).value;
    final settings = ref.watch(settingsProvider).value;
    final rules = ref.watch(rulesProvider).value;
    if (rule != null) _load(rule);
    final ready = categories != null && accounts != null && settings != null && rules != null && (_isNew || rule != null);
    final today = ref.watch(todayProvider);

    return GlassScaffold(
      header: ScreenHeader(
        leading: HeaderBack(tooltip: l.back),
        title: _isNew ? l.ruleNew : l.ruleEdit,
        trailing: _isNew
            ? null
            : GlassIconButton(icon: Icons.delete_outline_rounded, tooltip: l.delete, onPressed: () => unawaited(_delete())),
      ),
      bar: !ready
          ? null
          : FilledButton(
              onPressed: _busy
                  ? null
                  : () => unawaited(_save(categories, settings.baseCurrency, _defaultAccount(rules, _payable(accounts), settings.lastAccountId))),
              child: Text(l.save),
            ),
      body: (context) {
        if (!ready) return const SizedBox.shrink();
        final currency = _currency ?? settings.baseCurrency;
        final category = categories.where((c) => c.id == _categoryId).firstOrNull ??
            categories.where((c) => c.key == _kind.defaultCategoryKey).firstOrNull;
        final accountId = _accountId ?? _defaultAccount(rules, _payable(accounts), settings.lastAccountId);
        final account = accounts.where((a) => a.id == accountId).firstOrNull;
        final next = _nextDate(today);
        final text = Theme.of(context).textTheme;
        return ListView(
          padding: AppSpacing.scroll(context, top: AppSpacing.s8).copyWith(left: AppSpacing.s16, right: AppSpacing.s16),
          children: [
            if (_isNew || RuleKind.userKinds.contains(_kind)) ...[
              AppSegmented<RuleKind>(
                expand: true,
                values: RuleKind.userKinds,
                labels: [l.ruleKindSubscription, l.ruleKindUtility, l.ruleKindOther],
                selected: _kind,
                onChanged: (k) => setState(() {
                  _kind = k;
                  if (_categoryId == null) _iconKey = null;
                  _varies = k == RuleKind.utility;
                }),
              ),
              const SizedBox(height: AppSpacing.s16),
            ],
            TextField(
              controller: _name,
              autofocus: _isNew,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.fieldName, hintText: l.ruleNameHint, errorText: _nameError ? l.nameRequired : null),
              onChanged: (_) {
                if (_nameError) setState(() => _nameError = false);
              },
            ),
            const SizedBox(height: AppSpacing.s12),
            if (!_varies)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: l.txAmount, errorText: _amountError ? l.amountRequired : null),
                      onChanged: (_) {
                        if (_amountError) setState(() => _amountError = false);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  AppChip(
                    label: currency,
                    trailingIcon: Icons.expand_more_rounded,
                    onTap: () async {
                      final c = await pickCurrency(context, selected: currency);
                      if (c != null) setState(() => _currency = c);
                    },
                  ),
                ],
              ),
            if (_kind == RuleKind.utility || _varies)
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                title: Text(l.ruleAmountVaries, style: text.bodyLarge),
                value: _varies,
                onChanged: (v) => setState(() => _varies = v),
              ),
            const SizedBox(height: AppSpacing.s12),
            RowsCard(
              children: [
                ValueRow(
                  label: l.ruleNextCharge,
                  value: '${context.day(next)} · ${_frequencyText()}',
                  onTap: () => unawaited(_pickNext(today)),
                ),
                const RowDivider(),
                ValueRow(
                  label: l.ruleEnds,
                  value: _end == null ? l.ruleNoEnd : context.dayYear(_end!),
                  onTap: () async {
                    if (_end != null) {
                      setState(() => _end = null);
                      return;
                    }
                    final d = await pickDate(context, next.addMonths(12), first: next);
                    if (d != null) setState(() => _end = d);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            RowsCard(
              children: [
                ValueRow(
                  label: l.txCategory,
                  value: category == null ? '' : categoryName(l, category),
                  leading: category == null ? null : IconBubble(iconKey: category.iconKey, colorKey: category.colorKey, size: 32),
                  onTap: () async {
                    final c = await pickCategory(
                      context,
                      categories.where((c) => c.kind == CategoryKind.expense && !c.isSystem).toList(),
                      title: l.pickCategory,
                      selected: category?.id,
                    );
                    if (c != null) {
                      setState(() {
                        _categoryId = c.id;
                        _iconKey ??= c.iconKey;
                        _colorKey ??= c.colorKey;
                      });
                    }
                  },
                ),
                const RowDivider(),
                ValueRow(
                  label: l.fieldPayFrom,
                  value: account?.name ?? l.none,
                  onTap: () async {
                    final id = await pickAccount(context, accounts.where((a) => !a.isArchived).toList(), title: l.fieldPayFrom, selected: accountId);
                    if (id != null) {
                      setState(() {
                        _accountId = id;
                                          });
                    }
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
                const RowDivider(),
                ValueRow(
                  label: l.ruleRemindTime,
                  value: context.minutes(_remindMinutes ?? settings.defaultReminderMinutes),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: (_remindMinutes ?? settings.defaultReminderMinutes) ~/ 60,
                        minute: (_remindMinutes ?? settings.defaultReminderMinutes) % 60,
                      ),
                    );
                    if (t != null) setState(() => _remindMinutes = t.hour * 60 + t.minute);
                  },
                ),
                const RowDivider(),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s18),
                  title: Text(l.ruleAutoPay),
                  subtitle: Text(l.ruleAutoPayHint),
                  value: _autoPayValue,
                  onChanged: (v) => setState(() => _autoPay = v),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            RowsCard(
              children: [
                ValueRow(
                  label: l.fieldIcon,
                  value: '',
                  trailing: Icon(iconFor(_iconKey ?? category?.iconKey ?? _kind.defaultIcon)),
                  onTap: () async {
                    final k = await pickIcon(context, title: l.fieldIcon, colorKey: _colorKey ?? _kind.defaultColor, selected: _iconKey);
                    if (k != null) setState(() => _iconKey = k);
                  },
                ),
                const RowDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s18, AppSpacing.s12, AppSpacing.s18, AppSpacing.s14),
                  child: ColorRow(
                    selected: _colorKey ?? category?.colorKey ?? _kind.defaultColor,
                    onChanged: (k) => setState(() => _colorKey = k),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  List<String> _payable(List<Account> accounts) =>
      [for (final a in accounts) if (!a.isArchived && a.kind.isAsset) a.id];

  /// Счёт по умолчанию: последний, с которого платили правила этого вида,
  /// иначе последний счёт вообще (§8.3).
  String? _defaultAccount(List<Rule> rules, List<String> ids, String? last) {
    final sameKind = rules.where((r) => r.kind == _kind && r.accountId != null && ids.contains(r.accountId)).toList();
    if (sameKind.isNotEmpty) return sameKind.last.accountId;
    return last != null && ids.contains(last) ? last : (ids.isEmpty ? null : ids.first);
  }
}
