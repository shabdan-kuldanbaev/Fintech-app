import 'package:flutter/foundation.dart';

import '../../../core/calendar.dart';
import 'loan_math.dart';

/// Вид счёта (`accounts.kind`, spec.md §3.1).
enum AccountKind {
  cash('cash'),
  card('card'),
  creditLine('credit_line'),
  loan('loan'),
  savings('savings'),
  deposit('deposit');

  const AccountKind(this.db);
  final String db;

  static AccountKind fromDb(String value) => values.firstWhere(
    (k) => k.db == value,
    orElse: () => throw ArgumentError.value(value, 'account kind'),
  );

  /// Пассив: баланс ≤ 0, долг = −баланс.
  bool get isLiability => this == creditLine || this == loan;

  /// Входит в «Own funds» (§9.2).
  bool get isAsset => !isLiability;

  /// Секция «Money» на вкладке Accounts.
  bool get isEveryday => this == cash || this == card;

  bool get isSaving => this == savings || this == deposit;

  String get defaultIcon => switch (this) {
    cash => 'wallet',
    card => 'card',
    creditLine => 'credit_line',
    loan => 'loan',
    savings => 'savings',
    deposit => 'deposit',
  };

  String get defaultColor => switch (this) {
    cash => 'mint',
    card => 'sky',
    creditLine => 'sky',
    loan => 'sky',
    savings => 'butter',
    deposit => 'mint',
  };
}

/// Счёт. Баланса здесь нет (I3): он приходит из транзакций отдельно.
@immutable
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.kind,
    required this.currency,
    required this.openingBalance,
    required this.iconKey,
    required this.colorKey,
    this.creditLimit,
    this.dueDay,
    this.minPayment,
    this.principal,
    this.totalPayable,
    this.monthlyPayment,
    this.termMonths,
    this.rateBp,
    this.ratePeriod,
    this.firstPaymentDate,
    this.targetAmount,
    this.targetDate,
    this.sortOrder = 0,
    this.includeInTotal = true,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final AccountKind kind;
  final String currency;
  final int openingBalance;
  final int? creditLimit;
  final int? dueDay;
  final int? minPayment;
  final int? principal;
  final int? totalPayable;
  final int? monthlyPayment;
  final int? termMonths;
  final int? rateBp;
  final RatePeriod? ratePeriod;
  final LocalDate? firstPaymentDate;
  final int? targetAmount;
  final LocalDate? targetDate;
  final String iconKey;
  final String colorKey;
  final int sortOrder;
  final bool includeInTotal;
  final bool isArchived;

  @override
  bool operator ==(Object other) =>
      other is Account &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.currency == currency &&
      other.openingBalance == openingBalance &&
      other.creditLimit == creditLimit &&
      other.dueDay == dueDay &&
      other.minPayment == minPayment &&
      other.totalPayable == totalPayable &&
      other.monthlyPayment == monthlyPayment &&
      other.targetAmount == targetAmount &&
      other.targetDate == targetDate &&
      other.iconKey == iconKey &&
      other.colorKey == colorKey &&
      other.sortOrder == sortOrder &&
      other.includeInTotal == includeInTotal &&
      other.isArchived == isArchived;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    currency,
    openingBalance,
    creditLimit,
    dueDay,
    totalPayable,
    targetAmount,
    iconKey,
    colorKey,
    sortOrder,
    includeInTotal,
    isArchived,
  );
}

/// Поля счёта, которые задаёт пользователь (создание и правка).
@immutable
class AccountInput {
  const AccountInput({
    required this.name,
    required this.kind,
    required this.currency,
    this.openingBalance = 0,
    this.iconKey,
    this.colorKey,
    this.creditLimit,
    this.dueDay,
    this.minPayment,
    this.principal,
    this.totalPayable,
    this.monthlyPayment,
    this.termMonths,
    this.rateBp,
    this.ratePeriod,
    this.firstPaymentDate,
    this.targetAmount,
    this.targetDate,
    this.includeInTotal = true,
  });

  final String name;
  final AccountKind kind;
  final String currency;
  final int openingBalance;
  final String? iconKey;
  final String? colorKey;
  final int? creditLimit;
  final int? dueDay;
  final int? minPayment;
  final int? principal;
  final int? totalPayable;
  final int? monthlyPayment;
  final int? termMonths;
  final int? rateBp;
  final RatePeriod? ratePeriod;
  final LocalDate? firstPaymentDate;
  final int? targetAmount;
  final LocalDate? targetDate;
  final bool includeInTotal;
}

/// Ошибка проверки счёта (§3.4): ничего не записано.
class AccountValidationError implements Exception {
  const AccountValidationError(this.reason);
  final String reason;

  @override
  String toString() => 'AccountValidationError: $reason';
}
