import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../features/settings/domain/settings.dart';
import 'app.dart';
import 'providers.dart';
import 'startup.dart';
import 'theme.dart';
import 'widgets/startup_failure_screen.dart';
import 'widgets/toast.dart';

/// Корень дерева: `runApp` вызывается сразу, инициализация идёт под ним, и
/// её отказ — состояние экрана, а не отсутствие приложения (Jattap).
class StartupGate extends StatefulWidget {
  const StartupGate({super.key, this.startUp = runStartup, this.onReady = completeStartup});

  final Future<StartupResult> Function({List<Override> overrides}) startUp;

  /// Отложенная работа после первого удачного кадра.
  final void Function(StartupSuccess success) onReady;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  StartupResult? _result;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    _attempt++;
    final result = await widget.startUp(overrides: [appRestartProvider.overrideWithValue(_restart)]);
    if (!mounted) {
      if (result is StartupSuccess) result.container.dispose();
      return;
    }
    setState(() => _result = result);
    if (result is StartupSuccess) {
      widget.onReady(result);
      final toast = _pendingToast;
      _pendingToast = null;
      if (toast != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final overlay = result.router.routerDelegate.navigatorKey.currentState?.overlay;
          if (overlay != null) showActionToastOn(overlay, toast);
        });
      }
    }
  }

  String? _pendingToast;

  void _retry() {
    setState(() => _result = null);
    unawaited(_start());
  }

  /// §7: снять экраны → закрыть контейнер → [work] → запустить заново.
  Future<void> _restart({Future<void> Function()? work, String? toast, String Function(Object error)? failToast}) async {
    final old = _result;
    setState(() => _result = null);
    await WidgetsBinding.instance.endOfFrame;
    if (old is StartupSuccess) {
      old.container.dispose();
      old.router.dispose();
    }
    _pendingToast = toast;
    if (work != null) {
      try {
        await work();
      } catch (error, stack) {
        FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'backup'));
        _pendingToast = failToast?.call(error);
      }
    }
    if (mounted) await _start();
  }

  @override
  void dispose() {
    final result = _result;
    if (result is StartupSuccess) result.container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result is StartupSuccess) {
      return UncontrolledProviderScope(
        container: result.container,
        child: _LocalizedApp(router: result),
      );
    }
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: appLocalizationDelegates,
      supportedLocales: const [Locale('en'), Locale('ru')],
      localeResolutionCallback: FintechApp.resolveLocale,
      home: switch (result) {
        StartupFailure(:final reason, :final error) => StartupFailureScreen(
          reason: reason,
          details: '$error',
          onRetry: reason == StartupFailureReason.unknown ? _retry : null,
        ),
        _ when _attempt > 1 => const Scaffold(body: Center(child: CircularProgressIndicator())),
        _ => const Scaffold(),
      },
    );
  }
}

/// Приложение в языке из настроек (`system` — как в системе).
class _LocalizedApp extends ConsumerWidget {
  const _LocalizedApp({required this.router});

  final StartupSuccess router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(settingsProvider).value?.language ?? AppLanguage.system;
    return FintechApp(
      router: router.router,
      locale: switch (language) {
        AppLanguage.en => const Locale('en'),
        AppLanguage.ru => const Locale('ru'),
        AppLanguage.system => null,
      },
    );
  }
}
