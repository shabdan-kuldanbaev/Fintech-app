import 'package:flutter/material.dart';

import '../../../app/format.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/dialogs.dart';
import '../../../core/currencies.dart';
import '../../../core/icons.dart';

IconData appIconOf(String key) => iconFor(key);

/// Пять пастелей кругами; выбранная — с кольцом графита.
class ColorRow extends StatelessWidget {
  const ColorRow({super.key, required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final key in AppColors.pastelKeys)
          Semantics(
            button: true,
            selected: key == selected,
            label: key,
            child: GestureDetector(
              onTap: () => onChanged(key),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.pastel(key),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: key == selected ? scheme.primary : colors.pastel(key),
                    width: 2.5,
                  ),
                ),
                child: key == selected ? Icon(Icons.check_rounded, color: colors.onPastel(key), size: 20) : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// Сетка иконок в шторке.
Future<String?> pickIcon(
  BuildContext context, {
  required String title,
  required String colorKey,
  String? selected,
}) => showModalBottomSheet<String>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.s16, 0, AppSpacing.s16, AppSpacing.s24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.s8, bottom: AppSpacing.s12),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        Flexible(
          child: GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            mainAxisSpacing: AppSpacing.s8,
            crossAxisSpacing: AppSpacing.s8,
            children: [
              for (final key in pickableIconKeys)
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(context, key),
                  child: Container(
                    decoration: key == selected
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                          )
                        : null,
                    padding: const EdgeInsets.all(2),
                    child: IconBubble(iconKey: key, colorKey: colorKey),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  ),
);

/// Валюта из справочника: код, имя на языке приложения.
Future<String?> pickCurrency(BuildContext context, {String? selected}) {
  final lang = context.lang;
  return showPickSheet<String>(
    context,
    title: context.l10n.fieldCurrency,
    selected: selected,
    items: [
      for (final c in currencies) PickItem(value: c.code, label: c.code, subtitle: c.name(lang), trailing: c.sign(lang)),
    ],
  );
}

/// День месяца 1..28 (платёж по кредитной линии, начало расчётного месяца).
Future<int?> pickDayOfMonth(BuildContext context, {required String title, int? selected, int max = 28}) =>
    showPickSheet<int>(
      context,
      title: title,
      selected: selected,
      items: [for (var d = 1; d <= max; d++) PickItem(value: d, label: context.l10n.dayOfMonth(d))],
    );
