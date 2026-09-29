import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Единственный источник цветов и типографики (CLAUDE.md «Правила изменений»).
///
/// Язык дизайна — Jattap (Flashcards-1.0, docs/ui_redesign.md §10; spec.md §8.0): мягкий графит вместо чёрного,
/// пастель только внутри карточек, шрифт Outfit, «стеклянные» панели. Форма
/// (карточки, скругления, шрифт, кегли) — прежняя; 2026-09-20 сменилась только
/// палитра нейтральных тонов, по мотивам awwwards.com (§12): светло-серый фон
/// с белыми поверхностями, графит мягче, тёмная тема — «мягкий чёрный».
abstract final class AppTheme {
  static const String fontFamily = 'Outfit';

  /// В Outfit нет кириллицы: русские буквы берутся из Onest — геометрический
  /// гротеск того же характера (OFL). Латиница и цифры остаются в Outfit.
  static const List<String> fontFallback = ['Onest'];

  // --- базовые тона
  static const Color _white = Color(0xFFFFFFFF);

  /// Фон страницы — серый awwwards.com (`--bg-primary`); карточки на нём белые.
  static const Color _ground = Color(0xFFF8F8F8);

  /// Графит. У awwwards это #222; заказчик попросил «чёрный нежнее».
  static const Color _ink = Color(0xFF38383D);
  static const Color _muted = Color(0xFF6F6F76);

  /// Рамка белой карточки на сером фоне — чуть плотнее прежней, иначе карточка
  /// сливается с фоном.
  static const Color _line = Color(0xFFE8E8EA);

  /// Тихая заливка (чипы, дорожки прогресса) — темнее фона, иначе не видна.
  static const Color _soft = Color(0xFFEFEFF0);
  static const Color _outline = Color(0xFFC9C8CF);

  /// Чёрного в палитре нет намеренно (§10: вместо него графит `_ink`).
  /// Этот цвет существует ровно для одного случая — капсула тоста на iPhone
  /// с Dynamic Island должна сливаться с аппаратным островом.
  static const Color _islandBlack = Color(0xFF000000);

  // --- пастель (заливка) и её текст
  static const Color _lavender = Color(0xFFE6DDF8);
  static const Color _onLavender = Color(0xFF6A4FB5);
  static const Color _mint = Color(0xFFD8F0E1);
  static const Color _onMint = Color(0xFF2F7A55);
  static const Color _butter = Color(0xFFFBEAC1);
  static const Color _onButter = Color(0xFF9A6A10);
  static const Color _blush = Color(0xFFF9D9DA);
  static const Color _onBlush = Color(0xFFB5504F);
  static const Color _sky = Color(0xFFD8E8F7);
  static const Color _onSky = Color(0xFF3B6B9C);

  // --- тёмная тема
  //
  // «Мягкий чёрный» awwwards.com (2026-09-20, решение заказчика): фон — их
  // `--bg-secondary` #222, а не почти чёрный; серые нейтральные, без прежнего
  // фиолетового оттенка. Поверхность на ступень светлее фона, рамка — рядом с
  // их #383838 (на ступень светлее, чтобы читалась и на поверхности), вторичный
  // текст — их #A7A7A7. Белый тоже смягчён. Контраст (WCAG 2.1): текст на фоне
  // 14,2:1, на поверхности 12,7:1; вторичный 6,6:1 и 5,9:1 — пороги в
  // test/app/theme_test.dart.
  static const Color _darkBg = Color(0xFF222222);
  static const Color _darkSurface = Color(0xFF2B2B2B);
  static const Color _darkSoft = Color(0xFF343434);
  static const Color _darkLine = Color(0xFF3A3A3A);
  static const Color _darkInk = Color(0xFFF2F2F2);
  static const Color _darkMuted = Color(0xFFA7A7A7);

