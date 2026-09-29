import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/format.dart';
import '../../../app/theme.dart';
import '../../../core/currencies.dart';

/// Крупная сумма с курсором и знаком валюты; системная цифровая клавиатура
/// открыта сразу (решение заказчика 2026-09-29).
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.currency,
    required this.onChanged,
    this.error,
    this.autofocus = true,
    this.large = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String currency;
  final VoidCallback onChanged;
  final String? error;
  final bool autofocus;

  /// Экран «Add» — 56 pt; карточка наступления и правка — 48 pt.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 120),
              child: IntrinsicWidth(
                child: TextField(
                  key: const ValueKey('amount-field'),
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: autofocus,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]'))],
                  style: (large ? text.amountInput : text.amountInputSmall).copyWith(color: error != null ? colors.onBlush : scheme.onSurface),
                  cursorColor: colors.onLavender,
                  // Без рамки и заливки поля из темы: сумма — это текст.
                  decoration: InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: '0',
                    hintStyle: (large ? text.amountInput : text.amountInputSmall).copyWith(color: scheme.outline),
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              currencyInfo(currency).sign(context.lang),
              style: text.heroUnit.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 150),
          child: error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s4),
                  child: Text(error!, style: text.bodySmall?.copyWith(color: colors.onBlush)),
                ),
        ),
      ],
    );
  }
}

