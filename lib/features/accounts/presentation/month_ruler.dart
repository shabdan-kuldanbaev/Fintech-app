import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';

/// Шкала месяцев 1..[max] (приём Simbank, §8.3 «New loan»): листается
/// пальцем, выбранное число — под риской по центру, крупно.
class MonthRuler extends StatefulWidget {
  const MonthRuler({super.key, required this.value, required this.onChanged, this.max = 60});

  final int value;
  final ValueChanged<int> onChanged;
  final int max;

  @override
  State<MonthRuler> createState() => _MonthRulerState();
}

class _MonthRulerState extends State<MonthRuler> {
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: widget.value - 1);

  static const double _extent = 44;
  static const double _height = 72;

  @override
  void didUpdateWidget(MonthRuler old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.selectedItem + 1 && _controller.hasClients) {
      _controller.jumpToItem(widget.value - 1);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: _height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotatedBox(
            quarterTurns: 3,
            child: ListWheelScrollView.useDelegate(
              key: const ValueKey('month-ruler'),
              controller: _controller,
              itemExtent: _extent,
              diameterRatio: 40,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (i) {
                HapticFeedback.selectionClick();
                widget.onChanged(i + 1);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: widget.max,
                builder: (context, i) {
                  final n = i + 1;
                  final selected = n == widget.value;
                  return RotatedBox(
                    quarterTurns: 1,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _controller.animateToItem(
                        i,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '$n',
                            maxLines: 1,
                            softWrap: false,
                            style: selected
                                ? text.titleLarge?.copyWith(fontWeight: FontWeight.w700)
                                : text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: AppSpacing.s6),
                          Container(
                            width: 2,
                            height: n % 6 == 0 ? 16 : 10,
                            color: selected ? scheme.onSurface : scheme.outlineVariant,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          IgnorePointer(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(width: 2, height: 22, color: scheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
