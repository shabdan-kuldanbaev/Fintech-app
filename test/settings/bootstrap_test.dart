import 'package:drift/native.dart';
import 'package:fintech/core/clock.dart';
import 'package:fintech/data/db/database.dart';
import 'package:fintech/features/accounts/data/account_repository.dart';
import 'package:fintech/features/accounts/domain/account.dart';
import 'package:fintech/features/categories/data/category_repository.dart';
import 'package:fintech/features/categories/domain/category.dart';
import 'package:fintech/features/settings/data/bootstrap.dart';
import 'package:fintech/features/settings/data/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final clock = FakeClock(DateTime.utc(2026, 9, 29, 12));

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('первый запуск: сом, «Наличные», категории §3.5 и корректировка', () async {
    final ran = await bootstrapIfNeeded(db, clock, countryCode: 'KG', cashName: 'Наличные');
    expect(ran, isTrue);
    final settings = await SettingsRepository(db).load();
    expect(settings.baseCurrency, 'KGS');
    final accounts = await AccountRepository(db, clock).all();
    expect(accounts, hasLength(1));
    expect(accounts.single.kind, AccountKind.cash);
    expect(accounts.single.name, 'Наличные');
    expect(accounts.single.currency, 'KGS');
    expect(settings.lastAccountId, accounts.single.id);
    final cats = await CategoryRepository(db, clock).all();
    expect(cats.where((c) => !c.isSystem), hasLength(categoryPresets.length));
    expect(cats.where((c) => c.isSystem).single.key, adjustmentKey);
    expect(cats.where((c) => c.kind == CategoryKind.income && !c.isSystem), hasLength(5));
  });

  test('повторный запуск ничего не добавляет', () async {
    await bootstrapIfNeeded(db, clock, countryCode: 'KG', cashName: 'Cash');
    final ran = await bootstrapIfNeeded(db, clock, countryCode: 'US', cashName: 'Cash');
    expect(ran, isFalse);
    expect(await AccountRepository(db, clock).all(), hasLength(1));
    expect((await SettingsRepository(db).load()).baseCurrency, 'KGS');
  });

  test('страна вне списка — доллар; еврозона — евро', () async {
    await bootstrapIfNeeded(db, clock, countryCode: 'DE', cashName: 'Cash');
    expect((await SettingsRepository(db).load()).baseCurrency, 'EUR');
    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    await bootstrapIfNeeded(other, clock, countryCode: null, cashName: 'Cash');
    expect((await SettingsRepository(other).load()).baseCurrency, 'USD');
  });

  test('notification_base_id идёт шагом 8 от 1000 (I11)', () async {
    final s = SettingsRepository(db);
    expect(await s.takeNotificationBaseId(), 1000);
    expect(await s.takeNotificationBaseId(), 1008);
  });
}
