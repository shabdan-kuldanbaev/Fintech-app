import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../core/calendar.dart';
import '../core/money.dart';
import '../features/accounts/domain/account.dart';
import '../features/categories/domain/category.dart';
import '../l10n/app_localizations.dart';

/// Язык, деньги и даты по текущей локали приложения (spec.md §8.1).
extension AppFormat on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String get lang => Localizations.localeOf(this).languageCode;

  /// «2 584,31 сом». [whole] — для hero и итогов секций (§8.0).
  String money(
    int minor,
    String currency, {
    bool whole = false,
    bool symbol = true,
    bool plus = false,
  }) => formatAmount(
    minor,
    currency,
    lang,
    whole: whole,
    symbol: symbol,
    plus: plus,
  );

  /// «5 окт.» / «Oct 5».
  String day(LocalDate date) =>
      DateFormat.MMMd(lang).format(date.toLocalDateTime());

  /// «5 окт. 2026» / «Oct 5, 2026».
  String dayYear(LocalDate date) =>
      DateFormat.yMMMd(lang).format(date.toLocalDateTime());

  /// «ср, 1 окт.» / «Wed, Oct 1».
  String weekdayDay(LocalDate date) =>
      DateFormat.MMMEd(lang).format(date.toLocalDateTime());

  /// «Сентябрь 2026» / «September 2026».
  String monthYear(LocalDate date) {
    final s = DateFormat('LLLL y', lang).format(date.toLocalDateTime());
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  /// Месяц и год в родительном падеже для «до …»: «июня 2027» / «June 2027».
  String monthYearUntil(LocalDate date) =>
      DateFormat('MMMM y', lang).format(date.toLocalDateTime());

  /// «Сегодня», «Вчера», «Завтра» или дата.
  String relativeDay(LocalDate date, LocalDate today) {
    final d = today.daysUntil(date);
    if (d == 0) return l10n.today;
    if (d == -1) return l10n.yesterday;
    if (d == 1) return l10n.tomorrow;
    return date.year == today.year ? day(date) : dayYear(date);
  }

  /// Курс ×10⁶ строкой: «87,45» (до 4 знаков, без хвостовых нулей).
  String rate(int rateMicro) {
    final whole = rateMicro ~/ rateScale;
    var frac = (rateMicro % rateScale).toString().padLeft(6, '0');
    frac = frac.substring(0, 4).replaceFirst(RegExp(r'0+$'), '');
    if (frac.length < 2) frac = frac.padRight(2, '0');
    return '$whole${lang == 'ru' ? ',' : '.'}$frac';
  }

  /// Время из минут от полуночи: «10:00».
  String minutes(int minutesOfDay) {
    final t = DateTime(2000, 1, 1, minutesOfDay ~/ 60, minutesOfDay % 60);
    return DateFormat.Hm(lang).format(t);
  }
}

/// Имя категории: своё или из ARB по ключу предустановленной (§3.1).
String categoryName(AppLocalizations l, Category c) {
  final own = c.name;
  if (own != null && own.isNotEmpty) return own;
  return switch (c.key) {
    'groceries' => l.groceries,
    'cafe' => l.cafe,
    'transport' => l.transport,
    'taxi' => l.taxi,
    'housing' => l.housing,
    'utilities' => l.utilities,
    'phone' => l.phone,
    'subscriptions' => l.subscriptions,
    'health' => l.health,
    'clothes' => l.clothes,
    'entertainment' => l.entertainment,
    'education' => l.education,
    'gifts' => l.gifts,
    'travel' => l.travel,
    'kids' => l.kids,
    'pets' => l.pets,
    'other_expense' => l.otherExpense,
    'salary' => l.salary,
    'freelance' => l.freelance,
    'gift_income' => l.giftIncome,
    'interest' => l.interest,
    'other_income' => l.otherIncome,
    adjustmentKey => l.adjustment,
    _ => l.otherExpense,
  };
}

String accountKindName(AppLocalizations l, AccountKind kind) => switch (kind) {
  AccountKind.cash => l.accountKindCash,
  AccountKind.card => l.accountKindCard,
  AccountKind.creditLine => l.accountKindCreditLine,
  AccountKind.loan => l.accountKindLoan,
  AccountKind.savings => l.accountKindSavings,
  AccountKind.deposit => l.accountKindDeposit,
};
