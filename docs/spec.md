# Fintech — Specification v1

Формат: спецификация для исполнителя (Claude Code). Правила используют MUST / MUST NOT / SHOULD / MAY.
Идентификаторы (имена таблиц, колонок, файлов, параметров) — только латиницей, ровно как написано.
При конфликте между разделами приоритет: §1 Инварианты > §3 Схема > остальные.

Решения заказчика 2026-09-29, на которых стоит документ: (1) полноценное приложение, не MVP-огрызок:
расходы, доходы, обязательства, бюджеты, накопления; (2) любая валюта; (3) кредит — простая модель
(платёж, день, остаток), без банковской процентной математики; (4) дизайн и структура — как во
Flashcards (Jattap), простота и доступность интерфейса — как в Simbank (скриншоты 2026-09-29, §8.0);
(5) напоминания за 3 дня и в день платежа плюс дневная сводка; (6) бюджеты сразу; (7) резервная копия —
JSON, вход по Face ID; (8) интерфейс английский и русский, название придумывается позже; (9) только iOS;
(10) процесс — как во Flashcards: спецификация первична, протокол §13.

---

## 0. Контекст

- Приложение: личные финансы одного человека. Учёт расходов и доходов по счетам, календарь
  обязательных платежей (кредиты, кредитные линии, подписки, коммуналка), бюджеты по категориям,
  накопления, напоминания.
- Платформа: Flutter, iOS (сборка через Xcode). Android не требуется, но код MUST NOT содержать
  iOS-only зависимостей без `Platform` проверки.
- Один пользователь. Локальная база. Сервера, авторизации, синхронизации, подключения к банкам нет
  и быть не может: в Кыргызстане нет открытого банковского API для частных приложений, iOS не даёт
  читать СМС. Весь ввод ручной, поэтому быстрый ввод расхода — главный сценарий (§8, «Add expense»).
- Единый источник правды — **транзакции** (`transactions`). Балансы счетов, остаток долга, «потрачено
  за месяц», прогресс копилки — всё выводится из транзакций, нигде не хранится отдельно (I3).
- Обязательство — **правило** (`recurring_rules`), которое порождает **наступления** (`occurrences`).
  Оплата наступления создаёт транзакцию. Так кредиты, подписки и коммуналка попадают в статистику
  расходов без двойного ввода.
- Рабочее имя пакета — `fintech` (внутренний идентификатор, как `flashcards` у Jattap). Название в
  App Store, отображаемое имя и bundle id заказчик выберет позже; до тех пор bundle id
  `com.shabdan.fintech`.
- Язык интерфейса — английский и русский (§8.1). Документация — русская.

Критерий готовности v1: все пункты §11 выполнены, `tool/verify.sh` зелёный.

---

## 1. Инварианты (MUST)

