// Тёмная тема: обе схемы строятся, пастель в тёмной перевёрнута по светлоте,
// контраст пар посчитан, а светлая палитра не сдвинулась ни на единицу.
//
// Контраст считается здесь, а не берётся на глаз: формула WCAG 2.1
// (относительная яркость sRGB), порог 4.5:1 — «нормальный текст, уровень AA».
import 'dart:math' as math;

import 'package:fintech/app/app.dart';
import 'package:fintech/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Относительная яркость по WCAG 2.1 (§ «relative luminance»).
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

/// Коэффициент контраста двух непрозрачных цветов, 1.0…21.0.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Порог AA для обычного текста.
const double _aa = 4.5;

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';

typedef _Pastel = ({String name, Color Function(AppColors) fill, Color Function(AppColors) on});

const List<_Pastel> _pastels = [
  (name: 'lavender', fill: _lavender, on: _onLavender),
  (name: 'mint', fill: _mint, on: _onMint),
  (name: 'butter', fill: _butter, on: _onButter),
  (name: 'blush', fill: _blush, on: _onBlush),
  (name: 'sky', fill: _sky, on: _onSky),
];

Color _lavender(AppColors c) => c.lavender;
Color _onLavender(AppColors c) => c.onLavender;
Color _mint(AppColors c) => c.mint;
Color _onMint(AppColors c) => c.onMint;
Color _butter(AppColors c) => c.butter;
Color _onButter(AppColors c) => c.onButter;
Color _blush(AppColors c) => c.blush;
Color _onBlush(AppColors c) => c.onBlush;
Color _sky(AppColors c) => c.sky;
Color _onSky(AppColors c) => c.onSky;

AppColors _colors(ThemeData theme) => theme.extension<AppColors>()!;

