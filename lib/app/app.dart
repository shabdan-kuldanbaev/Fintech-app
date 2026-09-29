import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import 'theme.dart';

/// Корень приложения после успешного запуска.
///
/// [locale] — выбор из настроек (`app_settings.locale`, spec.md §8.1);
/// `null` — как в системе: русский, если система русская, иначе английский.
class FintechApp extends StatelessWidget {
  const FintechApp({super.key, required this.router, this.locale});

  final GoRouter router;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeResolutionCallback: resolveLocale,
      // Тап по пустому месту прячет клавиатуру.
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
      ),
    );
  }

  /// Язык устройства → язык приложения: русский для русского, английский для
  /// всех остальных.
  static Locale resolveLocale(Locale? device, Iterable<Locale> supported) =>
      device?.languageCode == 'ru' ? const Locale('ru') : const Locale('en');
}

/// Делегаты локализации для экранов вне [FintechApp] (экран отказа запуска).
const List<LocalizationsDelegate<dynamic>> appLocalizationDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
