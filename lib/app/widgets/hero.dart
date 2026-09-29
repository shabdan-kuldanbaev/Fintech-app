import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../format.dart';
import '../theme.dart';

/// Главное число экрана (приём Simbank, spec.md §8.0): подпись сверху,
/// крупная целая часть, мельче дробная и знак валюты, под ним строки
/// «подпись  значение». Число не переносится: не влезает — уменьшается
/// целиком (`FittedBox`), а не ломается посередине.
class HeroAmount extends StatelessWidget {
  const HeroAmount({
    super.key,
    required this.label,
    required this.minor,
    required this.currency,
    this.whole = true,
    this.lines = const [],
    this.negativeIsAlert = false,
    this.caption,
  });

  final String label;
  final int minor;
  final String currency;

  /// Целые единицы (Главная); `false` — с дробной частью (кредит).
  final bool whole;
  final List<(String, String)> lines;
  final bool negativeIsAlert;
  final Widget? caption;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final parts = amountParts(minor, currency, context.lang, whole: whole);
    final color = negativeIsAlert && minor < 0 ? AppColors.of(context).onBlush : scheme.onSurface;
    final unit = text.heroUnit.copyWith(color: scheme.onSurfaceVariant);
    final number = text.heroAmount.copyWith(color: color);
    final minus = parts.negative ? '−' : '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: AppSpacing.s6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: [
                if (parts.signBefore) TextSpan(text: '$minus${parts.sign}', style: number),
                TextSpan(text: parts.signBefore ? parts.whole : '$minus${parts.whole}', style: number),
                if (parts.fraction.isNotEmpty) TextSpan(text: parts.fraction, style: unit.copyWith(color: color)),
                if (!parts.signBefore && parts.sign.isNotEmpty) TextSpan(text: ' ${parts.sign}', style: unit),
              ],
            ),
            maxLines: 1,
            softWrap: false,
          ),
        ),
        if (caption != null) ...[const SizedBox(height: AppSpacing.s4), caption!],
        if (lines.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.s20,
            runSpacing: AppSpacing.s4,
            children: [
              for (final (k, v) in lines)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$k  ', style: TextStyle(color: scheme.onSurfaceVariant)),
                      TextSpan(text: v),
                    ],
                  ),
                  maxLines: 1,
                  softWrap: false,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