void main() {
  final light = AppTheme.light();
  final dark = AppTheme.dark();
  final lightColors = _colors(light);
  final darkColors = _colors(dark);

  group('обе темы строятся', () {
    test('яркость схемы совпадает с запрошенной', () {
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.colorScheme.brightness, Brightness.light);
      expect(dark.colorScheme.brightness, Brightness.dark);
    });

    test('расширение AppColors есть в обеих', () {
      expect(light.extension<AppColors>(), isNotNull);
      expect(dark.extension<AppColors>(), isNotNull);
    });
  });

  group('тёмная тема тёмная', () {
    test('фон тёмный, текст на нём светлый', () {
      expect(
        _luminance(dark.scaffoldBackgroundColor),
        lessThan(0.05),
        reason: 'фон тёмной темы должен быть тёмным',
      );
      expect(
        _luminance(dark.colorScheme.onSurface),
        greaterThan(0.5),
        reason: 'основной текст тёмной темы должен быть светлым',
      );
      expect(
        _contrast(dark.colorScheme.onSurface, dark.colorScheme.surface),
        greaterThanOrEqualTo(_aa),
      );
      expect(
        _contrast(dark.colorScheme.onSurfaceVariant, dark.colorScheme.surface),
        greaterThanOrEqualTo(_aa),
      );
    });

    test('светлая тема осталась светлой', () {
      expect(_luminance(light.scaffoldBackgroundColor), greaterThan(0.9));
      expect(_luminance(light.colorScheme.onSurface), lessThan(0.1));
    });
  });

  group('пастель тёмной темы', () {
    // Главная ловушка включения тёмной темы: пастель собрана одним набором на
    // обе яркости, и светлая плашка оказывается на тёмном фоне. Проверяем
    // именно порядок светлот, а не конкретные значения.
    for (final p in _pastels) {
      test('${p.name}: заливка темнее своего текста', () {
        final fill = p.fill(darkColors);
        final on = p.on(darkColors);
        expect(
          _luminance(fill),
          lessThan(_luminance(on)),
          reason:
              'в тёмной теме ${p.name} = ${_hex(fill)} должен быть темнее '
              'on${p.name} = ${_hex(on)}; светлая пастель на тёмном фоне — '
              'это невключённая тёмная тема',
        );
        expect(
          _luminance(fill),
          lessThan(0.2),
          reason: '${_hex(fill)} — заливка в тёмной теме, она не может светиться',
        );
      });

      test('${p.name}: контраст текста на заливке не ниже 4.5:1', () {
        final ratio = _contrast(p.on(darkColors), p.fill(darkColors));
        expect(
          ratio,
          greaterThanOrEqualTo(_aa),
          reason: '${p.name}: получилось ${ratio.toStringAsFixed(2)}:1',
        );
      });

      test('${p.name}: текст читается и прямо на фоне', () {
        // `on*` берут не только как текст на своей заливке: подписи в
        // статистике и на плитках модуля красятся им поверх фона и
        // поверхности.
        for (final ground in [
          dark.scaffoldBackgroundColor,
          dark.colorScheme.surfaceContainerLowest,
          dark.colorScheme.surfaceContainerLow,
        ]) {
          final ratio = _contrast(p.on(darkColors), ground);
          expect(
            ratio,
            greaterThanOrEqualTo(_aa),
            reason:
                'on${p.name} ${_hex(p.on(darkColors))} на ${_hex(ground)}: '
                '${ratio.toStringAsFixed(2)}:1',
          );
        }
      });

      test('${p.name}: тёмный вариант отличается от светлого', () {
        expect(p.fill(darkColors), isNot(p.fill(lightColors)));
        expect(p.on(darkColors), isNot(p.on(lightColors)));
      });
    }

    test('заливка отличима от фона и от поверхности', () {
      for (final p in _pastels) {
        final fill = p.fill(darkColors);
        expect(
          _contrast(fill, dark.scaffoldBackgroundColor),
          greaterThan(1.1),
          reason: '${p.name} ${_hex(fill)} сливается с фоном',
        );
      }
    });

    test('светлая пастель осталась светлой (роли не перепутаны)', () {
      for (final p in _pastels) {
        expect(
          _luminance(p.fill(lightColors)),
          greaterThan(_luminance(p.on(lightColors))),
          reason: 'в светлой теме ${p.name} — светлая заливка под тёмным текстом',
        );
      }
    });
  });

  group('схема тоже переключается', () {
    // `scheme.copyWith` в теме прибивал контейнеры к светлой пастели; если
    // это вернётся, тёмная схема снова начнёт отдавать светлые плашки.
    test('контейнеры схемы взяты из пастели своей яркости', () {
      expect(dark.colorScheme.primaryContainer, darkColors.lavender);
      expect(dark.colorScheme.onPrimaryContainer, darkColors.onLavender);
      expect(dark.colorScheme.secondaryContainer, darkColors.sky);
      expect(dark.colorScheme.onSecondaryContainer, darkColors.onSky);
      expect(dark.colorScheme.tertiaryContainer, darkColors.mint);
      expect(dark.colorScheme.onTertiaryContainer, darkColors.onMint);
      expect(dark.colorScheme.errorContainer, darkColors.blush);
      expect(dark.colorScheme.onErrorContainer, darkColors.onBlush);
      expect(dark.colorScheme.error, darkColors.onBlush);

      expect(light.colorScheme.primaryContainer, lightColors.lavender);
      expect(light.colorScheme.tertiaryContainer, lightColors.mint);
      expect(light.colorScheme.errorContainer, lightColors.blush);
    });

    test('контейнер и текст на нём контрастны в тёмной схеме', () {
      final s = dark.colorScheme;
      for (final pair in [
        (s.primaryContainer, s.onPrimaryContainer),
        (s.secondaryContainer, s.onSecondaryContainer),
        (s.tertiaryContainer, s.onTertiaryContainer),
        (s.errorContainer, s.onErrorContainer),
      ]) {
        expect(_contrast(pair.$2, pair.$1), greaterThanOrEqualTo(_aa));
      }
    });

    test('семантика «верно/неверно» читается в обеих темах', () {
      for (final c in [lightColors, darkColors]) {
        expect(_contrast(c.onSuccess, c.success), greaterThanOrEqualTo(_aa));
        expect(_contrast(c.onFailure, c.failure), greaterThanOrEqualTo(_aa));
        expect(_contrast(c.onMint, c.successContainer), greaterThan(3.5));
        expect(_contrast(c.onBlush, c.failureContainer), greaterThan(3.5));
      }
    });
  });

  group('капсула тоста', () {
    // Исключение из палитры: капсула сливается с аппаратным островом, поэтому
    // остаётся чистым чёрным в обеих темах. Текст на ней — свой цвет, не
    // `colorScheme.onPrimary`: тот в тёмной теме почти чёрный.
    test('чёрная в обеих темах', () {
      expect(lightColors.islandBlack, darkColors.islandBlack);
      expect(_luminance(lightColors.islandBlack), 0);
    });

    test('текст на ней читается в обеих темах', () {
      for (final c in [lightColors, darkColors]) {
        final ratio = _contrast(c.onIslandBlack, c.islandBlack);
        expect(
          ratio,
          greaterThanOrEqualTo(_aa),
          reason: 'текст тоста: ${ratio.toStringAsFixed(2)}:1',
        );
      }
    });

    test('onPrimary тёмной темы для капсулы не годится', () {
      // Фиксируем причину, по которой у текста тоста свой цвет: в тёмной теме
      // `onPrimary` — это цвет фона, и на чёрной капсуле он невидим.
      expect(
        _contrast(dark.colorScheme.onPrimary, darkColors.islandBlack),
        lessThan(_aa),
      );
    });
  });

  group('светлая палитра не изменилась', () {
    // Заказчик выверял светлую тему по кадрам с устройства (docs/ui_redesign.md
    // §10). Значения прибиты числами намеренно: включение тёмной темы не
    // должно сдвинуть светлую ни на единицу.
    test('пастель ровно та же, что в §10', () {
      expect(_hex(lightColors.lavender), '#E6DDF8');
      expect(_hex(lightColors.onLavender), '#6A4FB5');
      expect(_hex(lightColors.mint), '#D8F0E1');
      expect(_hex(lightColors.onMint), '#2F7A55');
      expect(_hex(lightColors.butter), '#FBEAC1');
      expect(_hex(lightColors.onButter), '#9A6A10');
      expect(_hex(lightColors.blush), '#F9D9DA');
      expect(_hex(lightColors.onBlush), '#B5504F');
      expect(_hex(lightColors.sky), '#D8E8F7');
      expect(_hex(lightColors.onSky), '#3B6B9C');
    });

    test('нейтральные тона и семантика светлой темы те же', () {
      // 2026-09-19, «A · Editorial light» (решение заказчика): фон — серый
      // awwwards.com, карточки на нём белые, графит мягче прежнего, рамка и
      // тихая заливка плотнее — на сером фоне прежние терялись. Пастель выше
      // не тронута.
      expect(_hex(light.scaffoldBackgroundColor), '#F8F8F8');
      expect(_hex(light.colorScheme.surfaceContainerLowest), '#FFFFFF');
      expect(_hex(light.colorScheme.onSurface), '#38383D');
      expect(_hex(light.colorScheme.onSurfaceVariant), '#6F6F76');
      expect(_hex(light.colorScheme.outline), '#C9C8CF');
      expect(_hex(light.colorScheme.outlineVariant), '#E8E8EA');
      expect(_hex(light.colorScheme.surfaceContainerLow), '#EFEFF0');
      expect(_hex(lightColors.success), '#2F7A55');
      expect(_hex(lightColors.onSuccess), '#FFFFFF');
      expect(_hex(lightColors.failure), '#B5504F');
      expect(_hex(lightColors.onFailure), '#FFFFFF');
      expect(_hex(lightColors.glass), '#FFFFFF');
      expect(lightColors.glass.a, closeTo(0x85 / 255, 0.002));
    });
  });

  group('тёмная палитра — «мягкий чёрный»', () {
    // 2026-09-20, решение заказчика: тёмная тема в духе awwwards.com — фон их
    // #222, нейтральные серые без фиолетового оттенка, смягчённый белый.
    test('нейтральные тона тёмной темы', () {
      expect(_hex(dark.scaffoldBackgroundColor), '#222222');
      expect(_hex(dark.colorScheme.surfaceContainerLowest), '#2B2B2B');
      expect(_hex(dark.colorScheme.surfaceContainerLow), '#343434');
      expect(_hex(dark.colorScheme.outlineVariant), '#3A3A3A');
      expect(_hex(dark.colorScheme.onSurface), '#F2F2F2');
      expect(_hex(dark.colorScheme.onSurfaceVariant), '#A7A7A7');
    });

    test('серые нейтральны: ни один канал не выбивается', () {
      for (final c in [
        dark.scaffoldBackgroundColor,
        dark.colorScheme.surfaceContainerLowest,
        dark.colorScheme.surfaceContainerLow,
        dark.colorScheme.outlineVariant,
        dark.colorScheme.onSurface,
        dark.colorScheme.onSurfaceVariant,
      ]) {
        expect(c.r, c.g, reason: _hex(c));
        expect(c.g, c.b, reason: _hex(c));
      }
    });

    test('карточка отличима от фона, рамка — от карточки', () {
      expect(
        _contrast(
          dark.colorScheme.surfaceContainerLowest,
          dark.scaffoldBackgroundColor,
        ),
        greaterThan(1.1),
      );
      expect(
        _contrast(
          dark.colorScheme.outlineVariant,
          dark.colorScheme.surfaceContainerLowest,
        ),
        greaterThan(1.2),
      );
    });
  });

  group('приложение следует системе', () {
    // Поведение, ради которого всё делалось: `themeMode: system`. Проверяем не
    // значение поля, а результат — какую тему получает экран при системной
    // тёмной яркости.
    Future<Brightness> brightnessSeenByScreen(
      WidgetTester tester,
      Brightness platform,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = platform;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      late Brightness seen;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) {
              seen = Theme.of(context).brightness;
              return const SizedBox.shrink();
            },
          ),
        ],
      );
      await tester.pumpWidget(FintechApp(router: router, withLock: false));
      await tester.pump();
      addTearDown(router.dispose);
      return seen;
    }

    testWidgets('системная тёмная — экран получает тёмную тему', (
      tester,
    ) async {
      expect(
        await brightnessSeenByScreen(tester, Brightness.dark),
        Brightness.dark,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('системная светлая — экран получает светлую тему', (
      tester,
    ) async {
      expect(
        await brightnessSeenByScreen(tester, Brightness.light),
        Brightness.light,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