  // --- пастель тёмной темы: тот же оттенок, перевёрнутая светлота
  //
  // Роли сохранены (мята — «верно», румянец — «неверно», остальные — акценты),
  // но в тёмной теме заливка тёмная, а текст на ней светлый. Иначе светлая
  // пастель светилась бы плитой на тёмном фоне, а `on*`-тона — их берут не
  // только как текст на своей заливке, но и как самостоятельный цвет подписи
  // прямо на фоне (`stats_screen`, `deck_widgets`, `test_screen`) — на тёмном
  // фоне были бы нечитаемы.
  //
  // Значения подобраны по контрасту, а не на глаз: заливка HSL(тон, 30%,
  // 24–25%), текст HSL(тон, 60%, 76–80%). Замеры (WCAG 2.1) — в
  // test/app/theme_test.dart, там же порог: текст на своей заливке ≥ 4.5:1
  // (получилось 5.99…6.32) и он же на фоне, поверхности и тихой заливке
  // ≥ 4.5:1 (на «мягком чёрном» 2026-09-20 — 6.15…11.09).
  static const Color _darkLavender = Color(0xFF372D53);
  static const Color _darkOnLavender = Color(0xFFBEADEB);
  static const Color _darkMint = Color(0xFF2B503D);
  static const Color _darkOnMint = Color(0xFF9DE7C2);
  static const Color _darkButter = Color(0xFF50432B);
  static const Color _darkOnButter = Color(0xFFE7CD9D);
  static const Color _darkBlush = Color(0xFF532D2D);
  static const Color _darkOnBlush = Color(0xFFEBAEAD);
  static const Color _darkSky = Color(0xFF2B3D50);
  static const Color _darkOnSky = Color(0xFF9DC2E7);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final ink = isLight ? _ink : _darkInk;
    final muted = isLight ? _muted : _darkMuted;
    final line = isLight ? _line : _darkLine;
    final soft = isLight ? _soft : _darkSoft;
    final surface = isLight ? _white : _darkSurface;
    final background = isLight ? _ground : _darkBg;

    // Текст на «сильной» заливке (графитовая кнопка, галочка, семантика). Пока
    // фон был белым, сюда годился сам цвет фона; на сером фоне светлой темы
    // надпись на кнопке обязана остаться белой.
    final onStrong = isLight ? _white : _darkBg;

    // Пастель выбирается по яркости здесь, одним местом: и схема, и
    // `AppColors` ниже берут именно эти переменные. Прибитая к светлым
    // константам схема давала бы в тёмной теме светлые плашки на тёмном фоне.
    final lavender = isLight ? _lavender : _darkLavender;
    final onLavender = isLight ? _onLavender : _darkOnLavender;
    final mint = isLight ? _mint : _darkMint;
    final onMint = isLight ? _onMint : _darkOnMint;
    final butter = isLight ? _butter : _darkButter;
    final onButter = isLight ? _onButter : _darkOnButter;
    final blush = isLight ? _blush : _darkBlush;
    final onBlush = isLight ? _onBlush : _darkOnBlush;
    final sky = isLight ? _sky : _darkSky;
    final onSky = isLight ? _onSky : _darkOnSky;

