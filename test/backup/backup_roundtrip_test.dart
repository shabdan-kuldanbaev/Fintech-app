// Экспорт → импорт в пустую базу → те же строки, включая удалённые (I20).
import 'package:drift/drift.dart' show QueryRow;
import 'package:drift/native.dart';
import 'package:fintech/data/backup/backup_codec.dart';
import 'package:fintech/data/backup/backup_store.dart';
import 'package:fintech/data/db/database.dart';
import 'package:fintech/features/transactions/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/demo.dart';
import '../support/harness.dart';

Future<List<Map<String, Object?>>> dump(AppDatabase db, String table) async =>
    [for (final QueryRow r in await db.customSelect('SELECT * FROM $table ORDER BY ${table == 'app_settings' ? 'key' : 'rowid'}').get()) r.data];

void main() {
  test('все таблицы и настройки — строка в строку, deleted_at тоже', () async {
    final h = await Harness.create();
    addTearDown(h.dispose);
    final d = await Demo.seed(h);
    await h.rules.payAsExpected(d.internetOccurrence);
    final victim = (await h.transactions.list(const TxnFilter())).firstWhere((t) => t.occurrenceId == null);
    await h.transactions.delete(victim.id); // soft — строка остаётся

    const store = BackupStore();
    final json = encodeBackup(await store.read(h.db, h.clock.now()));
    final copy = decodeBackup(json);

    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    await store.restore(fresh, copy);

    for (final t in [...backupTables, 'app_settings']) {
      expect(await dump(fresh, t), await dump(h.db, t), reason: t);
    }
    final deleted = await fresh.customSelect(
      'SELECT COUNT(*) AS n FROM transactions WHERE deleted_at IS NOT NULL',
    ).getSingle();
    expect(deleted.read<int>('n'), greaterThan(0));
    expect(copy.tables['occurrences']!.any((o) => o['status'] == 'paid'), isTrue);
  });
}
