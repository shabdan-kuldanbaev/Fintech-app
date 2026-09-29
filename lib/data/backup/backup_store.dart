import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/database.dart';
import 'backup_codec.dart';

/// Чтение всей базы в копию и запись копии в пустую базу (spec.md §7).
///
/// Импорт не чистит рабочую базу: копия пишется в новую пустую, и только
/// после успеха файл новой базы встаёт на место старой (`BackupFiles`).
/// Так любая ошибка оставляет данные человека нетронутыми, а удалять строки
/// физически не нужно вовсе (I2).
class BackupStore {
  const BackupStore();

  /// Все таблицы как есть, включая удалённые (`deleted_at`) строки (I20).
  Future<BackupData> read(AppDatabase db, DateTime now) async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final t in backupTables) {
      final rows = await db.customSelect('SELECT * FROM $t ORDER BY rowid').get();
      tables[t] = [for (final r in rows) Map.of(r.data)];
    }
    final settings = await db.customSelect('SELECT key, value FROM app_settings ORDER BY key').get();
    return BackupData(
      exportedAt: now.toUtc(),
      settings: {for (final r in settings) r.read<String>('key'): jsonDecode(r.read<String>('value'))},
      tables: tables,
    );
  }

  /// Запись копии в пустую базу [target] одной транзакцией. Колонки строк
  /// сверяются со схемой: незнакомая — [BackupError], ничего не записано.
  Future<void> restore(AppDatabase target, BackupData data) async {
    for (final t in [...backupTables, 'app_settings']) {
      final n = await target.customSelect('SELECT COUNT(*) AS n FROM $t').getSingle();
      if (n.read<int>('n') != 0) throw StateError('restore target is not empty: $t');
    }
    final columns = <String, Set<String>>{};
    for (final t in backupTables) {
      final info = await target.customSelect('PRAGMA table_info($t)').get();
      columns[t] = {for (final c in info) c.read<String>('name')};
      for (final row in data.tables[t]!) {
        final unknown = row.keys.where((k) => !columns[t]!.contains(k));
        if (unknown.isNotEmpty) throw BackupError(BackupErrorKind.broken, '$t.${unknown.first}');
      }
    }
    await target.transaction(() async {
      // Наступление ссылается на операцию, операция — на наступление:
      // проверка внешних ключей — в конце транзакции.
      await target.customStatement('PRAGMA defer_foreign_keys = ON');
      for (final t in backupTables) {
        for (final row in data.tables[t]!) {
          final keys = row.keys.toList();
          await target.customInsert(
            'INSERT INTO $t (${keys.join(', ')}) VALUES (${List.filled(keys.length, '?').join(', ')})',
            variables: [for (final k in keys) _variable(row[k])],
          );
        }
      }
      for (final e in data.settings.entries) {
        await target.customInsert(
          'INSERT INTO app_settings (key, value) VALUES (?, ?)',
          variables: [Variable<String>(e.key), Variable<String>(jsonEncode(e.value))],
        );
      }
    });
  }

  static Variable<Object> _variable(Object? v) => switch (v) {
    null => const Variable(null),
    final int i => Variable<int>(i),
    final String s => Variable<String>(s),
    final bool b => Variable<int>(b ? 1 : 0),
    final double d => throw BackupError(BackupErrorKind.broken, 'double $d'),
    _ => throw BackupError(BackupErrorKind.broken, '$v'),
  };
}