    final scheme = ColorScheme.fromSeed(seedColor: _ink, brightness: brightness)
        .copyWith(
          primary: ink,
          onPrimary: onStrong,
          primaryContainer: lavender,
          onPrimaryContainer: onLavender,
          secondary: onSky,
          secondaryContainer: sky,
          onSecondaryContainer: onSky,
          tertiary: onMint,
          tertiaryContainer: mint,
          onTertiaryContainer: onMint,
          error: onBlush,
          errorContainer: blush,
          onErrorContainer: onBlush,
          surface: background,
          onSurface: ink,
          onSurfaceVariant: muted,
          surfaceContainerLowest: surface,
          surfaceContainerLow: soft,
          surfaceContainer: soft,
          surfaceContainerHigh: soft,
          surfaceContainerHighest: soft,
          outline: isLight ? _outline : _darkLine,
          outlineVariant: line,
          shadow: _ink,
        );

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
    );

    const buttonText = TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    );

    OutlineInputBorder fieldBorder([Color? color, double width = 1.5]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: color == null
              ? BorderSide.none
              : BorderSide(color: color, width: width),
        );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      // Без Material-«ряби» (расползающийся круг при нажатии, заметен на
      // больших карточках вроде «More»): только лёгкое затемнение, как в iOS.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: ink.withValues(alpha: 0.05),
      hoverColor: Colors.transparent,
      textTheme: _textTheme(base.textTheme, ink, muted),
      // Cupertino-переходы на iOS: системный жест «назад» от левого края.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: line),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: onStrong,
          minimumSize: const Size.fromHeight(AppSizes.button),
          shape: const StadiumBorder(),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(AppSizes.button),
          shape: const StadiumBorder(),
          side: BorderSide(color: line, width: 1.5),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: muted,
          minimumSize: const Size.fromHeight(44),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: soft,
        border: fieldBorder(),
        enabledBorder: fieldBorder(),
        focusedBorder: fieldBorder(ink),
        errorBorder: fieldBorder(onBlush),
        focusedErrorBorder: fieldBorder(onBlush),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s18,
          vertical: AppSpacing.s16,
        ),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: muted,
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: muted,
        ),
        hintStyle: TextStyle(
          fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
          fontSize: 17,
          color: muted,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(surface),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? ink : line,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? ink : surface,
        ),
        checkColor: WidgetStatePropertyAll(onStrong),
        side: BorderSide(color: line, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
          fontSize: 15,
          height: 1.4,
          color: muted,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.row),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.card),
          ),
        ),
      ),
      extensions: [
        AppColors(
          // «Сильный» тон семантики — это `on*`-тон пары: в светлой теме он
          // тёмный и держит белый текст, в тёмной светлый и держит текст
          // цвета фона.
          success: onMint,
          onSuccess: onStrong,
          successContainer: mint,
          failure: onBlush,
          onFailure: onStrong,
          failureContainer: blush,
          lavender: lavender,
          onLavender: onLavender,
          mint: mint,
          onMint: onMint,
          butter: butter,
          onButter: onButter,
          blush: blush,
          onBlush: onBlush,
          sky: sky,
          onSky: onSky,
          glass: isLight ? const Color(0x85FFFFFF) : const Color(0x8A2B2B2B),
          glassBorder: isLight
              ? const Color(0xD9FFFFFF)
              : const Color(0x33FFFFFF),
          glassHighlight: isLight
              ? const Color(0xE6FFFFFF)
              : const Color(0x22FFFFFF),
          shadow: const Color(0x1238383D),
          shadowStrong: const Color(0x1A38383D),
          // Волосяная линия рисуется затемнением, и на тёмном фоне затемнять
          // нечего — там она осветляет.
          hairline: isLight ? const Color(0x0D38383D) : const Color(0x14F2F2F2),
          islandBlack: _islandBlack,
          onIslandBlack: _white,
        ),
      ],
    );
  }

  static TextTheme _textTheme(TextTheme base, Color ink, Color muted) {
    TextStyle s(
      double size,
      FontWeight weight, {
      double? height,
      double? spacing,
      Color? color,
    }) => TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: color ?? ink,
    );
    return base.copyWith(
      displaySmall: s(36, FontWeight.w700, height: 1.05),
      headlineMedium: s(32, FontWeight.w600, height: 1.1),
      headlineSmall: s(24, FontWeight.w600, height: 1.15),
      titleLarge: s(22, FontWeight.w600, height: 1.2),
      titleMedium: s(17, FontWeight.w600, height: 1.25),
      titleSmall: s(15, FontWeight.w600, height: 1.25),
      bodyLarge: s(17, FontWeight.w400, height: 1.35),
      bodyMedium: s(15, FontWeight.w400, height: 1.35),
      bodySmall: s(13, FontWeight.w400, height: 1.35, color: muted),
      labelLarge: s(15, FontWeight.w600),
      labelMedium: s(13, FontWeight.w600),
      labelSmall: s(12, FontWeight.w600, spacing: 0.7, color: muted),
    );
  }
}

