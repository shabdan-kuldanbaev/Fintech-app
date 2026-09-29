import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Формат резервной копии (spec.md §7): `fintech-backup` v1.
const String backupFormat = 'fintech-backup';
const int backupVersion = 1;

/// Таблицы копии в порядке вставки. Строки — как в базе: моменты — unix-
/// секунды UTC, даты — `YYYY-MM-DD`, деньги — `int`, включая `deleted_at`
/// (I20).
const List<String> backupTables = [
  'accounts',
  'categories',
  'recurring_rules',
  'occurrences',
  'transactions',
  'budgets',
  'exchange_rates',
];

/// Ссылки, которые обязаны вести на строку этого же файла:
/// таблица → [(колонка, таблица цели)].
const Map<String, List<(String, String)>> backupReferences = {
  'transactions': [
    ('account_id', 'accounts'),
    ('counter_account_id', 'accounts'),
    ('category_id', 'categories'),
    ('occurrence_id', 'occurrences'),
  ],
  'recurring_rules': [
    ('account_id', 'accounts'),
    ('counter_account_id', 'accounts'),
    ('category_id', 'categories'),
  ],
  'occurrences': [
    ('rule_id', 'recurring_rules'),
    ('transaction_id', 'transactions'),
  ],
  'budgets': [('category_id', 'categories')],
};

enum BackupErrorKind {
  /// Не наша копия или не JSON.
  format,

  /// Копия из более новой версии приложения.
  version,

  /// Нет обязательной части или ссылка ведёт в никуда.
  broken,
}

class BackupError implements Exception {
  const BackupError(this.kind, [this.detail = '']);
  final BackupErrorKind kind;
  final String detail;

  @override
  String toString() => 'BackupError(${kind.name}): $detail';
}

/// Разобранная и проверенная копия.
@immutable
class BackupData {
  const BackupData({required this.exportedAt, required this.settings, required this.tables});

  final DateTime exportedAt;

  /// `app_settings`: ключ → значение (уже из JSON).
  final Map<String, Object?> settings;

  /// Таблица → строки (колонка → значение).
  final Map<String, List<Map<String, Object?>>> tables;
}

String encodeBackup(BackupData data) => const JsonEncoder.withIndent(' ').convert({
  'format': backupFormat,
  'version': backupVersion,
  'exported_at': data.exportedAt.toUtc().toIso8601String(),
  'app_settings': data.settings,
  for (final t in backupTables) t: data.tables[t] ?? const <Map<String, Object?>>[],
});

/// Разбор и проверка до какой-либо записи (§7, I20): формат, версия,
/// обязательные ключи, строки — объекты с `id` (у курсов — `code`), каждая
/// ссылка ведёт на строку этого же файла. Любая ошибка — [BackupError].
BackupData decodeBackup(String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    throw const BackupError(BackupErrorKind.format, 'not JSON');
  }
  if (json is! Map<String, Object?> || json['format'] != backupFormat) {
    throw const BackupError(BackupErrorKind.format);
  }
  final version = json['version'];
  if (version is! int || version < 1) throw const BackupError(BackupErrorKind.format, 'version');
  if (version > backupVersion) throw BackupError(BackupErrorKind.version, '$version');

  final exported = DateTime.tryParse('${json['exported_at']}');
  if (exported == null) throw const BackupError(BackupErrorKind.broken, 'exported_at');
  final settings = json['app_settings'];
  if (settings is! Map<String, Object?>) throw const BackupError(BackupErrorKind.broken, 'app_settings');

  final tables = <String, List<Map<String, Object?>>>{};
  for (final t in backupTables) {
    final rows = json[t];
    if (rows is! List) throw BackupError(BackupErrorKind.broken, t);
    final key = t == 'exchange_rates' ? 'code' : 'id';
    final list = <Map<String, Object?>>[];
    for (final r in rows) {
      if (r is! Map<String, Object?> || r[key] is! String) throw BackupError(BackupErrorKind.broken, '$t.$key');
      list.add(r);
    }
    tables[t] = list;
  }

  final ids = {
    for (final t in backupTables) t: {for (final r in tables[t]!) r['id']},
  };
  for (final MapEntry(key: table, value: refs) in backupReferences.entries) {
    for (final row in tables[table]!) {
      for (final (column, target) in refs) {
        final v = row[column];
        if (v != null && !ids[target]!.contains(v)) {
          throw BackupError(BackupErrorKind.broken, '$table.$column → $v');
        }
      }
    }
  }
  return BackupData(exportedAt: exported.toUtc(), settings: settings, tables: tables);
}
