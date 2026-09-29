import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';

import '../theme.dart';

/// «Стекло» (docs/ui_redesign.md §10): размытие того, что под панелью,
/// полупрозрачная заливка, светлая кромка и блик сверху.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = AppRadius.pill,
    this.padding = EdgeInsets.zero,
    this.blur = 22,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double blur;

  /// Верхний упор градиента: блик — это подсветка ПОВЕРХ заливки, а не дырка
  /// в ней.
  ///
  /// В светлой теме блик плотнее заливки (0xE6 против 0x85), и градиент можно
  /// вести прямо от него: верх панели получается матовее низа, как и задумано.
  /// В тёмной теме блик, наоборот, прозрачнее заливки (0x22 против 0x8A) —
  /// взятый напрямую, он оставлял в верхней трети каждой стеклянной панели
  /// почти сквозную полосу: контент, уезжающий под панель, проступал сквозь
  /// её верх и обрывался на 35 % высоты. Поэтому там блик кладётся на
  /// заливку, и панель остаётся непрозрачной, сохраняя светлую кромку сверху.
  static Color _highlight(AppColors colors) =>
      colors.glassHighlight.a >= colors.glass.a
      ? colors.glassHighlight
      : Color.alphaBlend(colors.glassHighlight, colors.glass);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final borderRadius = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: AppShadows.glass(colors),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: colors.glass,
              borderRadius: borderRadius,
              border: Border.all(color: colors.glassBorder),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_highlight(colors), colors.glass],
                stops: const [0, 0.35],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Содержимое стеклянной панели: главная кнопка и необязательная вторая
/// (текстовая или контурная).
class ActionBar extends StatelessWidget {
  const ActionBar({
    super.key,
    required this.primary,
    required this.onPrimary,
    this.secondary,
    this.onSecondary,
    this.secondaryOutlined = false,
    this.secondaryDestructive = false,
  });

  final String primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;
  final bool secondaryOutlined;

  /// Текстовая вторая кнопка в цвете ошибки («Delete set»).
  final bool secondaryDestructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton(onPressed: onPrimary, child: Text(primary)),
        if (secondary != null) ...[
          SizedBox(height: secondaryOutlined ? 10 : 2),
          if (secondaryOutlined)
            OutlinedButton(onPressed: onSecondary, child: Text(secondary!))
          else
            TextButton(
              onPressed: onSecondary,
              style: secondaryDestructive
                  ? TextButton.styleFrom(foregroundColor: scheme.error)
                  : null,
              child: Text(secondary!),
            ),
        ],
      ],
    );
  }
}

/// Вкладка панели: иконка и подпись.
class NavTabItem {
  const NavTabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Панель вкладок (spec.md §8.2, макет «Home»): слева стеклянная капсула с
/// вкладками, справа отдельная стеклянная капсула с графитовой кнопкой «+»
/// — ввод расхода одним касанием, без меню. Выделение активной вкладки —
/// мягкая пилюля, которая «перетекает» между вкладками: передний край бежит
/// вперёд, задний догоняет.
///
/// Перенесена из Jattap. Встроенных системных вью (`UITabBar` через
/// `UiKitView`) нет и быть не должно (I16, flutter/flutter#182662).
class GlassNavBar extends StatefulWidget {
  const GlassNavBar({
    super.key,
    required this.tabs,
    required this.active,
    required this.onTab,
    required this.onAction,
    required this.actionTooltip,
  });

  final List<NavTabItem> tabs;
  final int active;
  final ValueChanged<int> onTab;
  final VoidCallback onAction;
  final String actionTooltip;

  /// Наибольшая ширина вкладки; на узком экране она меньше — [tabWidthFor].
  static const double tabWidth = 84;
  static const double tabHeight = 54;
  static const double tabGap = 4;

  /// Поле капсулы вокруг вкладок.
  static const double inset = 5;

  /// Наименьший зазор между капсулой вкладок и капсулой действия.
  static const double groupGap = 12;

