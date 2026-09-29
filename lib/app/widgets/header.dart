import 'package:flutter/material.dart';

import '../theme.dart';
import 'glass.dart';

/// Прозрачная шапка (Jattap): круглые стеклянные кнопки по бокам, заголовок
/// по центру. Лежит поверх тела [GlassScaffold]; контент уезжает под неё.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.trailing,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s8),
        child: Row(
          children: [
            leading ?? const SizedBox(width: AppSizes.iconButton),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                child: Center(
                  child: titleWidget ??
                      (title == null
                          ? const SizedBox.shrink()
                          : Text(
                              title!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.screenTitle,
                            )),
                ),
              ),
            ),
            trailing ?? const SizedBox(width: AppSizes.iconButton),
          ],
        ),
      ),
    );
  }
}

/// Кнопка «назад» / «закрыть» для шапки.
class HeaderBack extends StatelessWidget {
  const HeaderBack({super.key, required this.tooltip, this.close = false, this.onPressed});

  final String tooltip;
  final bool close;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => GlassIconButton(
    icon: close ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
    tooltip: tooltip,
    onPressed: onPressed ?? () => Navigator.maybePop(context),
  );
}
