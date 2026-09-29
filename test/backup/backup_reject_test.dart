// Чужой формат, копия новее приложения, битая ссылка — отказ до записи;
// рабочая база не тронута (I20).
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:fintech/data/backup/backup_codec.dart';
import 'package:fintech/data/backup/backup_store.dart';
import 'package:fintech/data/db/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/demo.dart';
import '../support/harness.dart';

void main() {
  late Harness h;
  late Map<String, Object?> good;
  setUp(() async {
    h = await Harness.create();
    await Demo.seed(h);
    good = jsonDecode(encodeBackup(await const BackupStore().read(h.db, h.clock.now()))) as Map<String, Object?>;
  });
  tearDown(() => h.dispose());

  Matcher fails(BackupErrorKind kind) => throwsA(isA<BackupError>().having((e) => e.kind, 'kind', kind));
  String withChange(void Function(Map<String, Object?> j) f) {
    final j = jsonDecode(jsonEncode(good)) as Map<String, Object?>;
    f(j);
    return jsonEncode(j);
  }

  test('не JSON и чужой формат', () {
    expect(() => decodeBackup('hello'), fails(BackupErrorKind.format));
    expect(() => decodeBackup('[]'), fails(BackupErrorKind.format));
    expect(() => decodeBackup(withChange((j) => j['format'] = 'jattap-backup')), fails(BackupErrorKind.format));
  });

  test('версия новее приложения — «Update the app»', () {
    expect(() => decodeBackup(withChange((j) => j['version'] = backupVersion + 1)), fails(BackupErrorKind.version));
  });

  test('нет таблицы, строка без id, ссылка в никуда', () {
    expect(() => decodeBackup(withChange((j) => j.remove('occurrences'))), fails(BackupErrorKind.broken));
    expect(
      () => decodeBackup(withChange((j) => (j['accounts']! as List).add(<String, Object?>{'name': 'x'}))),
      fails(BackupErrorKind.broken),
    );
    expect(
      () => decodeBackup(withChange((j) => ((j['transactions']! as List).first as Map)['account_id'] = 'nowhere')),
      fails(BackupErrorKind.broken),
    );
    expect(
      () => decodeBackup(withChange((j) => ((j['occurrences']! as List).first as Map)['rule_id'] = 'nowhere')),
      fails(BackupErrorKind.broken),
    );
  });

  test('незнакомая колонка — отказ, в новую базу ничего не записано', () async {
    final data = decodeBackup(withChange((j) => ((j['accounts']! as List).first as Map)['balance'] = 1));
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    await expectLater(const BackupStore().restore(fresh, data), throwsA(isA<BackupError>()));
    final n = await fresh.customSelect('SELECT COUNT(*) AS n FROM accounts').getSingle();
    expect(n.read<int>('n'), 0);
  });

  test('в непустую базу не пишет', () async {
    await expectLater(const BackupStore().restore(h.db, decodeBackup(jsonEncode(good))), throwsStateError);
  });
}
