import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database.dart';
import 'backup_codec.dart';
import 'backup_store.dart';

/// Файловая сторона копии: в приложении — [BackupFiles], в тестах — память.
abstract interface class BackupFileSystem {
  Future<String> write(String json, String isoDay);
  Future<List<String>> list();
  Future<void> share(String path);
  Future<String?> pick();
  Future<void> replaceDatabase(BackupData data, Future<void> Function() closeCurrent);
}

/// Файлы копий на iPhone (spec.md §7): `Documents/backups/`, «Поделиться»,
/// выбор файла и подмена файла базы.
class BackupFiles implements BackupFileSystem {
  const BackupFiles();

  Future<Directory> _documents() => getApplicationDocumentsDirectory();

  Future<Directory> _backups() async {
    final dir = Directory('${(await _documents()).path}/backups');
    await dir.create(recursive: true);
    return dir;
  }

  /// `fintech-backup-<YYYY-MM-DD>.json`; копия того же дня заменяется.
  @override
  Future<String> write(String json, String isoDay) async {
    final file = File('${(await _backups()).path}/fintech-backup-$isoDay.json');
    await file.writeAsString(json, flush: true);
    return file.path;
  }

  /// Прошлые копии, новые сверху. Сами не удаляются (§7).
  @override
  Future<List<String>> list() async =>
      (await _backups()).listSync().whereType<File>().map((f) => f.path).where((p) => p.endsWith('.json')).toList()
        ..sort((a, b) => b.compareTo(a));

  @override
  Future<void> share(String path) => SharePlus.instance.share(ShareParams(files: [XFile(path, mimeType: 'application/json')]));

  /// Выбор файла копии; отмена — `null`.
  @override
  Future<String?> pick() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
    if (file == null) return null;
    return utf8.decode(await file.readAsBytes());
  }

  /// Полная замена (§7): копия пишется в новый файл рядом; удалось —
  /// [closeCurrent] закрывает рабочую базу, и новый файл встаёт на её место.
  /// Ошибка до подмены оставляет рабочий файл как был.
  @override
  Future<void> replaceDatabase(BackupData data, Future<void> Function() closeCurrent) async {
    final docs = (await _documents()).path;
    final main = File('$docs/${AppDatabase.fileName}.sqlite');
    final temp = File('$docs/${AppDatabase.fileName}-restore.sqlite');
    if (temp.existsSync()) temp.deleteSync();
    final fresh = AppDatabase(NativeDatabase(temp));
    try {
      await const BackupStore().restore(fresh, data);
    } catch (_) {
      await fresh.close();
      if (temp.existsSync()) temp.deleteSync();
      rethrow;
    }
    await fresh.close();
    await closeCurrent();
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final f = File('${main.path}$suffix');
      if (f.existsSync()) f.deleteSync();
    }
    temp.renameSync(main.path);
  }
}
