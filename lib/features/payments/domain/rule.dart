import 'package:flutter/foundation.dart';

import '../../../core/calendar.dart';
import 'schedule.dart';

/// Вид правила (`recurring_rules.kind`, spec.md §5.3).
enum RuleKind {
  subscription('subscription'),
  utility('utility'),
  loanPayment('loan_payment'),
  creditLinePayment('credit_line_payment'),
  other('other');

  const RuleKind(this.db);
  final String db;

  static RuleKind fromDb(String value) => values.firstWhere(
    (k) => k.db == value,
    orElse: () => throw ArgumentError.value(value, 'rule kind'),
  );

  /// Платёж — перевод на счёт-пассив, а не расход с категорией.
  bool get isTransfer => this == loanPayment || this == creditLinePayment;

  /// Виды, которые пользователь заводит сам на вкладке Payments.
  static const List<RuleKind> userKinds = [subscription, utility, other];

  String get defaultIcon => switch (this) {
    subscription => 'subscriptions',
    utility => 'utilities',
    loanPayment => 'loan',
    creditLinePayment => 'credit_line',
    other => 'housing',
  };

  String get defaultColor => switch (this) {
    subscription => 'lavender',
    utility => 'butter',
    loanPayment => 'sky',
    creditLinePayment => 'sky',
    other => 'lavender',
  };

  /// Категория по умолчанию (ключ предустановленной, §5.3).
  String? get defaultCategoryKey => switch (this) {
    subscription => 'subscriptions',
    utility => 'utilities',
    other => 'housing',
    loanPayment || creditLinePayment => null,
  };
}

/// Правило обязательства.
@immutable
class Rule {
  const Rule({
    required this.id,
    required this.name,
    required this.kind,
    required this.currency,
    required this.frequency,
    required this.startDate,
    required this.notificationBaseId,
    required this.iconKey,
    required this.colorKey,
    this.accountId,
    this.counterAccountId,
    this.categoryId,
    this.amount,
    this.interval = 1,
    this.dayOfMonth,
    this.endDate,
    this.remindDaysBefore = const [3, 0],
    this.remindMinutes,
    this.autoPay = false,
    this.pausedUntil,
  });

  final String id;
  final String name;
  final RuleKind kind;
  final String? accountId;
  final String? counterAccountId;
  final String? categoryId;
  final int? amount;
  final String currency;
  final Frequency frequency;
  final int interval;
  final int? dayOfMonth;
  final LocalDate startDate;
  final LocalDate? endDate;
  final List<int> remindDaysBefore;
  final int? remindMinutes;
  final int notificationBaseId;
  final bool autoPay;
  final LocalDate? pausedUntil;
  final String iconKey;
  final String colorKey;

  /// Пауза без срока (§3.4).
  static const LocalDate pausedForever = LocalDate(9999, 12, 31);

  ScheduleSpec get spec => ScheduleSpec(
    frequency: frequency,
    start: startDate,
    interval: interval,
    dayOfMonth: dayOfMonth,
    end: endDate,
    pausedUntil: pausedUntil,
  );

  bool isPausedOn(LocalDate today) =>
      pausedUntil != null && pausedUntil! > today;

  @override
  bool operator ==(Object other) =>
      other is Rule &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.accountId == accountId &&
      other.counterAccountId == counterAccountId &&
      other.categoryId == categoryId &&
      other.amount == amount &&
      other.currency == currency &&
      other.frequency == frequency &&
      other.interval == interval &&
      other.dayOfMonth == dayOfMonth &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      listEquals(other.remindDaysBefore, remindDaysBefore) &&
      other.remindMinutes == remindMinutes &&
      other.autoPay == autoPay &&
      other.pausedUntil == pausedUntil &&
      other.iconKey == iconKey &&
      other.colorKey == colorKey;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    accountId,
    amount,
    frequency,
    interval,
    dayOfMonth,
    startDate,
    endDate,
    autoPay,
    pausedUntil,
    iconKey,
    colorKey,
  );
}

/// Поля правила, которые задаёт пользователь.
@immutable
class RuleInput {
  const RuleInput({
    required this.name,
    required this.kind,
    required this.currency,
    required this.frequency,
    required this.startDate,
    this.accountId,
    this.counterAccountId,
    this.categoryId,
    this.amount,
    this.interval = 1,
    this.dayOfMonth,
    this.endDate,
    this.remindDaysBefore = const [3, 0],
    this.remindMinutes,
    this.autoPay = false,
    this.iconKey,
    this.colorKey,
  });

  final String name;
  final RuleKind kind;
  final String? accountId;
  final String? counterAccountId;
  final String? categoryId;
  final int? amount;
  final String currency;
  final Frequency frequency;
  final int interval;
  final int? dayOfMonth;
  final LocalDate startDate;
  final LocalDate? endDate;
  final List<int> remindDaysBefore;
  final int? remindMinutes;
  final bool autoPay;
  final String? iconKey;
  final String? colorKey;
}

enum OccStatus {
  planned('planned'),
  paid('paid'),
  skipped('skipped');

  const OccStatus(this.db);
  final String db;

  static OccStatus fromDb(String value) => values.firstWhere(
    (s) => s.db == value,
    orElse: () => throw ArgumentError.value(value, 'occurrence status'),
  );
}

/// Наступление правила: дата и сумма к оплате.
@immutable
class Occurrence {
  const Occurrence({
    required this.id,
    required this.ruleId,
    required this.seq,
    required this.dueDate,
    required this.currency,
    required this.status,
    this.amountExpected,
    this.transactionId,
    this.paidAt,
  });

  final String id;
  final String ruleId;
  final int seq;
  final LocalDate dueDate;
  final int? amountExpected;
  final String currency;
  final OccStatus status;
  final String? transactionId;

  /// UTC.
  final DateTime? paidAt;

  bool isOverdue(LocalDate today) =>
      status == OccStatus.planned && dueDate < today;

  @override
  bool operator ==(Object other) =>
      other is Occurrence &&
      other.id == id &&
      other.ruleId == ruleId &&
      other.seq == seq &&
      other.dueDate == dueDate &&
      other.amountExpected == amountExpected &&
      other.currency == currency &&
      other.status == status &&
      other.transactionId == transactionId;

  @override
  int get hashCode =>
      Object.hash(id, ruleId, seq, dueDate, amountExpected, currency, status, transactionId);
}

/// Наступление вместе со своим правилом — то, что показывают списки.
@immutable
class DueItem {
  const DueItem(this.occurrence, this.rule);
  final Occurrence occurrence;
  final Rule rule;

  @override
  bool operator ==(Object other) =>
      other is DueItem && other.occurrence == occurrence && other.rule == rule;

  @override
  int get hashCode => Object.hash(occurrence, rule);
}
