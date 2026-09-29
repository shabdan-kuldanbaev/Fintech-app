import 'package:flutter/material.dart';

import 'app/startup_gate.dart';
import 'core/error_reporting.dart';

/// Запуск в три шага: биндинг, обработчики ошибок, `runApp`. База, часовой
/// пояс и первый запуск — под `runApp`, в [StartupGate]: их отказ — экран,
/// а не пустота (перенос из Jattap).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installErrorHandlers();
  runApp(const StartupGate());
}