/// Семантические и пастельные цвета из Jattap (Flashcards-1.0, docs/ui_redesign.md §10; spec.md §8.0).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.failure,
    required this.onFailure,
    required this.failureContainer,
    required this.lavender,
    required this.onLavender,
    required this.mint,
    required this.onMint,
    required this.butter,
    required this.onButter,
    required this.blush,
    required this.onBlush,
    required this.sky,
    required this.onSky,
    required this.glass,
    required this.glassBorder,
    required this.glassHighlight,
    required this.shadow,
    required this.shadowStrong,
    required this.hairline,
    required this.islandBlack,
    required this.onIslandBlack,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color failure;
  final Color onFailure;
  final Color failureContainer;
  final Color lavender;
  final Color onLavender;
  final Color mint;
  final Color onMint;
  final Color butter;
  final Color onButter;
  final Color blush;
  final Color onBlush;
  final Color sky;
  final Color onSky;

  /// Заливка стеклянной панели (поверх размытия), её кромка и блик.
  final Color glass;
  final Color glassBorder;
  final Color glassHighlight;
  final Color shadow;
  final Color shadowStrong;
  final Color hairline;

  /// Цвет капсулы тоста на iPhone с Dynamic Island: она должна сливаться с
  /// аппаратным островом, поэтому здесь чистый чёрный, а не графит.
  final Color islandBlack;

  /// Текст на капсуле тоста. Отдельный цвет, а не `colorScheme.onPrimary`:
  /// капсула чёрная в обеих темах, а `onPrimary` следует за темой и в тёмной
  /// становится почти чёрным (`_darkBg` на чистом чёрном — 1.17:1, текст
  /// пропадает). Здесь белый в обеих темах — 21:1.
  final Color onIslandBlack;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  /// Ключи пастели (`accounts.color_key`, `categories.color_key`, spec.md §8.0).
  static const List<String> pastelKeys = [
    'lavender',
    'mint',
    'butter',
    'blush',
    'sky',
  ];

  /// Заливка по ключу пастели; неизвестный ключ — лаванда.
  Color pastel(String key) => switch (key) {
    'mint' => mint,
    'butter' => butter,
    'blush' => blush,
    'sky' => sky,
    _ => lavender,
  };

  /// Текст и иконка на заливке [pastel] того же ключа.
  Color onPastel(String key) => switch (key) {
    'mint' => onMint,
    'butter' => onButter,
    'blush' => onBlush,
    'sky' => onSky,
    _ => onLavender,
  };

  @override
  AppColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? failure,
    Color? onFailure,
    Color? failureContainer,
    Color? lavender,
    Color? onLavender,
    Color? mint,
    Color? onMint,
    Color? butter,
    Color? onButter,
    Color? blush,
    Color? onBlush,
    Color? sky,
    Color? onSky,
    Color? glass,
    Color? glassBorder,
    Color? glassHighlight,
    Color? shadow,
    Color? shadowStrong,
    Color? hairline,
    Color? islandBlack,
    Color? onIslandBlack,
  }) {
    return AppColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      failure: failure ?? this.failure,
      onFailure: onFailure ?? this.onFailure,
      failureContainer: failureContainer ?? this.failureContainer,
      lavender: lavender ?? this.lavender,
      onLavender: onLavender ?? this.onLavender,
      mint: mint ?? this.mint,
      onMint: onMint ?? this.onMint,
      butter: butter ?? this.butter,
      onButter: onButter ?? this.onButter,
      blush: blush ?? this.blush,
      onBlush: onBlush ?? this.onBlush,
      sky: sky ?? this.sky,
      onSky: onSky ?? this.onSky,
      glass: glass ?? this.glass,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      shadow: shadow ?? this.shadow,
      shadowStrong: shadowStrong ?? this.shadowStrong,
      hairline: hairline ?? this.hairline,
      islandBlack: islandBlack ?? this.islandBlack,
      onIslandBlack: onIslandBlack ?? this.onIslandBlack,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      success: l(success, other.success),
      onSuccess: l(onSuccess, other.onSuccess),
      successContainer: l(successContainer, other.successContainer),
      failure: l(failure, other.failure),
      onFailure: l(onFailure, other.onFailure),
      failureContainer: l(failureContainer, other.failureContainer),
      lavender: l(lavender, other.lavender),
      onLavender: l(onLavender, other.onLavender),
      mint: l(mint, other.mint),
      onMint: l(onMint, other.onMint),
      butter: l(butter, other.butter),
      onButter: l(onButter, other.onButter),
      blush: l(blush, other.blush),
      onBlush: l(onBlush, other.onBlush),
      sky: l(sky, other.sky),
      onSky: l(onSky, other.onSky),
      glass: l(glass, other.glass),
      glassBorder: l(glassBorder, other.glassBorder),
      glassHighlight: l(glassHighlight, other.glassHighlight),
      shadow: l(shadow, other.shadow),
      shadowStrong: l(shadowStrong, other.shadowStrong),
      hairline: l(hairline, other.hairline),
      islandBlack: l(islandBlack, other.islandBlack),
      onIslandBlack: l(onIslandBlack, other.onIslandBlack),
    );
  }
}

