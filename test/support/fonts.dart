import 'dart:io';

import 'package:flutter/services.dart';

bool _loaded = false;

/// Настоящие шрифты в тестах вместо Ahem: Outfit, Onest (кириллица) и
/// Material Icons — иначе кадры и замеры ширины текста врут.
Future<void> loadAppFonts() async {
  if (_loaded) return;
  _loaded = true;
  Future<ByteData> file(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());
  for (final family in ['Outfit', 'Onest']) {
    final loader = FontLoader(family);
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(file('assets/fonts/$family-$w.ttf'));
    }
    await loader.load();
  }
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final icons = FontLoader('MaterialIcons')
    ..addFont(file('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}