  /// Ширина вкладки при доступной ширине [available] и [count] вкладках;
  /// капсула действия — круг высотой вкладки.
  static double tabWidthFor(double available, int count) {
    if (!available.isFinite) return tabWidth;
    final fit =
        (available -
            (count - 1) * tabGap -
            4 * inset -
            groupGap -
            tabHeight) /
        count;
    return fit.clamp(0.0, tabWidth).toDouble();
  }

  @override
  State<GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<GlassNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    value: 1,
  );
  late int _from = widget.active;

  @override
  void didUpdateWidget(GlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _from = oldWidget.active;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _bar(
      context,
      GlassNavBar.tabWidthFor(constraints.maxWidth, widget.tabs.length),
    ),
  );

  Widget _bar(BuildContext context, double width) {
    final scheme = Theme.of(context).colorScheme;
    const height = GlassNavBar.tabHeight;
    final tabs = widget.tabs.length;
    final groupWidth = width * tabs + GlassNavBar.tabGap * (tabs - 1);
    const radius = (height + GlassNavBar.inset * 2) / 2;
    double leftOf(int tab) => tab * (width + GlassNavBar.tabGap);

    Widget tab(int index) {
      final item = widget.tabs[index];
      return Positioned(
        left: leftOf(index),
        top: 0,
        width: width,
        height: height,
        child: Tooltip(
          message: item.label,
          child: Semantics(
            selected: widget.active == index,
            child: _NavItem(
              icon: item.icon,
              label: item.label,
              labelInSemantics: false,
              onTap: () => widget.onTab(index),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        GlassPanel(
          radius: radius,
          padding: const EdgeInsets.all(GlassNavBar.inset),
          child: SizedBox(
            width: groupWidth,
            height: height,
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final v = _controller.value;
                    final fromLeft = leftOf(_from);
                    final toLeft = leftOf(widget.active);
                    final front = Curves.easeOutCubic.transform(v);
                    final back = Curves.easeInCubic.transform(v);
                    final double left;
                    final double right;
                    if (toLeft >= fromLeft) {
                      left = lerpDouble(fromLeft, toLeft, back)!;
                      right = lerpDouble(fromLeft + width, toLeft + width, front)!;
                    } else {
                      left = lerpDouble(fromLeft, toLeft, front)!;
                      right = lerpDouble(fromLeft + width, toLeft + width, back)!;
                    }
                    return Positioned(
                      key: const ValueKey('nav-indicator'),
                      left: left,
                      top: 0,
                      width: right - left,
                      height: height,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(height / 2),
                        ),
                      ),
                    );
                  },
                ),
                for (var i = 0; i < tabs; i++) tab(i),
              ],
            ),
          ),
        ),
        const Spacer(),
        GlassPanel(
          radius: radius,
          padding: const EdgeInsets.all(GlassNavBar.inset),
          child: Tooltip(
            message: widget.actionTooltip,
            child: SizedBox.square(
              dimension: height,
              child: Material(
                color: scheme.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const ValueKey('nav-action'),
                  customBorder: const CircleBorder(),
                  onTap: widget.onAction,
                  child: Icon(Icons.add_rounded, size: 28, color: scheme.onPrimary),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Пункт панели вкладок: иконка, под ней подпись.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelInSemantics = true,
  });

  final IconData icon;
  final String label;

  /// `null` — нажатие обрабатывает предок (меню действия).
  final VoidCallback? onTap;
  final bool labelInSemantics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface;
    // Подпись сжимается, а не вылезает за вкладку при крупном системном
    // шрифте: по ширине — `FittedBox`, по высоте — `Flexible` ниже (без него
    // колонка даёт подписи бесконечную высоту, и короткое «Home» не сжималось).
    final Widget text = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        style: theme.textTheme.navLabel.copyWith(color: color),
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: AppSpacing.s2),
              Flexible(
                child: labelInSemantics ? text : ExcludeSemantics(child: text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Пункт меню «⋯»: значение, подпись, иконка; [destructive] — красный пункт
/// («Delete»).
class MenuAction<T> {
  const MenuAction({
    required this.value,
    required this.label,
    required this.icon,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData icon;
  final bool destructive;
}

/// Круглая стеклянная кнопка «⋯» с Flutter-меню.
///
/// Системную кнопку с меню Liquid Glass (`cupertino_native`) здесь держать
/// нельзя — см. [GlassIconButton].
class GlassMenuButton<T> extends StatelessWidget {
  const GlassMenuButton({
    super.key,
    required this.actions,
    required this.onSelected,
    required this.tooltip,
  });

  final List<MenuAction<T>> actions;
  final ValueChanged<T> onSelected;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<T>(
      tooltip: tooltip,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final a in actions)
          PopupMenuItem<T>(
            value: a.value,
            child: MenuRow(
              icon: a.icon,
              label: a.label,
              destructive: a.destructive,
            ),
          ),
      ],
      child: GlassPanel(
        radius: AppSizes.iconButton / 2,
        blur: 18,
        child: SizedBox(
          width: AppSizes.iconButton,
          height: AppSizes.iconButton,
          child: Icon(Icons.more_horiz, size: 22, color: scheme.onSurface),
        ),
      ),
    );
  }
}

/// Строка пункта меню: иконка и подпись; [destructive] — в цвете ошибки.
class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpacing.s12),
        // Меню не шире 280 pt: длинная подпись («Delete folder») при крупном
        // системном шрифте обрезается многоточием, а не вылезает за край.
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Круглая стеклянная кнопка-иконка 44 px (шапки экранов), Flutter-стекло
/// на всех платформах.
///
/// До 2026-09-16 на iPhone здесь стояла системная кнопка Liquid Glass
/// (`CNButton.icon` из `cupertino_native`, то есть `UiKitView`). С Flutter
/// 3.47 движок иначе режет свой контент на слои «под» и «над» встроенной
/// системной вью (flutter/flutter#182662, регрессии #191771 и #192245), и
/// стеклянная пилюля заголовка в той же шапке — `BackdropFilter`, который
/// рисуется после кнопки, — теряла боковые полосы заливки: внутри пилюли
/// проступал «квадрат» (iPhone 15 Pro, iOS 27; на симуляторе не
/// воспроизводится). Проверено на устройстве: с Flutter-кнопкой артефакта
/// нет. Заказчику этот вид кнопок к тому же нравится больше, поэтому
/// системные кнопки и меню в шапках больше не используются; страж —
/// `test/architecture/invariants_test.dart`.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = AppSizes.iconButton,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = GlassPanel(
      radius: size / 2,
      blur: 18,
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Icon(icon, size: 22, color: scheme.onSurface),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Сообщает наружу фактическую высоту ребёнка: после первого кадра и при
/// каждом её изменении. Измеряется в `addPostFrameCallback`, а [onHeight]
/// зовётся только когда высота действительно изменилась — иначе панель
/// меняла бы отступ тела, тело перестраивало бы панель, и перестройки не
/// кончились бы.
class MeasuredHeight extends StatefulWidget {
  const MeasuredHeight({
    super.key,
    required this.onHeight,
    required this.child,
  });

  final ValueChanged<double> onHeight;
  final Widget child;

  @override
  State<MeasuredHeight> createState() => _MeasuredHeightState();
}

class _MeasuredHeightState extends State<MeasuredHeight> {
  final _box = GlobalKey();
  double? _reported;

  void _measure() {
    if (!mounted) return;
    final render = _box.currentContext?.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return;
    final height = render.size.height;
    if (_reported != null && (_reported! - height).abs() < 0.5) return;
    _reported = height;
    widget.onHeight(height);
  }

  void _measureAfterFrame() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

  @override
  Widget build(BuildContext context) {
    _measureAfterFrame();
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _measureAfterFrame();
        return false;
      },
      child: SizeChangedLayoutNotifier(key: _box, child: widget.child),
    );
  }
}