/// Отступы, общие для экранов.
///
/// Шкала снята с экранов, а не придумана (ревью 2026-09-11, находка 18):
/// прежние `xs/sm/md/lg/xl` описывали шкалу, которой в вёрстке не было — `xs`
/// не использовался ни разу, `xl` один раз, а в экранах жили чётные 2…24.
/// Здесь ровно эти значения, ни одно не изменилось: это переименование, а не
/// правка макета.
///
/// Имена численные намеренно. Ступени идут через два пункта и покрывают
/// диапазон без пропусков; словесные ярлыки пришлось бы раздать двенадцати
/// соседям, отличающимся на два, — и прочесть такой ярлык обратно в размер
/// стало бы нельзя (`md` — это 12, 14 или 16?). Имя со значением внутри
/// проверяемо глазом, а роль каждой ступени описана ниже.
///
/// Роли (то, где ступень реально стоит):
/// - 2, 4 — две строки одной подписи: значение и пояснение под ним;
/// - 6, 8 — иконка и текст в одном ряду, подпись под заголовком;
/// - 10, 12 — заголовок раздела и его содержимое, плитки в ряду;
/// - 14, 16 — поля строки списка и формы;
/// - 18, 20 — внутренние отступы поля ввода и стеклянной панели;
/// - 22, 24 — раздел от раздела, поля страницы;
/// - 32 — нижнее поле шторки, верх карточки пустого состояния.
///
/// Значения из одного-двух мест (3, 7, 13, 26, 30, 34, 36, 40) в шкалу не
/// вошли: это подгонка конкретного виджета, а не общий ритм экранов, и жить им
/// рядом со своим виджетом.
abstract final class AppSpacing {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s18 = 18;
  static const double s20 = 20;
  static const double s22 = 22;
  static const double s24 = 24;
  static const double s32 = 32;

  static const EdgeInsets page = EdgeInsets.symmetric(
    horizontal: s24,
    vertical: s16,
  );

  /// Отступ снизу у прокручиваемого контента, чтобы последняя строка вышла
  /// из-под нижней панели. Высоту своей панели `GlassScaffold` (и `TabShell`)
  /// измеряет и отдаёт телу через `MediaQuery.padding.bottom` — константы
  /// здесь нет намеренно: панель из двух кнопок выше панели из одной, и
  /// фиксированный отступ оставлял последнюю строку под кнопкой.
  ///
  /// Нужный [context] приходит сам: `GlassScaffold` зовёт `body` (а `TabShell`
  /// строит вкладки) уже под своим `MediaQuery`, так что высота панели в
  /// `padding.bottom` есть у любого контекста внутри тела.
  static double scrollBottom(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + s16;

  /// Прокручиваемый контент под прозрачной шапкой ([AppSizes.header]) и
  /// стеклянной панелью: status bar + шапка + [top] сверху, высота панели
  /// плюс запас снизу. Сессии добавляют высоту пилюли прогресса через
  /// `MediaQuery.padding.top` (см. `SessionScaffold`).
  static EdgeInsets scroll(BuildContext context, {double top = s8}) =>
      EdgeInsets.fromLTRB(
        s24,
        MediaQuery.paddingOf(context).top + AppSizes.header + top,
        s24,
        scrollBottom(context),
      );

  /// `TextField.scrollPadding`: при фокусе поле докручивается так, чтобы
  /// не оказаться ни под прозрачной шапкой, ни вплотную к клавиатуре.
  static EdgeInsets fieldScroll(BuildContext context) => EdgeInsets.only(
    top: MediaQuery.paddingOf(context).top + AppSizes.header + s24,
    bottom: s24,
  );
}

/// Скругления из макета.
abstract final class AppRadius {
  static const double card = 28;
  static const double tile = 24;
  static const double row = 20;
  static const double field = 18;
  static const double chip = 16;
  static const double pill = 40;
}

abstract final class AppSizes {
  static const double button = 56;
  static const double iconButton = 44;
  static const double field = 54;
  static const double barHeight = 64;

