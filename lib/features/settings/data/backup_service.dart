import '../../../core/calendar.dart';
import '../../../core/clock.dart';
import '../../../data/backup/backup_codec.dart';
import '../../../data/backup/backup_files.dart';
import '../../../data/backup/backup_store.dart';
import '../../../data/db/database.dart';

/// Экспорт и импорт копии для экрана «Backup» (spec.md §7, I20).
class BackupService {
  BackupService(this._db, this._clock, this._files);

  final AppDatabase _db;
  final Clock _clock;
  final BackupFileSystem _files;

  /// Копия всех таблиц в файл дня; путь — для «Поделиться».
  Future<String> export() async {
    final data = await const BackupStore().read(_db, _clock.now());
    return _files.write(encodeBackup(data), LocalDate.today(_clock).iso);
  }

  Future<List<String>> files() => _files.list();

  Future<void> share(String path) => _files.share(path);

  /// Файл от человека: `null` — отмена; битая копия — [BackupError] до
  /// какой-либо записи.
  Future<BackupData?> pick() async {
    final text = await _files.pick();
    return text == null ? null : decodeBackup(text);
  }

  /// Полная замена после подтверждения: рабочая база закрывается и
  /// подменяется; дальше приложение перезапускает своё состояние.
  Future<void> replaceAll(BackupData data) => _files.replaceDatabase(data, _db.close);
}