/// «Шторка» под строкой состояния iOS (время, Wi‑Fi, батарея): контент,
/// уезжающий при прокрутке под верхний край, растворяется в фоне и не
/// смешивается с системными надписями (до 2026-09-19 «6 new» печаталось
/// прямо поверх «03:04»).
///
/// Это НЕ блок с краем. Раньше сверху стоял блок, под который всё «заезжало
/// и обрезалось», — заказчика это раздражало, и его убрали. Поэтому здесь
/// только цвет фона: плотный в зоне строки состояния и сходящий в полную
/// прозрачность на хвосте [tail] ниже неё; границы, по которой контент
/// обрывался бы, нет. Нажатий шторка не ловит.
///
/// Высота берётся из `viewPadding`, а не из `padding`: сессии добавляют в
/// `padding.top` свою пилюлю прогресса, а строке состояния до этого дела нет.
/// Нет строки состояния (альбомная ориентация, тесты) — нет и шторки.
class StatusBarVeil extends StatelessWidget {
  const StatusBarVeil({super.key});

  /// Хвост ниже строки состояния, на котором цвет сходит в ноль.
  static const double tail = 28;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).top;
    if (inset <= 0) return const SizedBox.shrink();
    final background = Theme.of(context).scaffoldBackgroundColor;
    final height = inset + tail;
    return IgnorePointer(
      child: SizedBox(
        key: const ValueKey('status-bar-veil'),
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [background, background, background.withValues(alpha: 0)],
              // Под временем и индикаторами — сплошной фон: на кадрах
              // симулятора при 90 % за «11:52» ещё читался призрак заголовка
              // карточки. Спад начинается чуть выше низа строки состояния и
              // тянется на весь хвост — 44 pt без единой границы.
              stops: [0, math.max(0, inset - 16) / height, 1],
            ),
          ),
        ),
      ),
    );
  }
}

