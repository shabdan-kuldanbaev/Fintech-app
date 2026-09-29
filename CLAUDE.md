# Fintech (Flutter, iOS) — личные финансы

Рабочее имя пакета `fintech`, bundle id `com.shabdan.fintech`; название в App Store заказчик выберет позже.
Интерфейс — английский и русский (ARB), документация — русская.

Спецификация: docs/spec.md. Она первична. При расхождении кода и спецификации — исправлять код.
Порядок работы: docs/spec.md §13 (автономный протокол). Прогресс и отклонения — docs/PROGRESS.md.
Не спрашивать подтверждения между этапами; останавливаться только по §13.4.

## Стек
Flutter 3.x / Dart 3.x, flutter_riverpod + riverpod_annotation, go_router, drift + drift_flutter,
flutter_localizations + intl (ARB en/ru), flutter_local_notifications + timezone + flutter_timezone,
dio (только курсы НБКР), local_auth, share_plus, file_picker, xml.
Дизайн — Jattap (Flashcards-1.0): app/theme.dart и app/widgets/glass.dart переносятся дословно (spec.md §2.1, §8.0).
Весь интерфейс рисует Flutter (Material 3 + тема). Встроенные системные вью (UiKitView, cupertino_native) запрещены.

## Инварианты — MUST (полный список: spec.md §1)
- id: UUID v4 TEXT. autoIncrement запрещён.
- accounts/categories/transactions/recurring_rules/occurrences/budgets: только soft delete через deleted_at. Восстановление копии заменяет файл БД.
- Балансы, долги, «потрачено» — только вычисления над transactions (spec.md §9). Колонок с балансом нет. Правка баланса — транзакция с системной категорией adjustment.
- Деньги — int в минимальных единицах + код ISO 4217. double не хранится и не складывается; исключение — оценка платежа в loan_math.dart с немедленным округлением.
- Моменты — UTC unix-секунды (после чтения .toUtc(), перед записью isUtc == true). Календарные даты — TEXT YYYY-MM-DD локального календаря, сравнение лексикографическое. Границы дня 04:00 нет.
- Календарная арифметика — только core/calendar.dart и features/payments/domain/schedule.dart, без I/O.
- transactions.currency == accounts.currency; base_amount — снимок в базовой валюте, пересчёт только при смене базовой валюты одной транзакцией.
- Оплата/отмена оплаты наступления — одна транзакция БД (transactions + occurrences).
- Наступления — материализованные строки; (rule_id, due_date) уникальны среди живых; paid/skipped перепланированием не трогаются; автооплата только при auto_pay = 1.
- Уведомления: только одноразовые zonedSchedule без matchDateTimeComponents; сводка id 1..7; правило — notification_base_id + k (k = 0..7) из app_settings 'notifications.next_id' шагом 8; hashCode запрещён; всего ≤ 64.
- Сеть — только lib/data/rates/ (экран Currencies, кнопка Refresh). Аналитики и крашлитики нет.
- presentation не импортирует drift.
- Строки интерфейса и уведомлений — только AppLocalizations; литералов с буквами в Text(...) нет; наборы ключей en и ru совпадают.
- Статистика: расходы + переводы на loan; переводы на credit_line — не трата; на savings/deposit — «отложено»; adjustment не считается.
- Цвета и типографика — только app/theme.dart. Clipboard.getData не вызывать.
- local_auth — только lib/features/security/. Замок — экран, не шифрование.
- Кредитная математика — только features/accounts/domain/loan_math.dart, без I/O.
- Копия: экспорт всех таблиц включая deleted_at; импорт — только полная замена после подтверждения, версия формата проверяется до записи.
- flutter_timezone: getLocalTimezone() возвращает TimezoneInfo, использовать .identifier.
- flutter_local_notifications: androidScheduleMode обязателен; uiLocalNotificationDateInterpretation не существует.

## Команды
- codegen: dart run build_runner build --delete-conflicting-outputs; локализация: flutter gen-l10n
- полная проверка: tool/verify.sh (dart analyze + flutter test целиком; вердикт — последняя строка)
- отдельные тесты: flutter test <путь>
- устройство: flutter run -d <device-id>

## Как работать (скиллы — .claude/skills/, агенты — .claude/agents/; переносятся из Flashcards-1.0 на этапе 1)
- Закончил правку — скилл /verify. «Готово» и «проверено» произносятся с приложенной командой и её выводом.
- Правка в lib/ — скилл /invariants (I1–I20). Правка интерфейса — скилл /shots: кадры смотреть глазами, обе темы, обе локали.
- Несколько агентов — скилл /wave: читающих (auditor) много, пишущих (wave-writer) не больше 3–4,
  зоны файлов не пересекаются, полный прогон после волны оркестратор делает САМ.
- Механизмы проверки (tool/*.sh, стражи, помощники тестов) правятся отдельно от проверяемого кода и после правки проверяются мутацией.
- Находка закрывается по всему коду, а не по списку мест из отчёта; класс дефекта, выразимый текстом, заводится стражем в test/architecture/invariants_test.dart.
- Новый тест обязан краснеть против старого кода — проверить и сказать, что проверил.
- Тест ждёт условие, а не фиксированное время.

## Правила изменений
- Перед каждым коммитом: tool/verify.sh зелёный над ровно этим кодом (хук tool/commit_gate.sh) и /invariants.
- Нужен платный внешний ресурс (API-ключ, аккаунт, сервис) — сначала спросить. У заказчика подписка Claude, API-ключа нет.
- До релиза: изменение tables.dart дописывается в onCreate (spec.md §3.2), schemaVersion остаётся 1, приложение на устройстве переустанавливается. После релиза — schemaVersion + 1 и шаг onUpgrade.
- Любое изменение loan_math.dart, schedule.dart, occurrence_planner.dart, reminder_planner.dart, SQL балансов и статистики → соответствующие тесты в test/ обязаны быть обновлены и зелёными.
- Вне v1 (не реализовывать без явного запроса): spec.md §14 — банки, СМС, OCR, облако, семейный доступ, инвестиции, перенос с выходных, проценты по вкладу, банковская математика кредита, вложенные категории, теги, вложения, виджеты, CSV, повторяющиеся доходы, Android.
