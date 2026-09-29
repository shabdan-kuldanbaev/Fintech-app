import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app/app.dart';
import 'core/error_reporting.dart';

/// Этап 1 (spec.md §11): приложение запускается с пустой главной. Настоящий
/// запуск — база, часовой пояс, уведомления под `StartupGate` — этап 2.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installErrorHandlers();
  runApp(
    FintechApp(
      router: GoRouter(
        routes: [GoRoute(path: '/', builder: (context, state) => const Scaffold())],
      ),
    ),
  );
}
