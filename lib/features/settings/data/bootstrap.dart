import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/clock.dart';
import '../../../core/currencies.dart';
import '../../../core/uuid.dart';
import '../../../data/db/database.dart';
import '../../accounts/domain/account.dart';
import '../../categories/data/category_repository.dart';
import '../domain/settings.dart';

/// Первый запуск (spec.md §3.4): без экранов, одной транзакцией —
/// базовая валюта по стране устройства, счёт «Наличные», категории §3.5.
/// Повторный вызов ничего не делает.
///
/// [cashName] — имя счёта «Наличные» на языке устройства: это данные
/// пользователя, а не строка интерфейса, и потом он может его переименовать.
Future<bool> bootstrapIfNeeded(
  AppDatabase db,
  Clock clock, {
  required String? countryCode,
  required String cashName,
}) {
  return db.transaction(() async {
    final done = await (db.select(db.appSettings)
          ..where((s) => s.key.equals(SettingKeys.bootstrapDone)))
        .getSingleOrNull();
    if (done != null && jsonDecode(done.value) == true) return false;

    Future<void> put(String key, Object value) => db
        .into(db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: jsonEncode(value)),
        );

    final base = defaultCurrencyForCountry(countryCode);
    await put(SettingKeys.baseCurrency, base);

    final now = clock.now();
    final cashId = newId();
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: cashId,
        createdAt: now,
        updatedAt: now,
        name: cashName,
        kind: AccountKind.cash.db,
        currency: base,
        iconKey: 'wallet',
        colorKey: 'mint',
        sortOrder: const Value(0),
      ),
    );
    await CategoryRepository(db, clock).seedPresets();
    await put(SettingKeys.lastAccountId, cashId);
    await put(SettingKeys.bootstrapDone, true);
    return true;
  });
}
