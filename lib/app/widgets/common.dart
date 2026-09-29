import 'package:flutter/material.dart';

import '../../core/icons.dart';
import '../theme.dart';

/// Белая карточка с тонкой кромкой (Jattap): тень только у стекла.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.s16),
    this.radius = AppRadius.card,
    this.color,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(radius);
    final content = Padding(padding: padding, child: child);
    return Container(
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerLowest,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      // Свой прозрачный Material: иначе отклик нажатия строк внутри
      // (ListTile, InkWell) рисуется под заливкой карточки и не виден.
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null
            ? content
            : InkWell(onTap: onTap, borderRadius: borderRadius, child: content),
      ),
    );
  }
}

/// Круглая пастельная подложка с иконкой (категория, счёт, правило).
class IconBubble extends StatelessWidget {
  const IconBubble({
    super.key,
    required this.iconKey,
    required this.colorKey,
    this.size = 44,
  });

  final String iconKey;
  final String colorKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.pastel(colorKey),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        iconFor(iconKey),
        size: size * 0.46,
        color: colors.onPastel(colorKey),
      ),
    );
  }
}

/// Сумма: одна строка, без переноса и сжатия (spec.md §8.0).
class AmountText extends StatelessWidget {
  const AmountText(this.text, {super.key, this.style, this.color});

  final String text;
  final TextStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.rowAmount;
    return Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      style: base.copyWith(
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Строка списка: иконка, название и подпись (обрезаются), справа — сумма
/// или кнопка (не сжимаются, §8.0).
class AppRow extends StatelessWidget {
  const AppRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.s16,
      vertical: AppSpacing.s10,
    ),
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.rowTitle,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.rowSubtitle.copyWith(color: subtitleColor),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.s10),
            trailing!,
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// Заголовок секции: «Upcoming» слева, действие справа.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s4, 0, AppSpacing.s4, AppSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: text.sectionTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (action != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
                child: Text(
                  action!,
                  maxLines: 1,
                  softWrap: false,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Подпись капителью над группой: «TODAY · 34,00 SOM».
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key, this.color, this.padding});

  final String text;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding:
        padding ??
        const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s14, AppSpacing.s16, AppSpacing.s6),
    child: Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.groupLabel.copyWith(color: color),
    ),
  );
}

enum PillTone { primary, alert, soft }

/// Кнопка-пилюля в строке: «Pay 2 584,31», «Enter amount». Не сжимается.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = PillTone.primary,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillTone tone;

  /// Значок перед подписью: узкая строка показывает «✓ 2 584,31» вместо
  /// «Оплатить 2 584,31».
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors.of(context);
    final (bg, fg) = switch (tone) {
      PillTone.primary => (scheme.primary, scheme.onPrimary),
      PillTone.alert => (colors.blush, colors.onBlush),
      PillTone.soft => (scheme.surfaceContainerHigh, scheme.onSurface),
    };
    return Material(
      color: bg,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14),
            child: Center(
              widthFactor: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: AppSpacing.s4)],
                  Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: Theme.of(context).textTheme.chipLabel.copyWith(
                      color: fg,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Чип: белая пилюля с кромкой, необязательная иконка слева.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.onTap,
    this.iconKey,
    this.colorKey,
    this.icon,
    this.trailingIcon,
    this.selected = false,
    this.dense = false,
    this.muted = false,
  });

  final String label;
  final VoidCallback? onTap;
  final String? iconKey;
  final String? colorKey;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool selected;
  final bool dense;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final height = dense ? 34.0 : 40.0;
    final fg = selected
        ? scheme.onPrimary
        : muted
        ? scheme.onSurfaceVariant
        : scheme.onSurface;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerLowest,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: EdgeInsets.only(
              left: iconKey != null ? AppSpacing.s6 : AppSpacing.s14,
              right: AppSpacing.s14,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iconKey != null) ...[
                  IconBubble(iconKey: iconKey!, colorKey: colorKey ?? 'lavender', size: height - 12),
                  const SizedBox(width: AppSpacing.s8),
                ] else if (icon != null) ...[
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: AppSpacing.s6),
                ],
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: (dense ? text.chipLabel : text.bodyMedium!.copyWith(fontWeight: FontWeight.w500))
                      .copyWith(color: fg),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: AppSpacing.s4),
                  Icon(trailingIcon, size: 16, color: scheme.onSurfaceVariant),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Сегмент из 2–3 пунктов (Expense / Income / Transfer). Подписи не
/// переносятся: не хватает места — сегмент уменьшается целиком (§8.0);
/// [expand] — во всю ширину, пункты поровну.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.expand = false,
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget item(int i) => Semantics(
      selected: values[i] == selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(values[i]),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: expand ? AppSpacing.s8 : AppSpacing.s16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: values[i] == selected ? scheme.primary : null,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              labels[i],
              maxLines: 1,
              softWrap: false,
              style: text.labelLarge?.copyWith(
                color: values[i] == selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
    final box = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < values.length; i++) expand ? Expanded(child: item(i)) : item(i),
        ],
      ),
    );
    return expand ? box : FittedBox(fit: BoxFit.scaleDown, child: box);
  }
}

