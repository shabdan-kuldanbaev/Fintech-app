import 'dart:convert';


import '../../../data/db/database.dart';
import '../domain/settings.dart';

/// `app_settings` (spec.md §3.3): значение — JSON.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<Object?> read(String key) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row == null ? null : jsonDecode(row.value);
  }

  /// Запись одного ключа. Внутри транзакции вызывающего — в ней же.
  Future<void> write(String key, Object? value) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: jsonEncode(value)),
      );

  Future<Settings> load() async => Settings.fromMap(await _all());

  Stream<Settings> watch() => _db
      .select(_db.appSettings)
      .watch()
      .map((rows) => Settings.fromMap(_decode(rows)))
      .distinct();

  Future<Map<String, Object?>> _all() async =>
      _decode(await _db.select(_db.appSettings).get());

  static Map<String, Object?> _decode(List<AppSetting> rows) => {
    for (final r in rows) r.key: jsonDecode(r.value),
  };

  /// Следующий `notification_base_id` (I11): берётся из
  /// `notifications.next_id`, счётчик сдвигается на 8. Вызывать внутри
  /// транзакции создания правила.
  Future<int> takeNotificationBaseId() async {
    final current = await read(SettingKeys.nextNotificationId);
    final id = current is int ? current : 1000;
    await write(SettingKeys.nextNotificationId, id + 8);
    return id;
  }
}
