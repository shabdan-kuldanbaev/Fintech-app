import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/format.dart';
import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/toast.dart';
import '../../../core/currencies.dart';
import '../../accounts/domain/account.dart';
import '../../categories/domain/category.dart';
import '../domain/frequent.dart';
import '../domain/transaction.dart';

/// Записать операцию и показать тост «Saved · … · Undo · Edit» (§8.3).
///
/// [context] — любой контекст экрана; тост и переход «Edit» идут через
/// корневой навигатор, поэтому экран можно закрыть сразу после вызова
/// ([closeScreen]).
Future<bool> saveWithToast(
  BuildContext context,
  WidgetRef ref,
  TxnInput input, {
  required String label,
  bool closeScreen = false,
}) async {
  final l = context.l10n;
  // Всё, что понадобится после закрытия экрана, берётся до `await`.
  final overlay = Navigator.of(context, rootNavigator: true).overlay;
  final router = GoRouter.of(context);
  final repo = ref.read(transactionRepositoryProvider);
  try {
    final id = await repo.create(input);
    if (closeScreen && context.mounted) context.closeScreen();
    if (overlay == null) return true;
    showActionToastOn(
      overlay,
      l.savedToast(label),
      actions: [
        ToastAction(l.edit, () => unawaited(router.push(Routes.txn(id)))),
        ToastAction(l.undo, () => unawaited(repo.delete(id)), primary: true),
      ],
    );
    return true;
  } on MissingRate catch (e) {
    if (overlay != null) {
      showActionToastOn(overlay, l.addMissingRate(e.currency), icon: Icons.info_outline_rounded);
    }
    return false;
  }
}

/// Подпись операции для чипа и тоста: заметка, иначе категория, иначе
/// «откуда → куда»; сумма без дробной части, если она нулевая.
String quickLabel(
  BuildContext context, {
  required TxKind kind,
  required int amount,
  required String currency,
  String? note,
  Category? category,
  Account? from,
  Account? to,
  bool withCurrency = false,
}) {
  final n = note?.trim();
  final title = n != null && n.isNotEmpty
      ? n
      : kind == TxKind.transfer
      ? '${from?.name ?? ''} → ${to?.name ?? ''}'
      : category == null
      ? ''
      : categoryName(context.l10n, category);
  final whole = amount % _pow10(minorUnits(currency)) == 0;
  final sum = context.money(amount, currency, whole: whole, symbol: withCurrency);
  return withCurrency ? '$title $sum' : '$title · $sum';
}

int _pow10(int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}

/// Лента чипов «Quick add» (§9.8): тап записывает операцию сразу.
/// Уходит под боковые поля до края экрана (§8.0). Пусто — ничего.
class QuickAddRow extends ConsumerWidget {
  const QuickAddRow({
    super.key,
    required this.kinds,
    this.label,
    this.closesScreen = false,
  });

  final Set<TxKind> kinds;
  final String? label;

  /// Чип на экране ввода: после записи экран закрывается.
  final bool closesScreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns = ref.watch(recentTxnsProvider).value;
    final cats = ref.watch(categoryMapProvider).value;
    final accounts = ref.watch(accountMapProvider).value;
    if (txns == null || cats == null || accounts == null) {
      return const SizedBox.shrink();
    }
    final today = ref.watch(todayProvider);
    final excluded = {
      for (final c in cats.values)
        if (c.isSystem) c.id,
    };
    final items = frequentOps(
      txns,
      today: today,
      excludedCategoryIds: excluded,
      kinds: kinds,
    ).where((q) => accounts[q.accountId] != null).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) GroupLabel(label!),
        EdgeToEdgeRow(
          children: [
            for (final q in items)
              _chip(context, ref, q, cats, accounts),
          ],
        ),
      ],
    );
  }

  Widget _chip(
    BuildContext context,
    WidgetRef ref,
    QuickAdd q,
    Map<String, Category> cats,
    Map<String, Account> accounts,
  ) {
    final account = accounts[q.accountId]!;
    final cat = cats[q.categoryId];
    final to = accounts[q.counterAccountId];
    final text = quickLabel(
      context,
      kind: q.kind,
      amount: q.amount,
      currency: account.currency,
      note: q.note,
      category: cat,
      from: account,
      to: to,
    );
    return AppChip(
      key: ValueKey('quick-${q.kind.db}-${q.categoryId ?? q.counterAccountId}-${q.amount}-${q.note}'),
      label: text,
      iconKey: q.kind == TxKind.transfer ? 'transfer' : cat?.iconKey ?? 'other',
      colorKey: q.kind == TxKind.transfer ? 'sky' : cat?.colorKey ?? 'lavender',
      onTap: () async {
        await saveWithToast(
          context,
          ref,
          q.toInput(ref.read(todayProvider)),
          label: quickLabel(
            context,
            kind: q.kind,
            amount: q.amount,
            currency: account.currency,
            note: q.note,
            category: cat,
            from: account,
            to: to,
            withCurrency: true,
          ),
          closeScreen: closesScreen,
        );
      },
    );
  }
}
