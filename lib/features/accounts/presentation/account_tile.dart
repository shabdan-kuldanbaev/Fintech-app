import 'package:flutter/material.dart';

import '../../../app/format.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../core/calendar.dart';
import '../domain/account.dart';
import '../domain/balances.dart';
import 'account_providers.dart';

/// Что показать на плитке счёта (§8.3 «Accounts»): верхняя подпись справа,
/// крупное число, нижняя подпись, доля для полоски.
class AccountFacts {
  const AccountFacts({
    required this.value,
    this.corner,
    this.caption,
    this.progress,
  });

  final String value;
  final String? corner;
  final String? caption;
  final double? progress;

  static AccountFacts of(
    BuildContext context,
    Account a, {
    required int balance,
    required int? monthDelta,
    required LocalDate today,
    ObligationInfo? info,
  }) {
    final l = context.l10n;
    String m(int v, {bool whole = true}) => context.money(v, a.currency, whole: whole, symbol: false);
    switch (a.kind) {
      case AccountKind.cash:
      case AccountKind.card:
        return AccountFacts(
          value: m(balance),
          caption: monthDelta == null || monthDelta == 0 ? null : l.accountThisMonth(context.money(monthDelta, a.currency, whole: true, symbol: false, plus: true)),
        );
      case AccountKind.savings:
        final target = a.targetAmount;
        return AccountFacts(
          value: m(balance),
          corner: a.targetDate == null ? null : l.accountByDate(context.monthYearUntil(a.targetDate!)),
          caption: target == null || target <= 0
              ? null
              : l.accountGoalOf(m(target), (balance * 100 ~/ target).clamp(0, 999)),
          progress: target == null || target <= 0 ? null : balance / target,
        );
      case AccountKind.deposit:
        return AccountFacts(
          value: m(balance),
          corner: a.targetDate == null ? null : l.accountByDate(context.dayYear(a.targetDate!)),
        );
      case AccountKind.creditLine:
        final limit = a.creditLimit ?? 0;
        final debt = debtOf(a, balance);
        final next = info?.next ?? _nextDue(today, a.dueDay);
        return AccountFacts(
          value: m(-debt),
          corner: next == null ? null : l.accountDueDate(context.day(next)),
          caption: l.accountAvailableOf(m(availableOf(a, balance)), m(limit)),
          progress: limit <= 0 ? null : debt / limit,
        );
      case AccountKind.loan:
        final debt = debtOf(a, balance);
        final total = info?.total ?? a.termMonths ?? 0;
        final monthly = a.monthlyPayment ?? 0;
        final paid = info?.paid ?? 0;
        return AccountFacts(
          value: m(-debt, whole: false),
          corner: info?.next == null ? null : l.accountNextDate(context.day(info!.next!)),
          caption: l.accountLoanProgress(paid, total, m(monthly, whole: false)),
          progress: total <= 0 ? null : paid / total,
        );
    }
  }

  static LocalDate? _nextDue(LocalDate today, int? day) {
    if (day == null) return null;
    final thisMonth = LocalDate(today.year, today.month, day);
    return thisMonth >= today ? thisMonth : thisMonth.addMonths(1);
  }
}

/// Плитка счёта: пастель по `color_key`; кредиты — белые с кромкой (макет).
class AccountTile extends StatelessWidget {
  const AccountTile({
    super.key,
    required this.account,
    required this.facts,
    required this.onTap,
    this.compact = false,
  });

  final Account account;
  final AccountFacts facts;
  final VoidCallback onTap;

  /// Плитка в ряду по две: без угловой подписи и полоски.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final loan = account.kind == AccountKind.loan;
    final fg = loan ? scheme.onSurface : colors.onPastel(account.colorKey);
    final muted = loan ? scheme.onSurfaceVariant : fg;
    return SoftCard(
      key: ValueKey('account-${account.id}'),
      radius: AppRadius.tile,
      color: loan ? null : colors.pastel(account.colorKey),
      borderColor: loan ? null : colors.pastel(account.colorKey),
      padding: const EdgeInsets.fromLTRB(AppSpacing.s18, AppSpacing.s16, AppSpacing.s18, AppSpacing.s16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.rowTitle.copyWith(color: fg),
                ),
              ),
              if (!compact && facts.corner != null) ...[
                const SizedBox(width: AppSpacing.s8),
                Text(facts.corner!, maxLines: 1, softWrap: false, style: text.bodySmall?.copyWith(color: muted)),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AmountText(facts.value, style: text.tileAmount, color: fg),
          ),
          if (facts.caption != null) ...[
            const SizedBox(height: AppSpacing.s6),
            Text(
              facts.caption!,
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: muted),
            ),
          ],
          if (!compact && facts.progress != null) ...[
            const SizedBox(height: AppSpacing.s10),
            ProgressBar(
              value: facts.progress!,
              color: fg,
              track: loan ? scheme.surfaceContainerHigh : fg.withValues(alpha: 0.14),
            ),
          ],
        ],
      ),
    );
  }
}
