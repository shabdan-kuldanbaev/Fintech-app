import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'format.dart';
import 'providers.dart';
import 'router.dart';
import 'theme.dart';
import 'widgets/glass.dart';

/// Оболочка вкладок Home / Payments / Accounts (spec.md §8.2): одна
/// стеклянная панель на все, справа — графитовая «+» (ввод расхода одним
/// касанием). Высота панели уходит телу через `MediaQuery.padding.bottom`.
class TabShell extends ConsumerStatefulWidget {
  const TabShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  /// Отступ панели от боков и от нижнего края экрана — один и тот же.
  static const double barInset = AppSpacing.s16;

  @override
  ConsumerState<TabShell> createState() => _TabShellState();
}

class _TabShellState extends ConsumerState<TabShell> {
  double _barHeight = 0;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Вернулись из фона — дата могла смениться: «сегодня» пересчитывается,
    // а за ним и всё, что от него зависит (§5.2).
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(todayProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onBarHeight(double height) {
    if (!mounted || (height - _barHeight).abs() < 0.5) return;
    setState(() => _barHeight = height);
  }

  void _selectTab(int index) => widget.shell.goBranch(
    index,
    initialLocation: index == widget.shell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final l = context.l10n;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MediaQuery(
              data: mq.copyWith(
                padding: mq.padding.copyWith(bottom: math.max(mq.padding.bottom, _barHeight)),
              ),
              child: widget.shell,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MeasuredHeight(
              onHeight: _onBarHeight,
              child: SafeArea(
                top: false,
                bottom: false,
                minimum: const EdgeInsets.fromLTRB(
                  TabShell.barInset,
                  0,
                  TabShell.barInset,
                  TabShell.barInset,
                ),
                child: GlassNavBar(
                  tabs: [
                    NavTabItem(icon: Icons.home_rounded, label: l.tabHome),
                    NavTabItem(icon: Icons.calendar_month_rounded, label: l.tabPayments),
                    NavTabItem(icon: Icons.account_balance_wallet_rounded, label: l.tabAccounts),
                  ],
                  active: widget.shell.currentIndex,
                  onTab: _selectTab,
                  actionTooltip: l.actionAddExpense,
                  onAction: () => unawaited(context.push(Routes.newTxn())),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
