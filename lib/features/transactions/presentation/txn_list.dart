import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/format.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../core/calendar.dart';
import '../../accounts/domain/account.dart';
import '../../categories/domain/category.dart';
import '../domain/transaction.dart';

/// Как показать операцию в ленте: иконка, название, подпись, сумма.
class TxnView {
  const TxnView({
    required this.iconKey,
    required this.colorKey,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.amountColor,
  });

  final String iconKey;
  final String colorKey;
  final String title;
  final String subtitle;
  final String amount;
  final Color? amountColor;

  /// [scope] — лента одного счёта: переводы получают знак относительно него.
  static TxnView of(
    BuildContext context,
    Txn t, {
    required Map<String, Category> categories,
    required Map<String, Account> accounts,
    String? scope,
  }) {
    final l = context.l10n;
    final colors = AppColors.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final account = accounts[t.accountId];
    final accountName = account?.name ?? '';
    switch (t.kind) {
      case TxKind.transfer:
        final to = accounts[t.counterAccountId];
        final incoming = scope != null && scope == t.counterAccountId;
        final amount = incoming
            ? context.money(t.counterAmount ?? t.amount, to?.currency ?? t.currency, symbol: false, plus: true)
            : scope != null
            ? context.money(-t.amount, t.currency, symbol: false)
            : context.money(t.amount, t.currency, symbol: false);
        final note = t.note?.trim();
        return TxnView(
          iconKey: 'transfer',
          colorKey: 'sky',
          title: note == null || note.isEmpty ? '$accountName → ${to?.name ?? ''}' : note,
          // Без заметки название уже «откуда → куда»: подпись не повторяет его.
          subtitle: note == null || note.isEmpty
              ? l.kindTransfer
              : '${l.kindTransfer} · $accountName → ${to?.name ?? ''}',
          amount: amount,
          amountColor: incoming ? colors.onMint : (scope == null ? muted : null),
        );
      case TxKind.expense:
      case TxKind.income:
        final cat = categories[t.categoryId];
        final catName = cat == null ? '' : categoryName(l, cat);
        final note = t.note?.trim();
        final income = t.kind == TxKind.income;
        return TxnView(
          iconKey: cat?.iconKey ?? 'other',
          colorKey: cat?.colorKey ?? 'lavender',
          title: note == null || note.isEmpty ? catName : note,
          subtitle: note == null || note.isEmpty ? accountName : '$catName · $accountName',
          amount: context.money(income ? t.amount : (scope != null ? -t.amount : t.amount), t.currency, symbol: false, plus: income),
          amountColor: income ? colors.onMint : null,
        );
    }
  }
}

/// Строка операции; тап — экран операции.
class TxnRow extends StatelessWidget {
  const TxnRow({
    super.key,
    required this.txn,
    required this.categories,
    required this.accounts,
    this.scope,
  });

  final Txn txn;
  final Map<String, Category> categories;
  final Map<String, Account> accounts;
  final String? scope;

  @override
  Widget build(BuildContext context) {
    final v = TxnView.of(context, txn, categories: categories, accounts: accounts, scope: scope);
    return AppRow(
      key: ValueKey('txn-${txn.id}'),
      leading: IconBubble(iconKey: v.iconKey, colorKey: v.colorKey),
      title: v.title,
      subtitle: v.subtitle,
      trailing: AmountText(v.amount, color: v.amountColor),
      onTap: () => context.push(Routes.txn(txn.id)),
    );
  }
}

/// Операции, сгруппированные по дням: подпись дня капителью с суммой
/// расходов дня, под ней карточка строк (макет «Home», «Recent»).
class TxnDayList extends StatelessWidget {
  const TxnDayList({
    super.key,
    required this.txns,
    required this.categories,
    required this.accounts,
    required this.today,
    required this.baseCurrency,
    this.scope,
    this.excludeFromDayTotal = const {},
  });

  final List<Txn> txns;
  final Map<String, Category> categories;
  final Map<String, Account> accounts;
  final LocalDate today;
  final String baseCurrency;
  final String? scope;

  /// Категории, которые не входят в итог дня (корректировка).
  final Set<String> excludeFromDayTotal;

  @override
  Widget build(BuildContext context) {
    final days = <LocalDate, List<Txn>>{};
    for (final t in txns) {
      (days[t.date] ??= []).add(t);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in days.entries) ...[
          GroupLabel(_dayTitle(context, entry.key, entry.value)),
          RowsCard(
            children: [
              for (final t in entry.value)
                TxnRow(txn: t, categories: categories, accounts: accounts, scope: scope),
            ],
          ),
        ],
      ],
    );
  }

  String _dayTitle(BuildContext context, LocalDate day, List<Txn> list) {
    final label = context.relativeDay(day, today);
    var spent = 0;
    for (final t in list) {
      if (t.kind == TxKind.expense && !excludeFromDayTotal.contains(t.categoryId)) {
        spent += t.baseAmount;
      }
    }
    if (spent == 0) return label;
    return '$label · ${context.money(spent, baseCurrency, whole: true)}';
  }
}
