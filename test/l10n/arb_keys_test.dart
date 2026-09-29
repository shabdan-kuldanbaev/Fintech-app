import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// I14: английский и русский ARB — один и тот же набор ключей, и у каждой
/// строки с плейсхолдерами в русском те же плейсхолдеры.
Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _messages(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

Set<String> _placeholders(String text) => RegExp(r'\{(\w+)[,}]')
    .allMatches(text)
    .map((m) => m.group(1)!)
    .where((p) => !const {'count', 'n'}.contains(p) || text.contains('{$p}') || text.contains('{$p,'))
    .toSet();

void main() {
  final en = _arb('en');
  final ru = _arb('ru');

  test('same keys in en and ru', () {
    expect(_messages(ru).difference(_messages(en)), isEmpty, reason: 'лишние в ru');
    expect(_messages(en).difference(_messages(ru)), isEmpty, reason: 'нет в ru');
  });

  test('no empty strings', () {
    for (final arb in [en, ru]) {
      for (final k in _messages(arb)) {
        expect((arb[k] as String).trim(), isNotEmpty, reason: k);
      }
    }
  });

  test('placeholders match', () {
    for (final k in _messages(en)) {
      expect(
        _placeholders(ru[k] as String),
        _placeholders(en[k] as String),
        reason: k,
      );
    }
  });

  test('Russian plurals have one/few/many', () {
    for (final k in _messages(ru)) {
      final text = ru[k] as String;
      if (!text.contains('plural,')) continue;
      final exact = RegExp(r'=0\{').hasMatch(text);
      for (final form in ['one{', 'few{', 'many{', 'other{']) {
        expect(text.contains(form) || (exact && form == 'one{'), isTrue, reason: '$k: $form');
      }
    }
  });
}
