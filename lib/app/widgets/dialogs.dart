import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';

/// Диалог подтверждения — только для необратимого (§8.0): удаление счёта,
/// категории, правила, импорт копии, смена базовой валюты.
Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String cancel,
  required String confirm,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;
      return Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.s24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s22, AppSpacing.s24, AppSpacing.s22, AppSpacing.s20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleLarge),
              const SizedBox(height: AppSpacing.s10),
              Text(body, style: text.bodyMedium?.copyWith(height: 1.4, color: scheme.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.s20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(cancel, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: FilledButton(
                      style: destructive
                          ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError)
                          : null,
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(confirm, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}

/// Пункт шторки выбора.
class PickItem<T> {
  const PickItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.iconKey,
    this.colorKey,
    this.trailing,
  });

  final T value;
  final String label;
  final String? subtitle;
  final String? iconKey;
  final String? colorKey;
  final String? trailing;
}

/// Шторка выбора из списка (счёт, валюта, периодичность). Выбранный — с
/// галочкой; тап выбирает и закрывает.
Future<T?> showPickSheet<T>(
  BuildContext context, {
  required String title,
  required List<PickItem<T>> items,
  T? selected,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s24, 0, AppSpacing.s24, AppSpacing.s8),
            child: Text(title, style: text.titleLarge),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: AppSpacing.s24),
              children: [
                for (final item in items)
                  AppRow(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s10),
                    leading: item.iconKey != null
                        ? IconBubble(iconKey: item.iconKey!, colorKey: item.colorKey ?? 'lavender', size: 40)
                        : const SizedBox.shrink(),
                    title: item.label,
                    subtitle: item.subtitle,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.trailing != null)
                          AmountText(item.trailing!, color: scheme.onSurfaceVariant),
                        if (item.value == selected) ...[
                          const SizedBox(width: AppSpacing.s8),
                          Icon(Icons.check_rounded, color: scheme.primary),
                        ],
                      ],
                    ),
                    onTap: () => Navigator.pop(context, item.value),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  },
);

/// Шторка с одним полем ввода текста или суммы и кнопкой.
Future<String?> showInputSheet(
  BuildContext context, {
  required String title,
  required String action,
  String initial = '',
  String? hint,
  bool numeric = false,
  String? Function(String value)? validate,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => _InputSheet(
    title: title,
    action: action,
    initial: initial,
    hint: hint,
    numeric: numeric,
    validate: validate,
  ),
);

class _InputSheet extends StatefulWidget {
  const _InputSheet({
    required this.title,
    required this.action,
    required this.initial,
    required this.hint,
    required this.numeric,
    required this.validate,
  });

  final String title;
  final String action;
  final String initial;
  final String? hint;
  final bool numeric;
  final String? Function(String value)? validate;

  @override
  State<_InputSheet> createState() => _InputSheetState();
}

class _InputSheetState extends State<_InputSheet> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text;
    final error = widget.validate?.call(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s24,
        0,
        AppSpacing.s24,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: text.titleLarge),
          const SizedBox(height: AppSpacing.s16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: widget.numeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: widget.hint, errorText: _error),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.s16),
          FilledButton(onPressed: _submit, child: Text(widget.action)),
        ],
      ),
    );
  }
}
