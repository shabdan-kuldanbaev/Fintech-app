import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:fintech/data/db/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Set<String>> names(String type) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = '$type'")
        .get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('все таблицы §3.1 созданы', () async {
    expect(
      await names('table'),
      containsAll([
        'accounts',
        'categories',
        'transactions',
        'recurring_rules',
        'occurrences',
        'budgets',
        'exchange_rates',
        'app_settings',
      ]),
    );
  });

  test('все индексы §3.2 созданы', () async {
    final expected = AppDatabase.indexStatements
        .map((s) => RegExp(r'INDEX (\w+) ON').firstMatch(s)!.group(1)!)
        .toSet();
    expect(expected, hasLength(8));
    expect(await names('index'), containsAll(expected));
  });

  test('внешние ключи включены', () async {
    final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(row.data.values.first, 1);
  });

  test('первичные ключи — TEXT, без автоинкремента (I1)', () async {
    final rows = await db
        .customSelect("SELECT sql FROM sqlite_master WHERE type = 'table'")
        .get();
    for (final r in rows) {
      final sql = r.read<String?>('sql') ?? '';
      expect(sql.toUpperCase(), isNot(contains('AUTOINCREMENT')));
    }
  });

  test('моменты хранятся unix-секундами (I5)', () async {
    final t = DateTime.utc(2026, 9, 29, 12);
    await db.into(db.exchangeRates).insert(
      ExchangeRatesCompanion.insert(
        code: 'USD',
        rateMicro: 87450000,
        source: 'manual',
        updatedAt: t,
      ),
    );
    final raw = await db
        .customSelect('SELECT updated_at FROM exchange_rates')
        .getSingle();
    expect(raw.read<int>('updated_at'), t.millisecondsSinceEpoch ~/ 1000);
    final read = await db.select(db.exchangeRates).getSingle();
    expect(read.updatedAt.toUtc(), t);
  });

  test('уникальность (rule_id, due_date) только среди живых наступлений', () async {
    final now = DateTime.utc(2026, 9, 29);
    await db.into(db.recurringRules).insert(
      RecurringRulesCompanion.insert(
        id: 'r1',
        createdAt: now,
        updatedAt: now,
        name: 'Rent',
        kind: 'other',
        currency: 'KGS',
        frequency: 'monthly',
        startDate: '2026-10-01',
        notificationBaseId: 1000,
        iconKey: 'housing',
        colorKey: 'lavender',
      ),
    );
    OccurrencesCompanion occ(String id, {DateTime? deletedAt}) =>
        OccurrencesCompanion.insert(
          id: id,
          createdAt: now,
          updatedAt: now,
          deletedAt: Value(deletedAt),
          ruleId: 'r1',
          seq: 1,
          dueDate: '2026-10-01',
          currency: 'KGS',
        );
    await db.into(db.occurrences).insert(occ('o1', deletedAt: now));
    await db.into(db.occurrences).insert(occ('o2'));
    await expectLater(
      db.into(db.occurrences).insert(occ('o3')),
      throwsA(isA<SqliteException>()),
    );
  });
}