| # | Правило |
|---|---|
| I1 | Все первичные ключи — UUID v4, тип `TEXT`. `autoIncrement` MUST NOT использоваться. |
| I2 | Таблицы `accounts`, `categories`, `transactions`, `recurring_rules`, `occurrences`, `budgets` имеют `created_at`, `updated_at`, `deleted_at`. Удаление — только `deleted_at = now`. Физический `DELETE` MUST NOT выполняться. Восстановление из копии (§7) заменяет файл базы целиком, а не чистит таблицы. |
| I3 | Баланс счёта, остаток долга, доступный лимит, прогресс копилки, «потрачено» — только вычисления над `transactions` (§9). Колонки с текущим балансом MUST NOT существовать. Ручная правка баланса — обычная транзакция с системной категорией `adjustment` (§3.4). |
| I4 | Деньги — целые в минимальных единицах валюты (`int`, тыйыны/центы) плюс код ISO 4217 (`TEXT`). `double` MUST NOT храниться и MUST NOT участвовать в сложении сумм. Единственное исключение — оценка платежа по кредиту в `loan_math.dart` (§4.3): результат округляется до `int` немедленно и показывается как предложение, которое пользователь может изменить. |
| I5 | Моменты времени (`created_at`, `updated_at`, `deleted_at`, `paid_at`, `rates.updated_at`) — UTC unix-секунды через `dateTime()` Drift. Drift возвращает их как локальные: после чтения всегда `.toUtc()`, перед записью `isUtc == true`. Опция `store_date_time_values_as_text` MUST NOT включаться. |
| I6 | Календарные даты (`transactions.date`, `occurrences.due_date`, `recurring_rules.start_date`/`end_date`, `budgets.from_month`) — `TEXT` в формате ISO `YYYY-MM-DD` (`YYYY-MM` для месяца) по **локальному календарю пользователя**. Сравнение — лексикографическое. «Сегодня» — `Clock.now()` → локальная дата (`core/calendar.dart`). Дата платежа — не момент, а день: границы дня 04:00, как во Flashcards, здесь нет. |
| I7 | Календарная арифметика (следующее наступление, 31-е → последний день короткого месяца, високосный год) — только `core/calendar.dart` и `features/payments/domain/schedule.dart`, без I/O. Другие места MUST NOT считать даты сами. |
| I8 | `transactions.currency` MUST равняться `accounts.currency` счёта `account_id`. У перевода `counter_amount` — в валюте `counter_account_id`; при одинаковой валюте `counter_amount == amount`. `base_amount` — снимок в базовой валюте на момент записи; пересчитывается только при смене базовой валюты (§4.2), одной транзакцией по всем строкам. |
| I9 | Оплата наступления — одна транзакция БД: `INSERT transactions` + `UPDATE occurrences (status, transaction_id, paid_at)`. Отмена оплаты — тоже одна: транзакция помечается `deleted_at`, наступление возвращается в `planned`. Удаление транзакции, связанной с наступлением, MUST идти через отмену оплаты. |
| I10 | Наступления материализуются строками (§5.2), не вычисляются на лету. Среди неудалённых наступлений одного правила `due_date` уникален. Перепланирование правила MUST NOT трогать наступления со статусом `paid` и `skipped`. Автооплаты без явного `auto_pay = 1` у правила не бывает. |
| I11 | Уведомления — только одноразовые `zonedSchedule` без `matchDateTimeComponents`. Идентификаторы: сводка — `1..7`; правило — `recurring_rules.notification_base_id + k`, `k = 0..7`, `notification_base_id` берётся только из `app_settings['notifications.next_id']` с шагом 8. `String.hashCode` MUST NOT использоваться. Одновременно запланировано ≤ 64 (§6). |
| I12 | Сеть используется только в `lib/data/rates/` (курсы валют, §4.2) и только при открытии экрана «Currencies» или по кнопке «Refresh». Остальной код MUST работать без сети. Никаких аналитик, крашлитиков, рекламы. |
| I13 | Presentation-слой MUST NOT импортировать `package:drift` или сгенерированные Drift-классы. Только доменные модели через репозитории. |
| I14 | Все видимые пользователю строки — из `AppLocalizations` (ARB `en` и `ru`, §8.1). Строковые литералы с буквами внутри `Text(...)`, `label:`, `hintText:`, `title:` и в текстах уведомлений в `lib/` MUST NOT встречаться. Оба ARB MUST иметь одинаковый набор ключей (страж). |
| I15 | Статистика, бюджеты и «потрачено за месяц» считают: расходы (`kind = 'expense'`) плюс переводы на счета вида `loan` (платёж по кредиту — это трата месяца). Переводы на `credit_line` MUST NOT считаться тратой (покупка по карте уже учтена как расход при покупке). Переводы на `savings`/`deposit` — «отложено», не трата. Транзакции системной категории `adjustment` в статистику MUST NOT попадать. Только `deleted_at IS NULL`. |
| I16 | Цвета, кегли и шрифты — только `app/theme.dart` (палитра Jattap, §8.0). Встроенные системные вью (`UiKitView`, `cupertino_native` и подобные) MUST NOT использоваться — та же причина, что во Flashcards (flutter/flutter#182662). |
| I17 | Буфер обмена MUST NOT читаться программно (`Clipboard.getData`). Вставка — только штатным меню поля. |
| I18 | Биометрия (`local_auth`) вызывается только из `lib/features/security/`. Замок — экран поверх приложения (§8, «Lock»), а не шифрование: база лежит в песочнице приложения открытой, и это записано в README как ограничение. |
| I19 | Кредитная математика (§4.3) — только `features/accounts/domain/loan_math.dart`, без I/O. |
| I20 | Резервная копия (§7): экспорт пишет все таблицы, включая `deleted_at`-строки; импорт — только полная замена после явного подтверждения, версия формата проверяется до записи. Частичного слияния нет. |

---

## 2. Зависимости

`pubspec.yaml`. Версии — последняя стабильная на pub.dev на момент `flutter pub add`.

```
dependencies: flutter_localizations (sdk), intl, flutter_riverpod, riverpod_annotation, go_router,
              drift, drift_flutter, flutter_local_notifications, timezone, flutter_timezone,
              uuid, path_provider, dio, local_auth, share_plus, file_picker, xml
dev_dependencies: drift_dev, build_runner, riverpod_generator, flutter_test (sdk)
```

- `sqlite3_flutter_libs` не добавлять отдельно: `drift_flutter` зависит от него.
- `flutter_secure_storage`, `image_picker`, `fsrs`, `crypto` из Flashcards не нужны.
- `dio` — только `lib/data/rates/` (I12). `xml` — разбор ответа НБКР (§4.2).
- `share_plus` — отдать файл копии через системный share sheet; `file_picker` — выбрать файл копии для импорта. Оба — плагины без встроенных вью (I16).
- `local_auth` — Face ID / Touch ID; `Info.plist` MUST содержать `NSFaceIDUsageDescription`.
- Пакеты с ломающимися API (проверено во Flashcards, здесь то же): `flutter_timezone` ≥ 5 — `getLocalTimezone()` возвращает `TimezoneInfo`, IANA-строка в `.identifier`; `flutter_local_notifications` ≥ 19 — `androidScheduleMode` обязателен даже для iOS, `uiLocalNotificationDateInterpretation` не существует, классы `DarwinInitializationSettings`/`DarwinNotificationDetails`/`IOSFlutterLocalNotificationsPlugin`.
- Локализация: `flutter gen-l10n` через `l10n.yaml` (`arb-dir: lib/l10n`, `template-arb-file: app_en.arb`, `output-localization-file: app_localizations.dart`, `synthetic-package: false`). Форматирование чисел и дат — `intl` (`NumberFormat`, `DateFormat`) с локалью приложения.

### 2.1 Что переносится из Flashcards дословно (этап 1)

Из репозитория `Flashcards-1.0` копируются и адаптируются (имя пакета, пути):
- `lib/app/theme.dart` (палитра, `AppColors`, `AppRadius`, `AppSizes`, шрифт Outfit и его файлы из `assets/fonts/`), `lib/app/widgets/glass.dart` (`GlassPanel`, `ActionBar`, `GlassNavBar`, `GlassIconButton`, `GlassMenuButton`), `lib/app/startup_gate.dart`, `lib/core/clock.dart`, `lib/core/uuid.dart`, `lib/core/error_reporting.dart`, `lib/core/timezone_setup.dart`, `lib/features/notifications/` (шлюз `NotificationGateway` и обвязка `NotificationTaps`), `ios/Runner/AppDelegate.swift` (делегат центра уведомлений — §6).
- `tool/verify.sh`, `tool/tree_hash.sh`, `tool/commit_gate.sh`, `tool/edit_guard.sh`, `tool/session_context.sh`, `tool/screenshots.sh`, `tool/verify_shots.sh`; `.claude/settings.json`, `.claude/skills/{verify,invariants,shots,wave}`, `.claude/agents/{auditor,wave-writer}.md`; `test/architecture/invariants_test.dart` как каркас стражей (список I1–I20 — этого документа); `test/app/theme_test.dart` (замеры контраста).
- `docs/rules/` и `docs/learn/` — правила и учебник процесса, без изменений по сути.

Не переносятся: всё про FSRS, сессии, рукописный ввод, библиотеку паков, AI.

### 2.2 iOS-конфигурация

`ios/Runner/Info.plist` MUST содержать `NSFaceIDUsageDescription`. Capability Push Notifications не нужна (только локальные уведомления). `UNUserNotificationCenter.current().delegate = self` в `AppDelegate` до `super` — как во Flashcards (§6). `CFBundleLocalizations`: `en`, `ru`.

---

## 3. Схема данных

### 3.1 `lib/data/db/tables.dart`

```dart
import 'package:drift/drift.dart';

mixin SyncableTable on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Счёт. Актив (cash, card, savings, deposit) или пассив (credit_line, loan).
/// Баланс не хранится (I3): balance = opening_balance + Σ transactions (§9.1).
/// Для пассива баланс ≤ 0, долг = -balance.
class Accounts extends Table with SyncableTable {
  TextColumn get name => text()();
  TextColumn get kind => text()();                        // 'cash'|'card'|'credit_line'|'loan'|'savings'|'deposit'
  TextColumn get currency => text()();                    // ISO 4217, напр. "KGS"
  IntColumn get openingBalance => integer().withDefault(const Constant(0))(); // минимальные единицы; loan: -total_payable на старте
  IntColumn get creditLimit => integer().nullable()();    // credit_line: лимит; иначе null
  IntColumn get dueDay => integer().nullable()();         // credit_line: день месяца оплаты 1..28; иначе null
  // --- loan (простая модель, §4.3) ---
  IntColumn get principal => integer().nullable()();      // сколько взяли
  IntColumn get totalPayable => integer().nullable()();   // сколько всего вернуть (Simbank «Итого»)
  IntColumn get monthlyPayment => integer().nullable()();
  IntColumn get termMonths => integer().nullable()();
  IntColumn get rateBp => integer().nullable()();         // ставка в базисных пунктах (2.24 % = 224); только для показа
  TextColumn get ratePeriod => text().nullable()();       // 'month'|'year'
  TextColumn get firstPaymentDate => text().nullable()(); // YYYY-MM-DD
  // --- savings / deposit ---
  IntColumn get targetAmount => integer().nullable()();   // savings: цель копилки
  TextColumn get targetDate => text().nullable()();       // savings: срок цели; deposit: дата окончания
  // --- оформление и порядок ---
  TextColumn get iconKey => text()();                     // ключ из core/icons.dart
  TextColumn get colorKey => text()();                    // 'lavender'|'mint'|'butter'|'blush'|'sky'
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get includeInTotal => boolean().withDefault(const Constant(true))(); // участвует в «Own funds»
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

/// Категория расхода или дохода. Один уровень, без вложенности.
/// Предустановленная: key != null, name == null → имя из ARB по ключу; переименованная — name != null.
class Categories extends Table with SyncableTable {
  TextColumn get key => text().nullable()();              // 'groceries', 'transport', … (§3.5); null — своя
  TextColumn get name => text().nullable()();
  TextColumn get kind => text()();                        // 'expense'|'income'
  TextColumn get iconKey => text()();
  TextColumn get colorKey => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))(); // 'adjustment' — не показывается в выборе
  @override
  Set<Column> get primaryKey => {id};
}

/// Транзакция. amount > 0 всегда; знак задаёт kind.
class Transactions extends Table with SyncableTable {
  TextColumn get kind => text()();                        // 'expense'|'income'|'transfer'
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get counterAccountId => text().nullable().references(Accounts, #id)(); // только transfer
  IntColumn get amount => integer()();                    // в валюте account_id, > 0
  TextColumn get currency => text()();                    // == accounts.currency (I8)
  IntColumn get counterAmount => integer().nullable()();  // transfer: в валюте counter_account_id
  IntColumn get baseAmount => integer()();                // снимок в базовой валюте (I8)
  TextColumn get categoryId => text().nullable().references(Categories, #id)(); // expense/income: обязателен; transfer: null
  TextColumn get occurrenceId => text().nullable()();     // оплата наступления (I9); FK не объявляется: occurrences ссылается сюда
  TextColumn get date => text()();                        // YYYY-MM-DD, локальный календарь (I6)
  TextColumn get note => text().nullable()();             // «Magazin Yrysky», «за сентябрь»
  @override
  Set<Column> get primaryKey => {id};
}

/// Правило обязательства: порождает наступления (§5).
class RecurringRules extends Table with SyncableTable {
  TextColumn get name => text()();
  TextColumn get kind => text()();                        // 'subscription'|'utility'|'loan_payment'|'credit_line_payment'|'other'
  TextColumn get accountId => text().nullable().references(Accounts, #id)();        // откуда платить; null — спросить при оплате
  TextColumn get counterAccountId => text().nullable().references(Accounts, #id)(); // loan_payment / credit_line_payment: счёт-пассив
  TextColumn get categoryId => text().nullable().references(Categories, #id)();     // subscription/utility/other: обязателен
  IntColumn get amount => integer().nullable()();         // null — сумма неизвестна заранее (коммуналка)
  TextColumn get currency => text()();
  TextColumn get frequency => text()();                   // 'monthly'|'weekly'|'yearly'|'every_n_days'
  IntColumn get interval => integer().withDefault(const Constant(1))(); // every_n_days: n; monthly: каждые n месяцев
  IntColumn get dayOfMonth => integer().nullable()();     // monthly/yearly: 1..31, >28 прижимается к концу месяца (§5.1)
  TextColumn get startDate => text()();                   // первое наступление, YYYY-MM-DD
  TextColumn get endDate => text().nullable()();          // последнее наступление включительно; loan_payment: обязателен
  TextColumn get remindDaysBefore => text().withDefault(const Constant('[3,0]'))(); // JSON int[]
  IntColumn get remindMinutes => integer().nullable()();  // минуты от 00:00 локального; null — app_settings 'notifications.default_minutes'
  IntColumn get notificationBaseId => integer()();        // app_settings 'notifications.next_id', шаг 8 (I11)
  BoolColumn get autoPay => boolean().withDefault(const Constant(false))(); // подписка списывается сама: наступление помечается paid в день due (§5.3)
  BoolColumn get isPaused => boolean().withDefault(const Constant(false))();
  TextColumn get iconKey => text()();
  TextColumn get colorKey => text()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Наступление правила: конкретная дата и сумма к оплате.
class Occurrences extends Table with SyncableTable {
  TextColumn get ruleId => text().references(RecurringRules, #id)();
  IntColumn get seq => integer()();                       // порядковый номер в правиле, с 1 («payment 3 of 24»)
  TextColumn get dueDate => text()();                     // YYYY-MM-DD
  IntColumn get amountExpected => integer().nullable()(); // null — ввести при оплате
  TextColumn get currency => text()();
  TextColumn get status => text().withDefault(const Constant('planned'))(); // 'planned'|'paid'|'skipped'
  TextColumn get transactionId => text().nullable().references(Transactions, #id)();
  DateTimeColumn get paidAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Бюджет на месяц по категории (category_id = null — общий). Действует с from_month
/// до следующей строки той же категории: история сохраняется (§9.4).
class Budgets extends Table with SyncableTable {
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get fromMonth => text()();                   // YYYY-MM
  IntColumn get amount => integer()();                    // в базовой валюте
  @override
  Set<Column> get primaryKey => {id};
}

/// Курс: 1 единица code = rate_micro / 1e6 единиц базовой валюты (§4.2).
class ExchangeRates extends Table {
  TextColumn get code => text()();
  IntColumn get rateMicro => integer()();
  TextColumn get source => text()();                      // 'manual'|'nbkr'
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {code};
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();                       // JSON
  @override
  Set<Column> get primaryKey => {key};
}
```

### 3.2 `lib/data/db/database.dart`

```dart
@DriftDatabase(tables: [Accounts, Categories, Transactions, RecurringRules, Occurrences, Budgets, ExchangeRates, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'fintech'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement('CREATE INDEX idx_tx_account_date ON transactions(account_id, date) WHERE deleted_at IS NULL');
          await customStatement('CREATE INDEX idx_tx_counter ON transactions(counter_account_id) WHERE deleted_at IS NULL');
          await customStatement('CREATE INDEX idx_tx_date ON transactions(date) WHERE deleted_at IS NULL');
          await customStatement('CREATE INDEX idx_tx_category_date ON transactions(category_id, date) WHERE deleted_at IS NULL');
          await customStatement('CREATE INDEX idx_tx_occurrence ON transactions(occurrence_id)');
          await customStatement('CREATE UNIQUE INDEX idx_occ_rule_due ON occurrences(rule_id, due_date) WHERE deleted_at IS NULL');
          await customStatement('CREATE INDEX idx_occ_status_due ON occurrences(status, due_date) WHERE deleted_at IS NULL');
          await customStatement('CREATE INDEX idx_budgets_cat_month ON budgets(category_id, from_month) WHERE deleted_at IS NULL');
        },
        beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
      );
}
```

Тесты открывают `AppDatabase(NativeDatabase.memory())`.

**Одна инициализирующая миграция**, как во Flashcards: до релиза любое изменение `tables.dart`
дописывается в `onCreate`, `schemaVersion` остаётся `1`, приложение на устройстве переустанавливается.
После релиза — `schemaVersion + 1` и шаг `onUpgrade`.

### 3.3 Ключи `app_settings` (value — JSON)

| key | тип | дефолт |
|---|---|---|
| `base_currency` | `string` ISO 4217 | по стране локали устройства: `KG → KGS`, `RU → RUB`, `KZ → KZT`, `US → USD`, `EU-страны → EUR`; иначе `USD`. Спрашивается на онбординге (§8) |
| `locale` | `"system" \| "en" \| "ru"` | `"system"` |
| `onboarding_done` | `bool` | `false` |
| `notifications.next_id` | `int` | `1000` |
| `notifications.default_minutes` | `int` | `600` (10:00) |
| `notifications.digest_enabled` | `bool` | `true` |
| `notifications.digest_minutes` | `int` | `540` (09:00) |
| `lock.enabled` | `bool` | `false` |
| `lock.after_seconds` | `int` | `60` |
| `rates.last_fetch` | `string \| null` — ISO-8601 UTC | `null` |
| `default_account_id` | `string \| null` — счёт по умолчанию в «Add expense» | первый созданный |
| `home.month_start_day` | `int` 1..28 — с какого числа считается «месяц» на Главной и в бюджетах (зарплата 5-го) | `1` |

### 3.4 Инварианты данных при записи (репозиторий)

- **Первый запуск** (`onboarding_done = false`, §8 «Onboarding»): в одной транзакции — счёт `Cash` (`kind = 'cash'`, базовая валюта, `iconKey = 'wallet'`, `colorKey = 'mint'`), системная категория `adjustment` (`kind = 'expense'`, `isSystem = 1`) и предустановленные категории §3.5. `default_account_id = Cash`.
- **Транзакция** (`createTransaction` / `updateTransaction`): `amount > 0`; `currency = accounts.currency`; `expense`/`income` требуют `category_id` того же `kind` (для `adjustment` — любой kind); `transfer` требует `counter_account_id != account_id`, `category_id = null`, `counter_amount` (равен `amount` при одной валюте; при разных — обязателен явно, конвертер §4.2 лишь подсказывает); `base_amount = toBase(amount, currency)` (§4.2) на момент записи. Иначе — исключение, ничего не пишется.
- **Удаление транзакции**: `deleted_at = now`. Если `occurrence_id != null` — MUST идти через `unpayOccurrence` (I9).
- **Счёт**: `kind` из списка §3.1; `credit_line` требует `credit_limit > 0` и `due_day`; `loan` требует `total_payable > 0`, `monthly_payment > 0`, `term_months ≥ 1`, `first_payment_date`; `opening_balance` для `loan` = `-total_payable`, для `credit_line` = `-текущий долг` (вводится при создании, обычно 0). Смена `currency` у счёта с транзакциями MUST быть запрещена.
- **Создание кредита** (`createLoan`, одна транзакция): счёт `loan` + правило `loan_payment` (`frequency = 'monthly'`, `day_of_month` = день `first_payment_date`, `start_date = first_payment_date`, `end_date = start + (term_months − 1) месяцев`, `amount = monthly_payment`, `counter_account_id = loan`, `category_id = null`, `auto_pay = 0`) + все `term_months` наступлений сразу (§5.2), `seq = 1..n`. Последнее наступление получает `amount_expected = total_payable − monthly_payment × (n − 1)`, чтобы сумма графика совпала с `total_payable` тыйын в тыйын.
- **Создание кредитной линии** (`createCreditLine`, одна транзакция): счёт `credit_line` + правило `credit_line_payment` (`monthly`, `day_of_month = due_day`, `amount = null`, `counter_account_id` = этот счёт, `start_date` = ближайшая дата с этим днём > сегодня).
- **Оплата наступления** (`payOccurrence(occurrenceId, amount, accountId, date)`, I9): наступление `planned` → создать транзакцию: для `loan_payment`/`credit_line_payment` — `transfer` с `account_id = accountId`, `counter_account_id = rule.counter_account_id`; иначе — `expense` с `category_id = rule.category_id`; `occurrence_id` = это наступление; `date` = переданная (по умолчанию сегодня); затем `UPDATE occurrences SET status = 'paid', transaction_id, paid_at = now`. Сумма — введённая; при `amount_expected != null` предзаполняется.
- **Отмена оплаты** (`unpayOccurrence`): транзакция → `deleted_at`, наступление → `planned`, `transaction_id = null`, `paid_at = null`. Одна транзакция БД.
- **Пропуск**: `status = 'skipped'`. Обратно — `planned`.
- **Правило**: правка полей расписания → `replanRule` (§5.2). `is_paused = 1` → новые наступления не создаются, существующие `planned` с `due_date > сегодня` помечаются `deleted_at`.
- **Удаление правила**: `deleted_at` у правила и всех его `planned` наступлений; `paid`/`skipped` и их транзакции остаются. Удаление счёта `loan`/`credit_line`: удаляет (soft) и связанное правило по тем же правилам; счёт с транзакциями удалять MUST быть запрещено — только архив (`is_archived = 1`).
- **Бюджет** (`setBudget(categoryId, month, amount)`): существует строка с тем же `category_id` и `from_month` → `UPDATE amount`; иначе `INSERT`. `amount = 0` → строка помечается `deleted_at` (бюджет снят с этого месяца).
- **Курсы**: `upsertRate(code, rateMicro, source)`. Смена базовой валюты (§4.2) — одна транзакция: пересчёт всех `rates`, `base_amount` всех транзакций, `budgets.amount`.

### 3.5 Предустановленные категории

Расходы (`kind = 'expense'`), в этом порядке: `groceries` (корзина, mint), `cafe` (чашка, butter), `transport` (автобус, sky), `taxi` (такси, sky), `housing` (дом, lavender), `utilities` (лампочка, lavender), `phone` (телефон, sky), `subscriptions` (повтор, lavender), `health` (сердце, blush), `clothes` (футболка, butter), `entertainment` (билет, butter), `education` (книга, sky), `gifts` (подарок, blush), `travel` (самолёт, mint), `kids` (игрушка, butter), `pets` (лапа, mint), `other_expense` (точки, lavender).
Доходы (`kind = 'income'`): `salary` (портфель, mint), `freelance` (ноутбук, sky), `gift_income` (подарок, blush), `interest` (процент, mint), `other_income` (точки, lavender).
Имена — ключи ARB `category_<key>`; иконки — ключи `core/icons.dart` (карта ключ → `IconData` Material, единственное место).

---

## 4. Деньги, валюты, кредит

### 4.1 `core/money.dart` (без I/O)

- `Money(int minor, String currency)`; сложение/вычитание только при одинаковой валюте, иначе `ArgumentError`.
- `minorUnits(code)`: `KGS 2, USD 2, EUR 2, RUB 2, KZT 2, UZS 2, TRY 2, CNY 2, GBP 2, JPY 0, KRW 0` и полный список ISO 4217 в `core/currencies.dart`; неизвестный код → 2.
- `parseAmount(String text, String currency) → int?`: принимает `1234`, `1 234,50`, `1,234.50`, `1234.5`; разделитель — последний из `.`/`,`, если после него ≤ `minorUnits` цифр; без `double`. Больше знаков после разделителя, чем `minorUnits` → `null`.
- `formatAmount(int minor, String currency, Locale)`: `NumberFormat` с группировкой по локали (ru: `1 234,50`, en: `1,234.50`), символ валюты — из `core/currencies.dart` (`KGS → "сом"` в ru и `"som"` в en; `USD → "$"`, `EUR → "€"`, `RUB → "₽"`, `KZT → "₸"`; иначе код). Глиф `⃀` (U+20C0) не используется, пока §12.1 не подтвердит его отрисовку на устройстве. Крупная сумма в hero (§8): целая часть кеглем `display`, дробная — на ступень меньше, как в Simbank.

### 4.2 Курсы и базовая валюта (`lib/data/rates/`, `features/currencies/`)

- Базовая валюта `base_currency` — валюта Главной, статистики, бюджетов. Счета могут быть в любой.
- `toBase(amount, currency)`: `currency == base` → `amount`; иначе `amount × rate_micro(currency) / 1e6` в минимальных единицах базовой, округление half-up, целочисленно. Нет курса → `MissingRate(currency)`: репозиторий требует ввести курс до записи транзакции (форма показывает поле курса).
- Источник курсов: `lib/data/rates/nbkr_client.dart` — GET `https://www.nbkr.kg/XML/daily.xml` (официальные курсы НБКР к сому; формат и точный URL проверяются в §12.2). Разбор `xml`. Курс к базовой: через сом как pivot: `rate(X→base) = rate(X→KGS) / rate(base→KGS)`, `rate(KGS→KGS) = 1`. Если базовая валюта не в списке НБКР — сеть бесполезна, только ручной ввод.
- Загрузка — только при открытии экрана «Currencies» (если `rates.last_fetch` старше 24 ч) и по кнопке «Refresh» (I12). Ручной курс (`source = 'manual'`) сетью MUST NOT перезаписываться.
- Смена базовой валюты (одна транзакция БД, §3.4): новый `rate_micro'(X) = rate_micro(X) / rate_micro(newBase) × 1e6`, для старой базы — `1e6 / rate_micro(newBase) × 1e6`; `base_amount` каждой транзакции — заново из `amount` и нового курса её валюты; `budgets.amount` — через старый курс новой базы. Нет курса новой базы → операция запрещена с подсказкой ввести курс.

### 4.3 Кредит: простая модель (`features/accounts/domain/loan_math.dart`, без I/O)

- Пользователь вводит: сумму `principal`, число месяцев `n`, ставку (в месяц или в год; MAY пропустить). Экран «New loan» повторяет Simbank (§8): «N months × payment», под ним «Total».
- Оценка: ставка задана → аннуитет `payment = P·r / (1 − (1 + r)^−n)`, где `r` — месячная ставка (`rate_bp / 10000`, для годовой — `/ 12`); `double` только здесь (I4), результат округляется half-up до минимальной единицы; `total = payment × n`. Ставка не задана → пользователь вводит `monthly_payment` или `total_payable` сам, второе считается. Ставка `0` → `payment = ceil(P / n)`.
- Всё вычисленное — только предложение: оба поля редактируемы, сохраняется то, что в полях. Банки считают дни и комиссии по-своему; приложение не претендует на точность до тыйына, а `remaining = −balance` (§9.1) опирается на введённое `total_payable`.
- Досрочное погашение: перевод на счёт `loan` любой суммой. Уменьшился долг — «Recalculate schedule» на экране кредита: оставшиеся `planned` наступления пересчитываются равными долями остатка (последняя добирает копейки), их число — по выбору «keep payment» (меньше платежей) или «keep term» (меньше платёж). Без I/O в `loan_math.dart`, запись — репозиторий.

---

## 5. Обязательства: правила и наступления

### 5.1 Расписание (`features/payments/domain/schedule.dart`, без I/O)

`nextDates(rule, fromDate, untilDate) → List<String>`:
- `monthly`, `interval = m`: месяц `start_date` + k·m, день `day_of_month` (по умолчанию день `start_date`); если в месяце дней меньше — последний день месяца (31 января → 28/29 февраля → 31 марта: отсчёт всегда от `day_of_month`, а не от предыдущей даты, иначе день «уползает»).
- `weekly`: `start_date + 7·k·interval` дней.
- `yearly`: та же дата ежегодно; 29 февраля → 28 февраля в невисокосный.
- `every_n_days`: `start_date + n·k`.
- Не раньше `start_date`, не позже `end_date` (если задан), `is_paused = 0`.
- Перенос с выходных и праздников не делается (решение: банки Кыргызстана списывают по календарю; вне v1 — §14).

### 5.2 Материализация (`OccurrencePlanner.replan`, репозиторий)

Вызывается при старте приложения, после создания/правки/паузы/удаления правила, после смены даты (полночь по локальному времени — при следующем возвращении в приложение), после оплаты/отмены оплаты.
1. Горизонт: `loan_payment` — весь срок (`end_date` обязателен, ≤ 360 наступлений); остальные — `сегодня + 92 дня`, не меньше одного будущего наступления.
2. Для каждого активного правила: даты §5.1 от `max(start_date, последнее существующее due_date + 1 день)` до горизонта → `INSERT occurrences` (`seq` продолжает нумерацию, `amount_expected = rule.amount`, `currency = rule.currency`). Существующие строки не трогаются (I10).
3. `credit_line_payment`: у `planned` наступлений `amount_expected` обновляется на текущий долг счёта (`max(0, −balance)`, §9.1); при долге 0 наступление остаётся `planned` с `amount_expected = 0` и в списках показывается серым «Nothing to pay».
4. `auto_pay = 1` (§5.3): `planned` наступления с `due_date ≤ сегодня` и `amount_expected != null` и `account_id != null` → `payOccurrence` суммой `amount_expected` датой `due_date`.
5. Затем `ReminderPlanner.replan()` (§6).

Просрочка: `planned` с `due_date < сегодня` — «overdue», ничего автоматически не меняется, пользователь платит или пропускает.

### 5.3 Виды правил

| kind | что это | amount | категория | counter | auto_pay по умолчанию |
|---|---|---|---|---|---|
| `subscription` | Netflix, iCloud, спортзал | фиксирован | обязательна (`subscriptions` по умолчанию) | — | `true` (списывается с карты само) |
| `utility` | свет, вода, интернет, телефон | `null` или оценка | обязательна (`utilities`) | — | `false` |
| `loan_payment` | платёж по кредиту/рассрочке | `monthly_payment` | — (перевод) | счёт `loan` | `false` |
| `credit_line_payment` | погашение долга по карте | текущий долг (§5.2) | — (перевод) | счёт `credit_line` | `false` |
| `other` | аренда, алименты, взнос | любой | обязательна | — | `false` |

---

## 6. Уведомления (`features/notifications/reminder_planner.dart`)

Инициализация, запрос разрешения при первом включении, `AppDelegate`, обработка тапа — как во Flashcards
(§6 её спецификации): `DarwinInitializationSettings(requestAlertPermission: false, …)`, разрешение — при
первом включении «Reminders» в настройках или первого напоминания у правила; `UNUserNotificationCenter.current().delegate = self` до `super`.

`ReminderPlanner.replan()` (после каждого `OccurrencePlanner.replan`, при старте, после изменения настроек уведомлений):
1. Разрешения нет → выход.
2. `plugin.cancelAll()`.
3. **Сводка** (`digest_enabled`): для дней `d = 0..6` от сегодня, `t_d` = `d`-й день в `digest_minutes` локального, строго больше `now`; `n_d` = число `planned` наступлений с `due_date == день t_d` (плюс для `d = 0` — все просроченные), `sum_d` — их `amount_expected` в базовой валюте. `n_d > 0` → `zonedSchedule(id: 1 + d, title: "Payments today", body: "3 payments · 12 400 som")`; `n_d == 0` → ничего. Тексты — из ARB по локали приложения на момент планирования.
4. **По правилам**: кандидаты — для каждого `planned` наступления (`due_date ≥ сегодня`, правило не на паузе) и каждого `days_before ∈ remind_days_before`: момент `due_date − days_before` в `remind_minutes ?? default_minutes`, строго больше `now`. Сортировка по времени, берутся первые `64 − 7 = 57`; на правило — не больше 8 (`k = 0..7` в порядке времени, лишние отбрасываются). `zonedSchedule(id: base + k, title: rule.name, body: "Due tomorrow · 2 584,31 som" / "Due today · …" / "Due in 3 days · …", payload: occurrence.id, androidScheduleMode: AndroidScheduleMode.inexact)` — без `matchDateTimeComponents`.
5. `amount_expected == null` → в теле «Amount not set».

Тап: `payload` = id наступления → `push('/occurrence/:id')`; наступление уже `paid`/удалено → `/payments` с тостом «Already paid»; сводка (`id ≤ 7`) → `/payments`. Верхний экран совпадает с целью → второй тап ничего не кладёт поверх.

---

## 7. Резервная копия (`lib/data/backup/`)

- Формат `fintech-backup` v1, JSON: `{"format":"fintech-backup","version":1,"exported_at":"<ISO UTC>","app_settings":{…},"accounts":[…],"categories":[…],"transactions":[…],"recurring_rules":[…],"occurrences":[…],"budgets":[…],"exchange_rates":[…]}`. Строки таблиц — как в БД: моменты — unix-секунды UTC, даты — `YYYY-MM-DD`, деньги — `int`. `deleted_at`-строки включаются (I20).
- Экспорт: файл `fintech-backup-<YYYY-MM-DD>.json` в `Documents/backups/`, затем `share_plus` (в «Файлы», AirDrop, почту). Старые файлы в `backups/` не удаляются автоматически, список — на экране «Backup» с возможностью поделиться заново.
- Импорт: `file_picker` → проверка `format`, `version ≤ текущей`, обязательных ключей, что каждая ссылка (`account_id`, `category_id`, …) есть в файле → диалог «Replace all data? Current data will be lost» → закрыть БД, удалить файл базы, открыть заново (`onCreate`), вставить всё одной транзакцией → `OccurrencePlanner.replan()` → перезапуск состояния приложения (`ProviderContainer` пересоздаётся). Любая ошибка проверки — ничего не тронуто, текст ошибки на экране.
- Импорт из копии старшей версии формата — отказ с текстом «Update the app».

---

## 8. Экраны и маршруты

### 8.0 Дизайн

Форма — Jattap: `theme.dart` без изменений (серый фон `#F8F8F8`, белые карточки радиус 28, пилюли 40, графит вместо чёрного, Outfit, тёмная тема «мягкий чёрный», стеклянная панель вкладок и круглые стеклянные кнопки шапки). Пастель получает роли: **небо** — кредиты и кредитные линии, **лаванда** — подписки, **масло** — коммуналка, **мята** — доходы, накопления, «оплачено», **румянец** — просрочено и превышение бюджета. Категории и счета носят свой `color_key`.

Из Simbank (скриншоты заказчика 2026-09-29) берутся приёмы, не стиль:
- **Hero-число** сверху экрана: одна крупная сумма, дробная часть меньше, под ней две-три строки разбивки «подпись … значение» (у них «Личные средства / Кредитный лимит»). У нас — на Главной, на экране счёта, на экране кредита, в накоплениях.
- **Лента по дням**: заголовок дня капителью с итогом дня («TODAY · 34,00 som»), строка — круглая цветная иконка категории 48 pt, заголовок (заметка или имя категории), подзаголовок (категория · счёт), сумма справа (расход — графит, доход — `onMint` со знаком «+»).
- **Ряд круглых действий** под hero: 2–3 круглые графитовые кнопки с подписью под ними («Add expense», «Transfer», «Pay»). Это те же `GlassIconButton`-по-форме, но залитые графитом (`primary`).
- **Форма кредита**: сверху капсула «Amount · Rate · Total», в центре крупно «N months × payment», под ним горизонтальная шкала месяцев с рисками, снизу залитая пилюля «Next».
- **Разделы списком** с круглыми иконками (экран «Payments» у них) — для нашего экрана «New» и настроек.
- Чёрных заливок нет — графит `_ink`; нижняя панель — стекло Jattap, а не белая полоса Simbank.

### 8.1 Локализация

`lib/l10n/app_en.arb` (шаблон) и `app_ru.arb`. Ключи — `camelCase`, плейсхолдеры типизированы (`{count}`, `{amount}`), множественное число — ICU `plural` (в русском три формы: `one`, `few`, `many`). Тексты уведомлений — тоже ARB, локаль берётся из `locale` (`system` → локаль устройства, если это `ru`, иначе `en`). Переключение языка в настройках применяется без перезапуска. Даты — `DateFormat` с локалью (`5 Sep` / `5 сен`).

### 8.2 Маршруты (`go_router`, `StatefulShellRoute` с тремя ветками)

| путь | экран |
|---|---|
| `/` | Home |
| `/payments` | Payments (вкладка) |
| `/accounts` | Accounts (вкладка) |
| `/transactions` | All transactions (поиск, фильтры) |
| `/transaction/new?kind=expense\|income\|transfer&account=<id>&occurrence=<id>` | Add transaction |
| `/transaction/:id` | Transaction (просмотр/правка) |
| `/rule/new?kind=subscription\|utility\|other` | New payment rule |
| `/rule/:id` | Payment rule (просмотр/правка, список наступлений) |
| `/occurrence/:id` | Occurrence (оплатить / пропустить / изменить сумму) |
| `/account/new?kind=` | New account (cash/card/savings/deposit) |
| `/loan/new` | New loan (§4.3) |
| `/credit-line/new` | New credit line |
| `/account/:id` | Account (hero, действия, лента) |
| `/account/:id/edit` | Edit account |
| `/stats` | Stats |
| `/budgets` | Budgets |
| `/categories`, `/category/:id`, `/category/new?kind=` | Категории |
| `/settings` | Settings |
| `/settings/currencies` | Currencies |
| `/settings/backup` | Backup |
| `/onboarding` | Onboarding (первый запуск) |
| `/lock` | Lock (Face ID) |

Панель вкладок: слева стеклянная капсула Home / Payments / Accounts, справа стеклянная капсула **New** с меню: Expense, Income, Transfer, Payment (подменю: Subscription / Utility / Other). Кредит и кредитная линия создаются с вкладки Accounts (у них свои формы). Шапка Home: слева круглая кнопка Stats (иконка столбиков, как в Simbank над лентой), справа Settings.

### 8.3 Экраны

**Onboarding.** Три шага в одном экране-пейджере: язык (System / English / Русский), базовая валюта (список §4.1 с поиском, предвыбор по локали), «Cash» — стартовый баланс (MAY пропустить, 0). «Start» → §3.4 «Первый запуск» → `/`.

**Home.** Hero: «Own funds» = Σ балансов счетов `cash`/`card`/`savings`/`deposit` с `include_in_total = 1` в базовой валюте (§9.1). Строки: «Credit available» = Σ по `credit_line` (`credit_limit + balance`); «Debt» = Σ долгов `loan` + `credit_line`; «Spent this month» = §9.3 за текущий месяц (месяц — от `home.month_start_day`) с «of budget N», если задан общий бюджет. Ряд действий: Add expense, Add income, Transfer. Секция «Upcoming»: горизонтальная лента до 5 ближайших `planned` наступлений на 30 дней, просроченные первыми (румянец) — карточка 148×96: имя правила, сумма, «Tomorrow» / «In 3 days» / «Overdue 2 days», тап → `/occurrence/:id`; пусто → секция скрыта. Дальше лента транзакций по дням (§8.0) за последние 30 дней, заголовок «Recent» с кнопкой «All» → `/transactions`. Пустая Главная: карточка «Add your first expense» с кнопкой.

**Add transaction.** Первый экран после «New → Expense» — сразу цифровая клавиатура, поле суммы крупно в валюте счёта, под ним чипы категорий (в порядке `sort_order`, последние использованные первыми; для Income — категории дохода), строка «Account: Cash ▾» (счёт по умолчанию), дата (сегодня, тап → выбор), заметка. Переключатель сверху Expense / Income / Transfer сегментом. Transfer: «From ▾» / «To ▾», при разных валютах — второе поле суммы с подсказкой по курсу (§4.2). Save — пилюля в стеклянной панели; после Save на Главной тост «Saved» и возврат; в форме, открытой из наступления (`occurrence=`), сумма и категория предзаполнены и Save = `payOccurrence`.

**Transaction.** Все поля, правка, «Delete» (диалог). Связано с наступлением → плашка «Payment for <rule> · <date>» и «Undo payment» вместо «Delete».

**All transactions.** Поиск по заметке и имени категории, фильтры чипами: счёт, категория, вид, месяц. Лента по дням; итоги за выбранный период в шапке.

**Payments.** Сегмент сверху: **Upcoming** / **Rules**. Upcoming — список наступлений на 92 дня, сгруппированный: Overdue (румянец), Today, This week, Later; строка: иконка правила, имя, «3 of 24» для кредитов, сумма (или «Enter amount»), справа кнопка-пилюля «Pay» (открывает `/occurrence/:id`); свайп влево — Skip. Суммарная строка сверху «Due in 30 days · N». Rules — список правил по видам (Loans, Credit lines, Subscriptions, Utilities, Other) с суммой в месяц по виду (§9.5); строка → `/rule/:id`; на паузе — серым.

**Occurrence.** Карточка: имя правила, дата, «3 of 24», сумма (редактируемая, если `null` — поле с автофокусом), счёт списания (`rule.account_id`, можно сменить), дата оплаты (сегодня). Кнопки: «Pay» (пилюля), «Skip», для `paid` — «Undo payment». Для `credit_line_payment` — текущий долг и «Pay in full» / своя сумма.

**New payment rule / Payment rule.** Поля по §5.3: имя, вид (сегмент), сумма и валюта (для utility — переключатель «Amount varies»), категория, счёт списания, периодичность (Monthly / Weekly / Yearly / Every N days), день месяца / дата первого платежа, дата окончания (необязательна), напоминания (чипы «3 days before», «1 day before», «On the day», время), «Auto-pay» (подписки — вкл по умолчанию), иконка и цвет. На экране правила снизу — список наступлений (paid зелёной галочкой, skipped серым), меню «⋯»: Pause / Resume, Delete.

**Accounts.** Секции: Money (cash, card, savings, deposit), Credit (credit_line, loan). Карточка счёта: имя, вид, баланс (для пассивов — долг и «available N of limit» / «paid 3 of 24»), пастель по `color_key`, архивные — в свёрнутой секции внизу. Итог секции в заголовке. Кнопки внизу: «New account», меню: Cash/Card, Savings goal, Deposit, Loan, Credit line.

**Account.** Hero: баланс (пассив — долг), строки по виду: cash/card — «This month: −spent / +income»; credit_line — «Limit», «Available», «Due day»; loan — «Monthly payment», «Paid 3 of 24», «Next payment <date>», «Remaining»; savings — «Goal», «Left», «By <date>» и пилюля прогресса; deposit — «Rate», «Ends». Действия: Add expense / Add income / Transfer (для пассивов — «Pay», открывает ближайшее `planned` наступление). Лента транзакций счёта по дням. Меню «⋯»: Edit, Archive/Unarchive, Recalculate schedule (loan, §4.3), Delete (только без транзакций).

**New loan.** Как в Simbank (§8.0): имя, сумма, валюта, шкала месяцев 1..60, ставка (поле + сегмент «per month / per year», MAY пусто), результат «N months × payment» и «Total» — оба редактируемы (§4.3), дата первого платежа, счёт списания, «Next» → создаётся всё разом (§3.4). Ставка редактируется — пересчитываются платёж и итого; платёж редактируется — итого; итого — платёж.

**New credit line.** Имя, лимит, валюта, текущий долг (0), день оплаты (1..28), счёт списания, напоминания. Создаётся счёт и правило (§3.4).

**Stats.** Переключатель месяца (← Sep 2026 →, месяц — от `month_start_day`). Плитки: Spent, Income, Saved, «Debt total». Список категорий с горизонтальными полосами (доля от Spent, сумма, процент) → тап фильтрует `/transactions`. Внизу 6 месяцев столбиками Spent/Income (рисуются `CustomPaint`, без библиотек диаграмм; цвета из темы). «Debt» — линия остатка долга по месяцам за 12 месяцев.

**Budgets.** Общий бюджет месяца сверху (пилюля прогресса «spent / budget», румянец при превышении), ниже категории с бюджетом; «Set budget» на категорию без бюджета. Тап → диалог суммы (`setBudget` на текущий месяц; «apply from next month» — переключатель, тогда `from_month` = следующий).

**Categories.** Два списка (Expense / Income), перетаскивание порядка (`sort_order`), создание/правка: имя, иконка (сетка ключей `core/icons.dart`), цвет (пять пастелей). Удаление — только если нет транзакций; иначе предложение «Move transactions to …» (одна транзакция БД).

**Settings.** Language, Base currency (→ смена по §4.2 с диалогом), Currencies, Month starts on (1..28), Reminders (переключатель + время по умолчанию, дневная сводка + время), Face ID (переключатель; включение — сразу проверка `local_auth`), Backup, Categories, About (версия, ограничения: данные локальные, не зашифрованы).

**Currencies.** Базовая валюта; список курсов: код, курс к базовой, источник, дата; «Refresh» (§4.2); тап — ручной курс. Валюты добавляются в список, когда создан счёт или правило в этой валюте.

**Backup.** «Export» (§7), список прошлых файлов, «Import…».

**Lock.** При `lock.enabled`: холодный старт и возврат из фона после `lock.after_seconds` → экран с логотипом и кнопкой «Unlock with Face ID»; `local_auth.authenticate` вызывается автоматически при появлении; отказ — кнопка «Try again». Экран накрывает роутер (`Overlay` в `app.dart`), содержимое под ним не рендерится в снимок переключателя приложений (`FlutterView` заменяется заглушкой при `AppLifecycleState.inactive`).

---

## 9. Вычисления (`features/*/domain`, без I/O; SQL — в DAO)

### 9.1 Баланс счёта
`balance(A) = opening_balance + Σ income(A) − Σ expense(A) − Σ transfer.amount [account_id = A] + Σ transfer.counter_amount [counter_account_id = A]`, только `deleted_at IS NULL`. Долг пассива = `−balance` (≥ 0 при корректных данных; отрицательный долг — переплата, показывается как «+N overpaid»). `available(credit_line) = credit_limit + balance`. `remaining(loan) = −balance`; `paidCount(loan)` = число `paid` наступлений правила.

### 9.2 Own funds
Σ `balance(A)` в базовой валюте (`toBase`, §4.2) по неархивным счетам `cash`/`card`/`savings`/`deposit` с `include_in_total = 1`. Нет курса для валюты счёта → счёт показывается, но в сумму не входит, рядом значок «no rate».

### 9.3 Потрачено за период
Σ `base_amount` по транзакциям периода: `expense` (кроме `adjustment`) + `transfer` с `counter_account_id` вида `loan` (I15). «Income» = Σ `income` (кроме `adjustment`). «Saved» = Σ `transfer` на `savings`/`deposit` − Σ `transfer` с них. Период — `[start, end)` по `date` лексикографически; месяц — от `month_start_day` текущего до `month_start_day` следующего.

### 9.4 Бюджет месяца
Для категории `C` и месяца `M`: строка `budgets` с `category_id = C` и максимальным `from_month ≤ M`, `deleted_at IS NULL`. Нет → бюджета нет. Потрачено — §9.3 по этой категории. Общий бюджет (`category_id = null`) сравнивается со всем §9.3.

### 9.5 В месяц по правилу
`monthly`: `amount / interval`; `weekly`: `amount × 52 / 12 / interval`; `yearly`: `amount / 12`; `every_n_days`: `amount × 365 / 12 / n`; `amount = null` → по последнему `paid` наступлению, нет — не считается. Целочисленно, в базовой валюте.

### 9.6 `Clock`
Интерфейс `DateTime now()` (UTC). `SystemClock` в приложении, `FakeClock` в тестах. Локальная дата — `core/calendar.dart: today(clock)`.

---

## 10. Структура проекта и CLAUDE.md

```
lib/
  main.dart
  app/            app.dart, router.dart, theme.dart, tab_shell.dart, startup.dart, startup_gate.dart,
                  providers.dart, notification_navigation.dart, widgets/{glass.dart, hero.dart, day_list.dart, amount_field.dart, progress_pill.dart}
  core/           clock.dart, calendar.dart, money.dart, currencies.dart, icons.dart, uuid.dart, error_reporting.dart, timezone_setup.dart
  l10n/           app_en.arb, app_ru.arb (+ сгенерированный app_localizations*.dart)
  data/
    db/           tables.dart, database.dart, daos/{account,category,transaction,rule,occurrence,budget,rate,settings}_dao.dart
    rates/        nbkr_client.dart
    backup/       backup_codec.dart, backup_store.dart
  features/
    accounts/     domain/ (account.dart, balances.dart, loan_math.dart) data/ presentation/
    transactions/ domain/ data/ presentation/
    categories/   domain/ data/ presentation/
    payments/     domain/ (rule.dart, occurrence.dart, schedule.dart) data/ (occurrence_planner.dart) presentation/
    budgets/      domain/ data/ presentation/
    stats/        domain/ data/ presentation/
    currencies/   domain/ data/ presentation/
    notifications/ reminder_planner.dart, notification_gateway.dart, notification_taps.dart
    security/     app_lock.dart, presentation/
    settings/     data/ presentation/
    onboarding/   presentation/
test/
  core/           calendar_test.dart, money_test.dart
  accounts/       balances_test.dart, loan_math_test.dart, create_loan_test.dart, create_credit_line_test.dart
  transactions/   create_transaction_test.dart, transfer_test.dart, base_amount_test.dart
  payments/       schedule_test.dart, occurrence_planner_test.dart, pay_occurrence_test.dart, auto_pay_test.dart
  budgets/        budget_test.dart
  stats/          spent_test.dart
  currencies/     rates_test.dart, change_base_currency_test.dart, nbkr_parse_test.dart
  notifications/  reminder_planner_test.dart
  backup/         backup_roundtrip_test.dart, backup_reject_test.dart
  l10n/           arb_keys_test.dart
  architecture/   invariants_test.dart
  app/            theme_test.dart, routes_test.dart
```

`CLAUDE.md` в корне — файл репозитория (не дублируется здесь). Он повторяет §1 сжато, команды и правила процесса из Flashcards.

---

## 11. Порядок реализации и критерии приёмки

Каждый этап завершён, когда его тесты зелёные, `tool/verify.sh` зелёный и критерий выполнен на устройстве.

**Этап 1 — фундамент.**
- Проект `fintech`, зависимости §2, codegen, `l10n.yaml` и оба ARB с общими строками, перенос §2.1 (тема, стекло, инструменты, стражи, скиллы), `.claude/settings.json` с хуками.
- `tables.dart`, `database.dart`, DAO. Тест: все таблицы и индексы в in-memory БД.
- `core/calendar.dart` + тест (31-е → конец февраля/апреля, високосный год, `today` при смене локальной даты, лексикографика дат). `core/money.dart` + тест (`parseAmount` на все форматы, отказ при лишних знаках, `formatAmount` в ru/en, JPY без дробной части).
- `loan_math.dart` + тест (аннуитет на известных примерах: Simbank 5 000 сом, 2 месяца, 2,24 %/мес → платёж 2 584,31 точно (проверено 2026-09-29: формула даёт 2 584,3101); итого по формуле 5 168,62, Simbank показывает 5 168,60 — банк округляет итог по-своему, поэтому в форме итого редактируемо, а тест сверяет итого с допуском 5 тыйын; ставка 0; годовая ставка; пересчёт остатка «keep payment» / «keep term»).
- `schedule.dart` + тест (все частоты, `day_of_month = 31`, `end_date`, пауза).
- Стражи `invariants_test.dart` на I1–I20, каждый проверен мутацией. `arb_keys_test.dart`.
- Критерий: `tool/verify.sh` зелёный; приложение запускается на iPhone, показывает онбординг и пустую Главную на обоих языках.

**Этап 2 — счета, транзакции, категории.**
- Репозитории §3.4 (первый запуск, транзакции, переводы, счета) + тесты `transactions/`, `accounts/balances_test.dart`.
- Экраны: Onboarding, Home (без «Upcoming»), Add transaction, Transaction, All transactions, Accounts, Account, New account, Edit account, Categories.
- Критерий: на устройстве — онбординг, 10 расходов за 3 дня, доход, перевод между счетами; лента по дням с итогами, балансы сходятся с §9.1 вручную.

**Этап 3 — обязательства и уведомления.**
- `OccurrencePlanner` + тесты (`occurrence_planner_test.dart`: идемпотентность, горизонт, `paid` не трогается, кредит целиком, `credit_line` обновляет сумму; `auto_pay_test.dart`; `pay_occurrence_test.dart`: одна транзакция, откат).
- `createLoan`, `createCreditLine` + тесты. Экраны: Payments, Occurrence, New payment rule, Payment rule, New loan, New credit line, Account для пассивов, секция «Upcoming» на Главной.
- `ReminderPlanner` + тест (сводка id 1..7 только при `n_d > 0`; правило ≤ 8 id; всего ≤ 64; порядок по времени; ничего без разрешения; ни одного `matchDateTimeComponents`; тексты в ru и en).
- Маршрутизация по payload (тёплый и холодный старт).
- Критерий: на устройстве — кредит из скриншота Simbank (5 000 / 2 мес / 2,24 %), подписка с автооплатой, коммуналка без суммы; уведомление за 3 дня и в день приходит в заданное время, тап открывает наступление, «Pay» создаёт транзакцию, остаток кредита уменьшается; сводка утром.

**Этап 4 — бюджеты, статистика, валюты, накопления.**
- Бюджеты (§9.4) + тест; Stats (§9.3, §9.5) + тест; счета `savings`/`deposit` и их экраны.
- `nbkr_client.dart` + тест на сохранённом XML (`test/fixtures/nbkr_daily.xml`); ручные курсы; смена базовой валюты + тест (`base_amount` пересчитан у всех, бюджеты пересчитаны, курсы инвертированы, отказ без курса).
- Экраны: Stats, Budgets, Currencies, Settings (без Face ID и Backup).
- Критерий: счёт в USD, расход в долларах виден на Главной в сомах по курсу НБКР; бюджет категории краснеет при превышении.

**Этап 5 — защита и копия.**
- `app_lock.dart` + Lock; `backup_codec.dart`, `backup_store.dart` + тесты (`backup_roundtrip_test.dart`: экспорт → импорт в пустую БД → те же строки, включая `deleted_at`; `backup_reject_test.dart`: чужой формат, старшая версия, битая ссылка — ничего не изменилось).
- Экраны: Backup, Settings целиком, About. `routes_test.dart`: каждый маршрут §8.2 открывается без исключений на пустой и заполненной БД в обеих локалях.
- Скриншоты всех экранов (`tool/screenshots.sh`) в светлой и тёмной теме, обе локали; просмотр глазами (скилл `/shots`).
- Критерий: Face ID запирает при возврате через минуту; экспорт → удалить приложение → установить → импорт → всё на месте, уведомления перепланированы.

---

## 12. Что проверить кодом в первый день

1. **Символ сома.** Отрисовывается ли `⃀` (U+20C0) шрифтом Outfit и системным fallback на iOS устройства заказчика. Нет — остаётся «сом»/«som» (§4.1). Результат — строкой в §4.1.
2. **НБКР.** Точный URL и формат XML ежедневных курсов (`https://www.nbkr.kg/XML/daily.xml` — по памяти, MUST подтвердить в браузере), кодировка, формат чисел (запятая?), номинал (`Nominal`: 1, 10, 100). Сохранить ответ как `test/fixtures/nbkr_daily.xml`. Результат — в §4.2.
3. **`local_auth` на симуляторе.** Как ведёт себя `authenticate` без биометрии и при `Features → Face ID → Enrolled`; какие исключения (`NotAvailable`, `NotEnrolled`, `LockedOut`) и что показывать. Результат — в §8.3 «Lock».
4. **`file_picker` и `share_plus`** на iOS: возвращают ли путь к JSON из «Файлов», нужны ли `UTType` в `Info.plist`. Результат — в §7.

---

## 13. Протокол автономного выполнения

Исполнитель работает без подтверждений от человека между этапами. Остановка — только по §13.4.

### 13.1 Старт
1. Прочитать `docs/spec.md` целиком. Составить `docs/PROGRESS.md`: пункты §11 и §12 с чекбоксами.
2. Первый коммит — `docs/` (уже есть) + пустой проект Flutter.
3. Этап 1, первый пункт: зависимости, codegen, перенос §2.1.
4. §12: четыре проверки, результат — по строке в указанные разделы, коммит. Дальше — остальные пункты этапа 1 по §13.2.

### 13.2 Цикл на каждый пункт §11
1. Реализовать пункт.
2. `dart run build_runner build --delete-conflicting-outputs` (если менялись tables/riverpod); `flutter gen-l10n` (если менялись ARB).
3. `tool/verify.sh` — MUST быть «ЗЕЛЕНО»: `dart analyze` без ошибок и предупреждений (не подавлять, чинить), `flutter test` целиком.
4. Самопроверка по §1: пройти I1–I20 и для каждого одной строкой сказать, где в только что написанном коде он мог быть нарушен, и проверить это место. Найденное — исправить до коммита (скилл `/invariants`).
5. Правка интерфейса — скриншоты и просмотр глазами (`/shots`).
6. Отметить пункт в `docs/PROGRESS.md`, закоммитить: `stage N: <пункт>`. Хук `tool/commit_gate.sh` не пустит коммит без зелёного штампа.

### 13.3 Завершение этапа
1. `flutter build ios --no-codesign` — MUST собираться.
2. Сквозной тест этапа `test/integration/stage_N_test.dart` на in-memory БД: критерий этапа из §11 целиком (этап 3 — с `FakeNotificationGateway`, фиксирующим вызовы; этап 4 — с подменённым `dio` на фикстуре XML).
3. `docs/PROGRESS.md`, раздел «Этап N: отклонения от спецификации». Пустой раздел — тоже запись.
4. Следующий этап без остановки.

### 13.4 Условия остановки (единственные)
- Зависимость не устанавливается или её API не соответствует §2 настолько, что нужен другой пакет.
- Для выполнения пункта нужно нарушить инвариант §1.
- §12.2: НБКР недоступен или формат не разбирается — тогда только ручные курсы, и это решение заказчика.
- Нужен платный внешний ресурс (аккаунт, ключ, сервис).
Во всех остальных случаях решение принимает исполнитель, записывает в «отклонения» и продолжает. Вопросы вкуса (цвета, отступы, тексты) — не причина остановки.

### 13.5 Что проверяет человек, один раз, в конце
После этапа 5: `flutter run -d <iphone>` и ручной прогон по критериям этапов 2–5 подряд. Найденное — новый прогон исполнителя по §13.2 с описанием бага.

### 13.6 Формат финального отчёта
`docs/PROGRESS.md` в конце содержит: все чекбоксы; отклонения по этапам; результаты §12; команду запуска; известные ограничения.

---

## 14. Вне v1 (не реализовывать без явного запроса)

Подключение к банкам, разбор СМС и чеков (OCR), синхронизация и облако, семейный доступ, инвестиции и
портфель, перенос платежей с выходных и праздников, проценты по вкладу и капитализация (депозит — только
сумма и дата окончания), полная банковская математика кредита (дифференцированные платежи, дни в
периоде, комиссии), вложенные категории, теги, вложения к транзакциям (фото чека), виджет iOS «следующий
платёж» (кандидат на v1.1), Apple Watch, экспорт в CSV/Excel (кандидат на v1.1), повторяющиеся доходы как
правила (в v1 доход вводится руками; кандидат на v1.1), Android.
