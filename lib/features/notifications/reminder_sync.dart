import 'dart:async';

import 'package:drift/drift.dart';

import '../../data/db/database.dart';
import 'reminder_service.dart';

/// Перепланирование уведомлений при изменении того, из чего они строятся
/// (§6: «после каждого `OccurrencePlanner.replan`, … после изменения
/// настроек»): правила, наступления, операции (сумма «как в прошлый раз»),
/// настройки, курсы. Одно слежение вместо вызова из каждого экрана —
/// новый экран не может «забыть» перепланировать.
///
/// Пачка изменений (оплата — две таблицы, планировщик — десятки строк)
/// сводится в один `replan` через [delay].
class ReminderSync {
  ReminderSync(this._db, this._service, {this.delay = const Duration(milliseconds: 800)});

  final AppDatabase _db;
  final ReminderService _service;
  final Duration delay;

  StreamSubscription<Set<TableUpdate>>? _sub;
  Timer? _timer;
  bool _running = false;
  bool _again = false;

  void start() {
    if (_sub != null) return;
    _sub = _db
        .tableUpdates(
          TableUpdateQuery.allOf([
            TableUpdateQuery.onTable(_db.recurringRules),
            TableUpdateQuery.onTable(_db.occurrences),
            TableUpdateQuery.onTable(_db.transactions),
            TableUpdateQuery.onTable(_db.appSettings),
            TableUpdateQuery.onTable(_db.exchangeRates),
          ]),
        )
        .listen((_) => schedule());
  }

  /// Перепланировать чуть позже; повторные вызовы сдвигают срок.
  void schedule() {
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(_run()));
  }

  Future<void> _run() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      await _service.replanQuietly();
    } finally {
      _running = false;
    }
    if (_again) {
      _again = false;
      schedule();
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _sub?.cancel();
    _sub = null;
  }
}