/// Шторка под нижней панелью действий — зеркало [StatusBarVeil] (решение
/// заказчика 2026-09-23: список уезжал под «Continue» / «Finish for now» и
/// читался сквозь текстовую кнопку). Цвет фона, плотный под кнопками и до
/// нижнего края экрана, сходящий в полную прозрачность на хвосте [tail] выше
/// панели; края нет; нажатий не ловит. Лежит над телом, но под панелью —
/// кнопки остаются чёткими. Только для панели [GlassScaffold.bar]: панель
/// вкладок (`GlassNavBar`, `TabShell`) остаётся стеклом без шторки — так
/// решил заказчик.
///
/// Спад начинается на [fadeInside] ниже верха панели — под верхом главной
/// кнопки, которая и так непрозрачна, — и тянется вверх на весь хвост:
/// последняя строка списка (она стоит на `AppSpacing.scrollBottom`, то есть
/// на 16 выше панели) в покое остаётся практически нетронутой.
class BarVeil extends StatelessWidget {
  const BarVeil({super.key, required this.barHeight});

  /// Высота панели вместе с её отступами — та же, что тело видит в
  /// `MediaQuery.padding.bottom`; пока панель не измерена — 0.
  final double barHeight;

  /// Хвост выше панели, на котором цвет сходит в ноль.
  static const double tail = 20;

  /// Насколько ниже верха панели начинается спад.
  static const double fadeInside = 16;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    final height = barHeight + tail;
    return IgnorePointer(
      child: SizedBox(
        key: const ValueKey('bar-veil'),
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [background.withValues(alpha: 0), background, background],
              stops: [0, math.min(1, (tail + fadeInside) / height), 1],
            ),
          ),
        ),
      ),
    );
  }
}