  /// Прозрачная шапка без status bar: 8 + 44 + 8.
  static const double header = AppSpacing.s8 + iconButton + AppSpacing.s8;

  /// Ряд с пилюлей прогресса под шапкой: 10 + 30 + 12.
  static const double progressRow = 52;
}

/// Тень стекла; карточки без теней — только рамка (решение заказчика).
abstract final class AppShadows {
  static List<BoxShadow> glass(AppColors c) => [
    BoxShadow(
      color: c.shadowStrong,
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];
}

/// Ступени типографики, которых нет в [TextTheme], но которые есть в макете
/// (https://claude.ai/artifact/4cGeWkGN4hV8b7EXu22cWn, spec.md §8.0).
///
/// Стили выведены из базовых `copyWith`: так они наследуют семейство шрифта и
/// цвет текста от темы и сами переезжают в тёмную схему. Цвет на месте вызова
/// оставлять можно (он из [ColorScheme]/[AppColors]); размер — нельзя.
extension AppTextStyles on TextTheme {
  /// Заголовок открытого экрана в шапке.
  TextStyle get screenTitle => titleMedium!;

  /// Главное число экрана (hero): «21 120».
  TextStyle get heroAmount => displaySmall!.copyWith(
    fontSize: 52,
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: -1,
  );

  /// Дробная часть и знак валюты рядом с [heroAmount].
  TextStyle get heroUnit =>
      titleLarge!.copyWith(fontSize: 22, fontWeight: FontWeight.w600);

  /// Сумма в поле ввода на экране «Add».
  TextStyle get amountInput => displaySmall!.copyWith(
    fontSize: 56,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -1,
  );

  /// Сумма в поле ввода на карточке наступления.
  TextStyle get amountInputSmall => displaySmall!.copyWith(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -1,
  );

  /// Крупное число на плитке счёта: «45 000».
  TextStyle get tileAmount => headlineSmall!.copyWith(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );

  /// Заголовок секции списка: «Upcoming», «Recent».
  TextStyle get sectionTitle => titleMedium!;

  /// Подпись капителью над группой: «TODAY · 34,00 SOM».
  TextStyle get groupLabel => labelSmall!.copyWith(letterSpacing: 0.9);

  /// Заголовок строки внутри карточки.
  TextStyle get rowTitle => titleMedium!.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  /// Сумма в строке списка — того же кегля, что [rowTitle].
  TextStyle get rowAmount => titleMedium!.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  /// Подпись под заголовком строки списка.
  TextStyle get rowSubtitle => bodySmall!;

  /// Текст в чипе и на кнопке «Pay» в строке.
  TextStyle get chipLabel => labelMedium!.copyWith(fontSize: 14);

  /// Подпись под иконкой в панели вкладок и под круглой кнопкой действия.
  TextStyle get navLabel =>
      labelMedium!.copyWith(fontSize: 12, fontWeight: FontWeight.w500);

  /// Подпись под категорией в сетке выбора.
  TextStyle get gridLabel =>
      labelMedium!.copyWith(fontSize: 12, fontWeight: FontWeight.w500);

  /// Большой заголовок пустого состояния и формы кредита («2 months»).
  TextStyle get bigTitle => headlineMedium!.copyWith(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.05,
    letterSpacing: -0.5,
  );

  /// Текст тоста. `decoration` снят явно: тост живёт в оверлее без
  /// `Material` и иначе наследует жёлтое двойное подчёркивание.
  TextStyle get toast =>
      titleSmall!.copyWith(height: 1.2, decoration: TextDecoration.none);
}
