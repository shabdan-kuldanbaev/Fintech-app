import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/format.dart';
import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/toast.dart';
import '../../../core/calendar.dart';
import '../../../core/currencies.dart';
import '../../transactions/domain/transaction.dart';
import '../data/rule_repository.dart';
import '../domain/rule.dart';

/// Сумма для кнопки: без нулевой дробной части; знак валюты — только если
/// она не базовая («Pay 18 000», «Pay 2 584,31», «\$9.99»).
String pillAmount(BuildContext context, int minor, String currency, {String? base}) {
  var p = 1;
  for (var i = 0; i < minorUnits(currency); i++) {
    p *= 10;
  }
  return context.money(
    minor,
    currency,
    whole: minor % p == 0,
    symbol: base != null && currency != base,
  );
}

/// Нужен ли экран наступления, или можно оплатить прямо в строке (§8.3).
bool needsScreen(DueItem i) =>
    i.rule.kind == RuleKind.creditLinePayment ||
    i.occurrence.amountExpected == null ||
    i.rule.accountId == null;

/// «Pay N» в строке: оплата ожидаемой суммой со счёта правила, тост
/// «Paid · Undo». Если нужна сумма или выбор — экран наступления.
Future<void> payFromRow(BuildContext context, WidgetRef ref, DueItem item) async {
  if (needsScreen(item)) {
    unawaited(context.push(Routes.occurrence(item.occurrence.id)));
    return;
  }
  final l = context.l10n;
  final repo = ref.read(ruleRepositoryProvider);
  final overlay = Overlay.of(context, rootOverlay: true);
  try {
    await repo.payAsExpected(item.occurrence.id);
    showActionToastOn(
      overlay,
      l.paidToast(item.rule.name),
      actions: [ToastAction(l.undo, () => unawaited(repo.unpay(item.occurrence.id)), primary: true)],
    );
  } on MissingRate catch (e) {
    showActionToastOn(overlay, l.addMissingRate(e.currency), icon: Icons.info_outline_rounded);
  } on RuleValidationError {
    if (context.mounted) unawaited(context.push(Routes.occurrence(item.occurrence.id)));
  }
}

Future<void> skipFromRow(BuildContext context, WidgetRef ref, DueItem item) async {
  final l = context.l10n;
  final repo = ref.read(ruleRepositoryProvider);
  final overlay = Overlay.of(context, rootOverlay: true);
  await repo.skip(item.occurrence.id);
  showActionToastOn(
    overlay,
    l.skippedToast(item.rule.name),
    icon: Icons.redo_rounded,
    actions: [ToastAction(l.undo, () => unawaited(repo.unskip(item.occurrence.id)), primary: true)],
  );
}

/// Когда платить: «Overdue 4 days», «Tomorrow», «Oct 3», «In 12 days».
String whenLabel(BuildContext context, LocalDate due, LocalDate today) {
  final l = context.l10n;
  final d = today.daysUntil(due);
  if (d < 0) return l.overdueDays(-d);
  if (d == 0) return l.today;
  if (d == 1) return l.tomorrow;
  return context.day(due);
}

/// Строка наступления (макет «Home · Upcoming», «Payments»): иконка,
/// имя (обрезается), когда, справа — кнопка с суммой (не сжимается, §8.0).
class DueRow extends ConsumerWidget {
  const DueRow({super.key, required this.item, this.total, this.showWhen = true});

  final DueItem item;

  /// Когда платить — в подписи; `false` под группой «Today» / «Tomorrow»,
  /// которая уже это говорит.
  final bool showWhen;

  /// Сколько всего платежей (кредит): «1 of 2».
  final int? total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final today = ref.watch(todayProvider);
    final base = ref.watch(settingsProvider).value?.baseCurrency;
    final o = item.occurrence;
    final r = item.rule;
    final overdue = o.isOverdue(today);
    final parts = <String>[
      if (showWhen || overdue) whenLabel(context, o.dueDate, today),
      if (total != null) l.seqOf(o.seq, total!),
      if (r.autoPay && !overdue) l.autoPayShort,
      if (r.kind == RuleKind.creditLinePayment && (o.amountExpected ?? 0) > 0 && _min(ref) != null)
        l.minPaymentShort(pillAmount(context, _min(ref)!, o.currency, base: base)),
    ];
    final Widget trailing;
    if (r.kind == RuleKind.creditLinePayment) {
      trailing = (o.amountExpected ?? 0) == 0
          ? Text(l.nothingToPay, style: Theme.of(context).textTheme.bodySmall)
          : PillButton(label: l.payEllipsis, tone: overdue ? PillTone.alert : PillTone.primary, onPressed: () => payFromRow(context, ref, item));
    } else if (o.amountExpected == null) {
      trailing = PillButton(
        label: l.enterAmount,
        tone: overdue ? PillTone.alert : PillTone.soft,
        onPressed: () => payFromRow(context, ref, item),
      );
    } else if (r.autoPay && !overdue) {
      trailing = AmountText(pillAmount(context, o.amountExpected!, o.currency, base: base), color: scheme.onSurfaceVariant);
    } else {
      final amount = pillAmount(context, o.amountExpected!, o.currency, base: base);
      final full = l.payAmount(amount);
      return LayoutBuilder(
        builder: (context, constraints) {
          // Кнопке — не больше ~38 % строки, иначе имя обрезается до «Si…»:
          // тогда глагол уступает место галочке (§8.0).
          final compact = _labelWidth(context, full) + 28 > constraints.maxWidth * 0.38;
          return _row(
            context,
            PillButton(
              key: ValueKey('pay-${o.id}'),
              label: compact ? amount : full,
              icon: compact ? Icons.check_rounded : null,
              tone: overdue ? PillTone.alert : PillTone.primary,
              onPressed: () => payFromRow(context, ref, item),
            ),
            parts,
            overdue,
            colors,
          );
        },
      );
    }
    return _row(context, trailing, parts, overdue, colors);
  }

  double _labelWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: Theme.of(context).textTheme.chipLabel),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }

  Widget _row(BuildContext context, Widget trailing, List<String> parts, bool overdue, AppColors colors) {
    final o = item.occurrence;
    final r = item.rule;
    return AppRow(
      key: ValueKey('due-${o.id}'),
      leading: IconBubble(iconKey: r.iconKey, colorKey: overdue ? 'blush' : r.colorKey),
      title: r.name,
      subtitle: parts.join(' · '),
      subtitleColor: overdue ? colors.onBlush : null,
      trailing: trailing,
      onTap: () => unawaited(context.push(Routes.occurrence(o.id))),
    );
  }

  int? _min(WidgetRef ref) {
    final accounts = ref.watch(accountMapProvider).value;
    return accounts?[item.rule.counterAccountId]?.minPayment;
  }
}
