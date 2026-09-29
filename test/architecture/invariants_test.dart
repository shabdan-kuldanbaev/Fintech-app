// Стражи инвариантов spec.md §1 по исходникам lib/. Каждый страж проверен
// мутацией: нарочно нарушить правило в lib/ — страж краснеет.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> _dartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));

String _rel(File f) => f.path.replaceFirst('${Directory.current.path}/', '');

/// Исходник без строк-комментариев: правило в комментарии — не нарушение.
String _code(File f) => f
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  final all = _dartFiles('lib').toList();

  /// Сгенерированная локализация — не наш код.
  final lib = all.where((f) => !f.path.contains('/lib/l10n/')).toList();

  test('lib/ has sources', () => expect(lib, isNotEmpty));

  List<String> offenders(
    bool Function(File f) applies,
    bool Function(String code) violates,
  ) => [
    for (final f in lib)
      if (applies(f) && violates(_code(f))) _rel(f),
  ];

  bool anywhere(File f) => true;

  test('I1: no autoIncrement', () {
    expect(offenders(anywhere, (c) => c.contains('autoIncrement')), isEmpty);
  });

  test('I2: no physical DELETE of rows in lib/', () {
    // Восстановление копии удаляет ФАЙЛ базы (I20), а не строки.
    expect(
      offenders(
        anywhere,
        (c) =>
            RegExp(r'\b_?db\.delete\(').hasMatch(c) ||
            RegExp(r'DELETE\s+FROM', caseSensitive: false).hasMatch(c),
      ),
      isEmpty,
    );
  });

  test('I3: no stored balance column', () {
    final tables = File('lib/data/db/tables.dart').readAsStringSync();
    expect(
      RegExp(r'get\s+(balance|currentBalance|debt|spent)\b').hasMatch(tables),
      isFalse,
    );
  });

  test('I4: no floating-point money columns', () {
    final tables = File('lib/data/db/tables.dart').readAsStringSync();
    expect(tables, isNot(contains('RealColumn')));
    expect(tables, isNot(contains('real()')));
  });

  test('I5: DateTime stored as unix seconds', () {
    final build = File('build.yaml').readAsStringSync();
    expect(build, contains('store_date_time_values_as_text: false'));
  });

  test('I7: calendar arithmetic only in calendar.dart and schedule.dart', () {
    const allowed = [
      'lib/core/calendar.dart',
      'lib/features/payments/domain/schedule.dart',
    ];
    expect(
      offenders(
        (f) => !allowed.contains(_rel(f)),
        (c) =>
            RegExp(r'Duration\(\s*days\s*:').hasMatch(c) ||
            RegExp(r'DateTime(\.utc)?\([^)]*month\s*[+-]').hasMatch(c),
      ),
      isEmpty,
    );
  });

  test('I11: no hashCode-based ids and no matchDateTimeComponents', () {
    expect(
      offenders(
        (f) => f.path.contains('/notifications/'),
        (c) => c.contains('.hashCode') || c.contains('matchDateTimeComponents'),
      ),
      isEmpty,
    );
    expect(
      offenders(anywhere, (c) => c.contains('matchDateTimeComponents')),
      isEmpty,
    );
  });

  test('I12: network (dio) only in lib/data/rates/', () {
    expect(
      offenders(
        (f) => !f.path.contains('/data/rates/'),
        (c) => c.contains('package:dio/'),
      ),
      isEmpty,
    );
  });

  test('I13: presentation does not import drift or the database', () {
    bool presentation(File f) =>
        f.path.contains('/presentation/') || f.path.contains('/app/widgets/');
    expect(
      offenders(
        presentation,
        (c) =>
            c.contains('package:drift') ||
            RegExp(r"import\s+'[^']*data/db/").hasMatch(c),
      ),
      isEmpty,
    );
  });

  test('I14: no user-visible string literals with letters', () {
    // Text('Save'), label: 'Save', tooltip: 'Close', title: 'x', hintText: …
    // Интерполяция (`'${l.save} · ${l.optional}'`) — не литерал: буквы
    // внутри `${…}` и `$name` вырезаются до проверки.
    final literal = RegExp(
      r"""(\bText\(\s*|\b(label|hintText|labelText|title|tooltip|message|semanticLabel|body)\s*:\s*)(['"])((?:(?!\3)[^\n])*)\3""",
    );
    bool hasLetters(String code) => literal.allMatches(code).any((m) {
      final content = m.group(4)!
          .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
          .replaceAll(RegExp(r'\$\w+'), '');
      return RegExp(r'[A-Za-zА-Яа-яЁё]').hasMatch(content);
    });
    expect(offenders(anywhere, hasLetters), isEmpty);
  });

  test('I16: colors only in app/theme.dart', () {
    expect(
      offenders(
        (f) => !_rel(f).endsWith('app/theme.dart'),
        (c) =>
            RegExp(r'\bColor\(0x').hasMatch(c) ||
            RegExp(r'\bColors\.(?!transparent\b)\w+').hasMatch(c),
      ),
      isEmpty,
    );
  });

  test('I16: fontSize only in app/theme.dart', () {
    expect(
      offenders(
        (f) => !_rel(f).endsWith('app/theme.dart'),
        (c) => RegExp(r'\bfontSize\s*:').hasMatch(c),
      ),
      isEmpty,
    );
    final theme = File('lib/app/theme.dart').readAsStringSync();
    expect(RegExp(r'\bfontSize\s*:').allMatches(theme).length, greaterThan(10));
  });

  test('I16: no platform views and no cupertino_native', () {
    expect(
      offenders(
        anywhere,
        (c) => RegExp(
          r'\b(UiKitView|AppKitView|AndroidView|PlatformViewLink|HtmlElementView)\b|package:cupertino_native/',
        ).hasMatch(c),
      ),
      isEmpty,
    );
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('cupertino_native')));
  });

  test('I17: Clipboard.getData is never called', () {
    expect(offenders(anywhere, (c) => c.contains('Clipboard.getData')), isEmpty);
  });

  test('I18: local_auth only in lib/features/security/', () {
    expect(
      offenders(
        (f) => !f.path.contains('/features/security/'),
        (c) => c.contains('package:local_auth/'),
      ),
      isEmpty,
    );
  });

  test('I19: loan math (pow) only in loan_math.dart', () {
    expect(
      offenders(
        (f) => !_rel(f).endsWith('features/accounts/domain/loan_math.dart'),
        (c) => RegExp(r'\bpow\(').hasMatch(c),
      ),
      isEmpty,
    );
  });

  test('domain is pure: no I/O, Flutter widgets or database in */domain/', () {
    expect(
      offenders(
        (f) => f.path.contains('/domain/'),
        (c) =>
            c.contains('package:drift') ||
            c.contains("import 'dart:io'") ||
            c.contains('package:flutter/material.dart') ||
            RegExp(r"import\s+'[^']*data/").hasMatch(c),
      ),
      isEmpty,
    );
  });

  test('presentation never substitutes an empty list for a loading value', () {
    expect(
      offenders(
        (f) =>
            f.path.contains('/presentation/') ||
            f.path.contains('/app/widgets/'),
        (c) => RegExp(r'\.value\s*\?\?\s*(const\s*)?(\[|<)').hasMatch(c),
      ),
      isEmpty,
    );
  });
}
