# PROGRESS

Спецификация: `docs/spec.md` v1. Протокол: §13.

## Сейчас (обновлено 2026-09-29)

- Спецификация v1 написана по решениям заказчика 2026-09-29; кода нет. Ждёт правок заказчика,
  затем — §13.1 (старт) исполнителем.
- Исходник дизайна и инструментов — репозиторий `Flashcards-1.0` (Jattap), список переноса — spec.md §2.1.

## §11 — пункты

### Этап 1 — фундамент
- [ ] Проект, зависимости §2, codegen, l10n, перенос §2.1, хуки `.claude/settings.json`
- [ ] `tables.dart`, `database.dart`, DAO + тест таблиц и индексов
- [ ] `core/calendar.dart` + тест
- [ ] `core/money.dart` + тест
- [ ] `loan_math.dart` + тест
- [ ] `schedule.dart` + тест
- [ ] Стражи I1–I20 (мутация каждого), `arb_keys_test.dart`
- [ ] Критерий этапа на устройстве

### Этап 2 — счета, транзакции, категории
- [ ] Репозитории §3.4 + тесты
- [ ] Экраны Onboarding, Home, Add transaction, Transaction, All transactions, Accounts, Account, New/Edit account, Categories
- [ ] Критерий этапа на устройстве

### Этап 3 — обязательства и уведомления
- [ ] `OccurrencePlanner` + тесты
- [ ] `createLoan`, `createCreditLine` + тесты; экраны Payments, Occurrence, New/Payment rule, New loan, New credit line, «Upcoming»
- [ ] `ReminderPlanner` + тест
- [ ] Маршрутизация по payload
- [ ] Критерий этапа на устройстве

### Этап 4 — бюджеты, статистика, валюты, накопления
- [ ] Бюджеты + тест; Stats + тест; savings/deposit
- [ ] `nbkr_client.dart` + тест на фикстуре; ручные курсы; смена базовой валюты + тест
- [ ] Экраны Stats, Budgets, Currencies, Settings
- [ ] Критерий этапа на устройстве

### Этап 5 — защита и копия
- [ ] `app_lock.dart` + Lock; backup codec/store + тесты
- [ ] Экраны Backup, Settings целиком, About; `routes_test.dart`
- [ ] Скриншоты всех экранов, обе темы, обе локали
- [ ] Критерий этапа на устройстве

## §12 — проверки первого дня
- [ ] 12.1 Символ сома U+20C0
- [ ] 12.2 URL и формат XML НБКР → `test/fixtures/nbkr_daily.xml`
- [ ] 12.3 `local_auth` на симуляторе
- [ ] 12.4 `file_picker` / `share_plus` на iOS

## Отклонения от спецификации
(заполняется по этапам, §13.3)

## Известные ограничения
- Данные локальные, без шифрования; Face ID — замок экрана (spec.md I18).
- Подключения к банкам и разбора СМС нет и не будет (spec.md §0).
