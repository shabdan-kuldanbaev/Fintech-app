import 'package:intl/intl.dart';

import '../../core/calendar.dart';
import '../../core/money.dart';
import '../../l10n/app_localizations.dart';
import 'domain/reminder_plan.dart';

/// Тексты уведомлений из ARB (I14) на языке [l10n].
class ArbReminderTexts implements ReminderTexts {
  ArbReminderTexts(this.l10n);

  final AppLocalizations l10n;

  String get _lang => l10n.localeName.split('_').first;

  @override
  String digestTitle() => l10n.notifDigestTitle;

  @override
  String digestBody(int count, String total) => l10n.notifDigestBody(count, total);

  @override
  String dueToday(String amount) => l10n.notifDueToday(amount);

  @override
  String dueTomorrow(String amount) => l10n.notifDueTomorrow(amount);

  @override
  String dueIn(int days, String amount) => l10n.notifDueIn(days, amount);

  @override
  String amountNotSet() => l10n.notifAmountNotSet;

  @override
  String resumes(String name, LocalDate date) =>
      l10n.notifResumes(name, DateFormat.MMMd(_lang).format(date.toLocalDateTime()));

  @override
  String money(int minor, String currency) => formatAmount(minor, currency, _lang);
}