/// Полоска прогресса: копилка, лимит, график кредита, бюджет.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.track,
    this.height = 8,
  });

  final double value;
  final Color color;
  final Color? track;
  final double height;

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    // Дорожка — во всю ширину, заливка — доля от неё. Пустой ColoredBox
    // имеет нулевой размер, поэтому оба слоя — DecoratedBox под жёсткими
    // ограничениями (кадр accounts-*, 2026-09-29: заливки не было).
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(color: track ?? color.withValues(alpha: 0.16)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Круглая графитовая кнопка с подписью под ней (ряд действий, §8.0).
class RoundAction extends StatelessWidget {
  const RoundAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: primary ? scheme.primary : scheme.surfaceContainerHigh,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox.square(
                dimension: 56,
                child: Icon(
                  icon,
                  size: 24,
                  color: primary ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.navLabel,
          ),
        ],
      ),
    );
  }
}

/// Пустое состояние: заголовок, пояснение, кнопка.
class EmptyCard extends StatelessWidget {
  const EmptyCard({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    this.iconKey = 'wallet',
  });

  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  final String iconKey;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s24, AppSpacing.s20, AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBubble(iconKey: iconKey, colorKey: 'lavender', size: 52),
          const SizedBox(height: AppSpacing.s16),
          Text(title, style: text.titleLarge),
          const SizedBox(height: AppSpacing.s6),
          Text(body, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.s20),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}

/// Карточка со строками, разделёнными воздухом (не линиями).
class RowsCard extends StatelessWidget {
  const RowsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SoftCard(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );
}

/// Горизонтальная лента, уходящая под боковые поля до края экрана (§8.0):
/// [sidePadding] — поле страницы, с которого начинается первый элемент.
class EdgeToEdgeRow extends StatelessWidget {
  const EdgeToEdgeRow({
    super.key,
    required this.children,
    this.sidePadding = AppSpacing.s16,
    this.gap = AppSpacing.s8,
    this.height = 40,
  });

  final List<Widget> children;
  final double sidePadding;
  final double gap;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: sidePadding),
      itemCount: children.length,
      separatorBuilder: (_, _) => SizedBox(width: gap),
      itemBuilder: (_, i) => children[i],
    ),
  );
}

/// Строка формы: подпись слева, значение справа, шеврон (§8.3 «Transaction»).
/// Подпись и значение не влезают в строку («Следующее списание» на 320 pt) —
/// значение уходит под подпись, а не обрезается до «3…».
class ValueRow extends StatelessWidget {
  const ValueRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.valueColor,
    this.leading,
    this.trailing,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? valueColor;
  final Widget? leading;
  final Widget? trailing;

  static const double _gap = AppSpacing.s12;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant);
    final valueStyle = text.bodyLarge?.copyWith(fontWeight: FontWeight.w500, color: valueColor);
    final Widget? end = trailing != null
        ? Padding(padding: const EdgeInsets.only(left: AppSpacing.s8), child: trailing)
        : onTap != null
        ? Padding(
            padding: const EdgeInsets.only(left: AppSpacing.s4),
            child: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant, size: 20),
          )
        : null;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s18, vertical: AppSpacing.s10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scaler = MediaQuery.textScalerOf(context);
              double width(String s, TextStyle? style) {
                final painter = TextPainter(
                  text: TextSpan(text: s, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: scaler,
                  maxLines: 1,
                )..layout();
                final w = painter.width;
                painter.dispose();
                return w;
              }
              final extras = (leading == null ? 0 : 44) + (end == null ? 0 : 28);
              final fits = value.isEmpty ||
                  width(label, labelStyle) + _gap + width(value, valueStyle) + extras <= constraints.maxWidth;
              if (fits) {
                return Row(
                  children: [
                    if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.s12)],
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: (constraints.maxWidth - extras) * 0.75),
                      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle),
                    ),
                    const SizedBox(width: _gap),
                    Expanded(
                      child: Text(
                        value,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: valueStyle,
                      ),
                    ),
                    ?end,
                  ],
                );
              }
              return Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.s12)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                        const SizedBox(height: AppSpacing.s2),
                        Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: valueStyle),
                      ],
                    ),
                  ),
                  ?end,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Тонкий разделитель внутри карточки строк формы.
class RowDivider extends StatelessWidget {
  const RowDivider({super.key});

  @override
  Widget build(BuildContext context) => const Divider(height: 1, indent: AppSpacing.s18, endIndent: AppSpacing.s18);
}