/// Обёртка для `Scaffold`: прозрачная шапка [header] лежит поверх тела
/// (контент уезжает под неё и виден сквозь стекло кнопок; пустое место
/// шапки не перехватывает нажатия). Панель действий [bar] стоит у нижнего
/// края экрана; подложки у неё нет, но под ней лежит шторка [BarVeil] — цвет
/// фона, гаснущий кверху, чтобы уехавший под кнопки список не читался сквозь
/// текстовую кнопку. При открытой клавиатуре панель никуда не уезжает —
/// клавиатура её просто накрывает. Полоски «Done» над клавиатурой нет (убрана
/// по решению заказчика 2026-09-19): клавиатуру закрывают «Готово» на ней самой
/// и смахивание списка (`keyboardDismissBehavior: onDrag`).
/// [barHidesForKeyboard] = false — панель живёт внутри тела и поднимается над
/// клавиатурой (строка ввода в сессии).
///
/// Высота панели измеряется ([MeasuredHeight]) и уходит в тело через
/// `MediaQuery.padding.bottom`: панель из двух кнопок выше панели из одной,
/// и фиксированный отступ оставлял последнюю строку списка под кнопкой.
/// Списки начинают контент ниже шапки через `AppSpacing.scroll`.
class GlassScaffold extends StatefulWidget {
  const GlassScaffold({
    super.key,
    required this.body,
    this.header,
    this.appBar,
    this.bar,
    this.barHidesForKeyboard = true,
    this.floatingActionButton,
  });

  /// Тело экрана — функция, а не готовый виджет: каркас зовёт её сам, с
  /// контекстом ПОД своим `MediaQuery`, где в `padding.bottom` уже лежит
  /// высота нижней панели. Пока тело передавали виджетом, каждый
  /// прокручиваемый экран обязан был обернуть его в `Builder`, чтобы
  /// добраться до этого контекста; забыть обёртку значило тихо оставить
  /// последнюю строку списка под кнопкой (ревью 2026-09-11, находка 15).
  final WidgetBuilder body;

  /// Шапка лежит поверх тела у верхнего края: высота нижней панели ей не
  /// нужна, поэтому она остаётся готовым виджетом — как [appBar], [bar] и
  /// [floatingActionButton]. Для [bar] это тем более так: его как раз и
  /// измеряют, и брать из него собственную высоту было бы кругом.
  final Widget? header;
  final PreferredSizeWidget? appBar;

  /// Содержимое нижней панели (кнопки или строка ввода).
  final Widget? bar;
  final bool barHidesForKeyboard;
  final Widget? floatingActionButton;

  /// Отступ нижней панели от боков: поля страницы, кнопка той же ширины, что
  /// и контент.
  static const double barSide = AppSpacing.s24;

  /// Отступ нижней панели от нижнего края экрана — ровно тот же, что у панели
  /// вкладок (`TabShell.barInset`, равенство держит тест): кнопки и навигация
  /// на всех экранах стоят на одной высоте (решение заказчика 2026-09-19).
  /// Нижняя безопасная зона (полоска «домой», 34 pt) намеренно не учитывается.
  static const double barBottom = AppSpacing.s16;

  @override
  State<GlassScaffold> createState() => _GlassScaffoldState();
}

class _GlassScaffoldState extends State<GlassScaffold> {
  /// Фактическая высота нижней панели вместе с её отступами; тело получает
  /// её через `MediaQuery.padding.bottom`. Это высота той панели, что сейчас
  /// в дереве: пока панели нет, она равна нулю.
  double _barHeight = 0;

  /// Готовое тело, а не свежий `Builder` на каждую перестройку каркаса.
  /// Каркас перестраивается, когда меняется его `MediaQuery` (выезд
  /// клавиатуры — два десятка кадров подряд), и новый экземпляр `Builder` каждый раз
  /// заставлял бы `Element.updateChild` пересобирать всё поддерево тела —
  /// два десятка полных перестроек формы ровно в тот момент, когда человек
  /// начинает печатать. Экземпляр меняется только вместе с виджетом
  /// каркаса, то есть когда экран-родитель пересобрался и дал новую функцию
  /// сборки, — так же, как когда тело передавали готовым виджетом.
  late Widget _bodyChild = Builder(builder: widget.body);

  void _onBarHeight(double height) {
    if (!mounted || (height - _barHeight).abs() < 0.5) return;
    setState(() => _barHeight = height);
  }

