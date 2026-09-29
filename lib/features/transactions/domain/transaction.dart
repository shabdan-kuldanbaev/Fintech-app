import 'package:flutter/foundation.dart';

import '../../../core/calendar.dart';

enum TxKind {
  expense('expense'),
  income('income'),
  transfer('transfer');

  const TxKind(this.db);
  final String db;

  static TxKind fromDb(String value) => values.firstWhere(
    (k) => k.db == value,
    orElse: () => throw ArgumentError.value(value, 'transaction kind'),
  );
}

/// Операция (spec.md §3.1). [amount] > 0 всегда; знак задаёт [kind].
@immutable
class Txn {
  const Txn({
    required this.id,
    required this.kind,
    required this.accountId,
    required this.amount,
    required this.currency,
    required this.baseAmount,
    required this.date,
    required this.createdAt,
    this.counterAccountId,
    this.counterAmount,
    this.categoryId,
    this.occurrenceId,
    this.note,
  });

  final String id;
  final TxKind kind;
  final String accountId;
  final String? counterAccountId;
  final int amount;
  final String currency;
  final int? counterAmount;
  final int baseAmount;
  final String? categoryId;
  final String? occurrenceId;
  final LocalDate date;
  final String? note;

  /// UTC. Порядок внутри дня — по времени записи.
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is Txn &&
      other.id == id &&
      other.kind == kind &&
      other.accountId == accountId &&
      other.counterAccountId == counterAccountId &&
      other.amount == amount &&
      other.counterAmount == counterAmount &&
      other.baseAmount == baseAmount &&
      other.categoryId == categoryId &&
      other.occurrenceId == occurrenceId &&
      other.date == date &&
      other.note == note;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    accountId,
    counterAccountId,
    amount,
    counterAmount,
    baseAmount,
    categoryId,
    occurrenceId,
    date,
    note,
  );
}

/// Что вводит пользователь: всё, кроме того, что считает репозиторий
/// (валюта — из счёта, `base_amount` — по курсу).
@immutable
class TxnInput {
  const TxnInput({
    required this.kind,
    required this.accountId,
    required this.amount,
    required this.date,
    this.counterAccountId,
    this.counterAmount,
    this.categoryId,
    this.note,
    this.occurrenceId,
  });

  final TxKind kind;
  final String accountId;
  final int amount;
  final LocalDate date;
  final String? counterAccountId;
  final int? counterAmount;
  final String? categoryId;
  final String? note;
  final String? occurrenceId;

  TxnInput copyWith({LocalDate? date}) => TxnInput(
    kind: kind,
    accountId: accountId,
    amount: amount,
    date: date ?? this.date,
    counterAccountId: counterAccountId,
    counterAmount: counterAmount,
    categoryId: categoryId,
    note: note,
    occurrenceId: occurrenceId,
  );
}

/// Ошибка проверки при записи операции (§3.4): ничего не записано.
class TxnValidationError implements Exception {
  const TxnValidationError(this.reason);
  final String reason;

  @override
  String toString() => 'TxnValidationError: $reason';
}

/// Нет курса валюты — `base_amount` не посчитать (§4.2).
class MissingRate implements Exception {
  const MissingRate(this.currency);
  final String currency;

  @override
  String toString() => 'MissingRate: $currency';
}
