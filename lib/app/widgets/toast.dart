import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Действие тоста: «Undo», «Edit».
class ToastAction {
  const ToastAction(this.label, this.onTap, {this.primary = false});
  final String label;
  final VoidCallback onTap;

  /// Белая кнопка (главное действие, обычно «Undo»).
  final bool primary;
}

/// Тост у нижнего края над панелью вкладок (макет «Home · saved»): графитовая
/// капсула с галочкой, текстом и действиями. Живёт [duration]; новый тост
/// заменяет текущий. Обратимые действия подтверждаются так, а не диалогом
/// (spec.md §8.0).
void showActionToast(
  BuildContext context,
  String text, {
  List<ToastAction> actions = const [],
  Duration duration = const Duration(seconds: 4),
  IconData icon = Icons.check_rounded,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  showActionToastOn(overlay, text, actions: actions, duration: duration, icon: icon);
}

/// То же на готовом оверлее — когда экран, из которого пришло действие,
/// уже закрыт: его контекст больше не годится, а корневой оверлей жив.
/// Контекст навигатора для этого не подходит: оверлей у навигатора —
/// дочерний, и `Overlay.of` от контекста навигатора его не находит.
void showActionToastOn(
  OverlayState overlay,
  String text, {
  List<ToastAction> actions = const [],
  Duration duration = const Duration(seconds: 4),
  IconData icon = Icons.check_rounded,
}) {
  if (!overlay.mounted) return;
  ActionToast.dismiss();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ToastView(
      text: text,
      icon: icon,
      actions: actions,
      duration: duration,
      onDone: () {
        if (identical(ActionToast._current, entry)) ActionToast._current = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  ActionToast._current = entry;
  overlay.insert(entry);
}

abstract final class ActionToast {
  static const Key capsuleKey = ValueKey('action-toast');
  static OverlayEntry? _current;

  /// Отступ снизу: над панелью вкладок (16 + 64) и её полем.
  static const double bottom = 104;

  static void dismiss() {
    final e = _current;
    _current = null;
    if (e != null && e.mounted) e.remove();
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.text,
    required this.icon,
    required this.actions,
    required this.duration,
    required this.onDone,
  });

  final String text;
  final IconData icon;
  final List<ToastAction> actions;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _hide);
  }

  Future<void> _hide() async {
    _timer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final colors = AppColors.of(context);
    return Positioned(
      left: AppSpacing.s16,
      right: AppSpacing.s16,
      bottom: ActionToast.bottom + MediaQuery.viewInsetsOf(context).bottom,
      child: FadeTransition(
        opacity: _controller,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.4), end: Offset.zero)
              .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)),
          child: Material(
            key: ActionToast.capsuleKey,
            color: scheme.primary,
            shape: const StadiumBorder(),
            elevation: 0,
            shadowColor: colors.shadowStrong,
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.only(left: AppSpacing.s18, right: AppSpacing.s8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: AppShadows.glass(colors),
              ),
              child: Row(
                children: [
                  Icon(widget.icon, size: 20, color: scheme.onPrimary),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Text(
                      widget.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.toast.copyWith(color: scheme.onPrimary),
                    ),
                  ),
                  for (final a in widget.actions)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.s4),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14),
                          backgroundColor: a.primary ? scheme.onPrimary : null,
                          foregroundColor: a.primary ? scheme.primary : scheme.onPrimary,
                        ),
                        onPressed: () {
                          a.onTap();
                          unawaited(_hide());
                        },
                        child: Text(a.label, maxLines: 1, softWrap: false),
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