  @override
  void didUpdateWidget(covariant GlassScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Родитель пересобрался — вместе с ним обязано пересобраться и тело.
    _bodyChild = Builder(builder: widget.body);
    // Панель убрали — вместе с ней ушёл и её измеритель [MeasuredHeight],
    // а без измерителя `_barHeight` уже никто не обновит: старая высота
    // осталась бы в отступе тела до конца жизни экрана, и контент рисовался
    // бы в области, укороченной снизу под несуществующую панель. Экраны
    // снимают панель на ходу (Cards убирает «Close», как только пришли
    // слова; сессия — когда открывается панель ответа).
    if (oldWidget.bar != null && widget.bar == null) _barHeight = 0;
  }

  @override
  Widget build(BuildContext context) {
    final bar = widget.bar;
    final header = widget.header;
    final barHidesForKeyboard = widget.barHidesForKeyboard;
    Widget? barBox;
    if (bar == null) {
      barBox = null;
    } else {
      // Отступ от низа — [GlassScaffold.barBottom], одинаковый у кнопок под
      // клавиатурой и у строки ввода сессии над ней. Константа, а не
      // `padding.bottom`: его iOS обнуляет, пока клавиатура открыта, и кнопки
      // под ней сползали бы и возвращались при её закрытии.
      barBox = Padding(
        padding: const EdgeInsets.fromLTRB(
          GlassScaffold.barSide,
          0,
          GlassScaffold.barSide,
          GlassScaffold.barBottom,
        ),
        child: bar,
      );
    }
    if (barBox != null) {
      barBox = MeasuredHeight(onHeight: _onBarHeight, child: barBox);
    }
    // Дерево над телом не зависит от клавиатуры: тело всегда первый
    // ребёнок одного и того же Stack, слои добавляются только после него.
    // Иначе при открытии клавиатуры тело пересоздавалось целиком, поля
    // теряли фокус и клавиатура тут же пряталась. По той же причине обёртка
    // с отступом под панель стоит всегда, даже когда панели нет.
    final content = Stack(
      children: [
        Positioned.fill(child: _bodyWithBarInset()),
        // Над телом, но под шапкой: кнопки и пилюля заголовка остаются
        // чёткими, гаснет только контент, уезжающий под строку состояния.
        const Positioned(top: 0, left: 0, right: 0, child: StatusBarVeil()),
        if (header != null)
          Positioned(top: 0, left: 0, right: 0, child: header),
        if (barBox != null && !barHidesForKeyboard) ...[
          // Строка ввода: внутри тела, поднимается вместе с клавиатурой;
          // шторка под ней — тоже.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BarVeil(barHeight: _barHeight),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: barBox),
        ],
      ],
    );
    final scaffold = Scaffold(
      appBar: widget.appBar,
      floatingActionButton: widget.floatingActionButton,
      body: content,
    );
    if (barBox == null || !barHidesForKeyboard) return scaffold;
    // Кнопки — вне Scaffold: тело сжимается под клавиатуру, а кнопки
    // остаются у нижнего края экрана, и клавиатура их накрывает.
    return Stack(
      children: [
        Positioned.fill(child: scaffold),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: BarVeil(barHeight: _barHeight),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: barBox),
      ],
    );
  }

  /// Тело видит высоту панели как `MediaQuery.padding.bottom`: отсюда её
  /// берут `AppSpacing.scroll` и все прокручиваемые экраны.
  Widget _bodyWithBarInset() => Builder(
    builder: (context) {
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(
          padding: mq.padding.copyWith(
            bottom: math.max(mq.padding.bottom, _barHeight),
          ),
        ),
        // Тело строится здесь, а не снаружи: `Builder` даёт ему контекст
        // ниже этого `MediaQuery`, иначе высоты панели оно бы не увидело.
        // Экземпляр `Builder` переживает перестройки каркаса — см.
        // [_bodyChild].
        child: _bodyChild,
      );
    },
  );
}
