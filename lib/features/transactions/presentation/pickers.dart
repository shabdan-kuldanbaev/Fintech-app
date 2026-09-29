import 'package:flutter/material.dart';

import '../../../app/format.dart';
import '../../../app/widgets/dialogs.dart';
import '../../../core/calendar.dart';
import '../../accounts/domain/account.dart';
import '../../categories/domain/category.dart';

/// Выбор счёта шторкой; возвращает id.
Future<String?> pickAccount(
  BuildContext context,
  List<Account> accounts, {
  required String title,
  String? selected,
}) => showPickSheet<String>(
  context,
  title: title,
  selected: selected,
  items: [
    for (final a in accounts)
      PickItem(
        value: a.id,
        label: a.name,
        subtitle: '${accountKindName(context.l10n, a.kind)} · ${a.currency}',
        iconKey: a.iconKey,
        colorKey: a.colorKey,
      ),
  ],
);

/// Выбор категории шторкой.
Future<Category?> pickCategory(
  BuildContext context,
  List<Category> categories, {
  required String title,
  String? selected,
}) async {
  final id = await showPickSheet<String>(
    context,
    title: title,
    selected: selected,
    items: [
      for (final c in categories)
        PickItem(
          value: c.id,
          label: categoryName(context.l10n, c),
          iconKey: c.iconKey,
          colorKey: c.colorKey,
        ),
    ],
  );
  return id == null ? null : categories.firstWhere((c) => c.id == id);
}

/// Выбор даты системным календарём Material в языке приложения.
Future<LocalDate?> pickDate(
  BuildContext context,
  LocalDate initial, {
  LocalDate? first,
  LocalDate? last,
}) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: initial.toLocalDateTime(),
    firstDate: (first ?? const LocalDate(2000, 1, 1)).toLocalDateTime(),
    lastDate: (last ?? LocalDate(initial.year + 30, 12, 31)).toLocalDateTime(),
  );
  return picked == null ? null : LocalDate.of(picked);
}
