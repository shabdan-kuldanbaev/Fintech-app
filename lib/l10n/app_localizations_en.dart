// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fintech';

  @override
  String get tabHome => 'Home';

  @override
  String get tabPayments => 'Payments';

  @override
  String get tabAccounts => 'Accounts';

  @override
  String get actionAddExpense => 'Add expense';

  @override
  String get close => 'Close';

  @override
  String get back => 'Back';

  @override
  String get more => 'More';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get undo => 'Undo';

  @override
  String get done => 'Done';

  @override
  String get next => 'Next';

  @override
  String get retry => 'Try again';

  @override
  String get all => 'All';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get notFoundTitle => 'Not found';

  @override
  String get notFoundBody => 'It may have been deleted.';

  @override
  String get optional => 'optional';

  @override
  String get none => 'None';

  @override
  String get startupIncompatibleTitle => 'Reinstall the app';

  @override
  String get startupIncompatibleBody =>
      'This build cannot open the data of the previous one. Delete the app and install it again.';

  @override
  String get startupUnknownTitle => 'Something went wrong';

  @override
  String get startupUnknownBody => 'The app could not start. Try again.';

  @override
  String get startupDetails => 'Details';

  @override
  String homeSafeToSpend(String date) {
    return 'Safe to spend until $date';
  }

  @override
  String get homeOwnFunds => 'Own funds';

  @override
  String get homeToPay => 'To pay';

  @override
  String get homeQuickAdd => 'Quick add · 1 tap';

  @override
  String get homeUpcoming => 'Upcoming';

  @override
  String homeUpcomingTotal(String total) {
    return '30 days · $total';
  }

  @override
  String get homeRecent => 'Recent';

  @override
  String get homeEmptyTitle => 'Add your first expense';

  @override
  String get homeEmptyBody =>
      'Tap + right after a purchase: amount, category — saved.';

  @override
  String homeCurrency(String code) {
    return 'Currency: $code';
  }

  @override
  String get homeStats => 'Statistics';

  @override
  String get homeSettings => 'Settings';

  @override
  String get homeNoRate =>
      'Some accounts have no exchange rate and are not counted';

  @override
  String get addTitle => 'Add';

  @override
  String get kindExpense => 'Expense';

  @override
  String get kindIncome => 'Income';

  @override
  String get kindTransfer => 'Transfer';

  @override
  String get addNote => 'Note';

  @override
  String get addNoteHint => 'What was it?';

  @override
  String get addCategoryHint => 'Category · tap to save';

  @override
  String get addQuick => 'Frequent · 1 tap';

  @override
  String get addFrom => 'From';

  @override
  String get addToHint => 'To · tap to save';

  @override
  String get addEnterAmount => 'Enter the amount first';

  @override
  String addCounterAmount(String currency) {
    return 'Amount in $currency';
  }

  @override
  String addRateHint(String rate) {
    return 'At the rate $rate';
  }

  @override
  String get addNoOtherAccount =>
      'No other account yet. Add one on the Accounts tab.';

  @override
  String addMissingRate(String code) {
    return 'No rate for $code. Enter it in Settings → Exchange rates.';
  }

  @override
  String get pickAccount => 'Account';

  @override
  String get pickDate => 'Date';

  @override
  String get pickCategory => 'Category';

  @override
  String savedToast(String label) {
    return 'Saved · $label';
  }

  @override
  String get deletedToast => 'Deleted';

  @override
  String paidToast(String label) {
    return 'Paid · $label';
  }

  @override
  String skippedToast(String label) {
    return 'Skipped · $label';
  }

  @override
  String unpaidToast(String label) {
    return 'Payment undone · $label';
  }

  @override
  String get changesSaved => 'Saved';

  @override
  String get txAmount => 'Amount';

  @override
  String get txCategory => 'Category';

  @override
  String get txAccount => 'Account';

  @override
  String get txFrom => 'From';

  @override
  String get txTo => 'To';

  @override
  String get txDate => 'Date';

  @override
  String get txNote => 'Note';

  @override
  String txPaymentFor(String rule, String date) {
    return 'Payment for $rule · $date';
  }

  @override
  String get txUndoPayment => 'Undo payment';

  @override
  String get txAllTitle => 'Transactions';

  @override
  String get txSearchHint => 'Search notes and categories';

  @override
  String get txEmpty => 'Nothing here yet';

  @override
  String get filterAccount => 'Account';

  @override
  String get filterCategory => 'Category';

  @override
  String get filterKind => 'Kind';

  @override
  String get filterMonth => 'Month';

  @override
  String get filterAny => 'Any';

  @override
  String get adjustment => 'Balance correction';

  @override
  String get accountsTitle => 'Accounts';

  @override
  String get accountsMoney => 'Money';

  @override
  String get accountsCredit => 'Credit';

  @override
  String accountsArchived(int count) {
    return 'Archived accounts · $count';
  }

  @override
  String get accountsNewMenu => 'New account';

  @override
  String get accountKindCash => 'Cash';

  @override
  String get accountKindCard => 'Card';

  @override
  String get accountKindCreditLine => 'Credit line';

  @override
  String get accountKindLoan => 'Loan';

  @override
  String get accountKindSavings => 'Savings goal';

  @override
  String get accountKindDeposit => 'Deposit';

  @override
  String get accountsNewCashOrCard => 'Cash or card';

  @override
  String get cashDefaultName => 'Cash';

  @override
  String accountThisMonth(String amount) {
    return '$amount this month';
  }

  @override
  String accountAvailableOf(String available, String limit) {
    return '$available available of $limit';
  }

  @override
  String accountLoanProgress(int paid, int total, String payment) {
    return '$paid of $total paid · $payment / month';
  }

  @override
  String accountGoalOf(String target, int percent) {
    return 'of $target · $percent%';
  }

  @override
  String accountByDate(String date) {
    return 'by $date';
  }

  @override
  String accountDueDate(String date) {
    return 'due $date';
  }

  @override
  String accountNextDate(String date) {
    return 'next $date';
  }

  @override
  String accountDebtTotal(String amount) {
    return 'debt $amount';
  }

  @override
  String get accountNoRate => 'no rate';

  @override
  String get accountBalance => 'Balance';

  @override
  String get accountDebt => 'Debt';

  @override
  String get accountRemaining => 'Remaining';

  @override
  String get accountLimit => 'Limit';

  @override
  String get accountAvailable => 'Available';

  @override
  String get accountDueDay => 'Due day';

  @override
  String get accountMonthly => 'Monthly';

  @override
  String get accountPaid => 'Paid';

  @override
  String accountPaidOf(int paid, int total) {
    return '$paid of $total';
  }

  @override
  String get accountNext => 'Next';

  @override
  String get accountGoal => 'Goal';

  @override
  String get accountLeft => 'Left';

  @override
  String get accountEnds => 'Ends';

  @override
  String get accountSpentMonth => 'Spent';

  @override
  String get accountIncomeMonth => 'Received';

  @override
  String accountOverpaid(String amount) {
    return '$amount overpaid';
  }

  @override
  String get actionAddIncome => 'Add income';

  @override
  String get actionTransfer => 'Transfer';

  @override
  String get actionExpense => 'Expense';

  @override
  String actionPayAmount(String amount) {
    return 'Pay $amount';
  }

  @override
  String get actionPayEllipsis => 'Pay…';

  @override
  String get actionExtraPayment => 'Extra payment';

  @override
  String get actionRecalculate => 'Recalculate';

  @override
  String get actionAddPurchase => 'Purchase';

  @override
  String get actionTopUp => 'Top up';

  @override
  String get accountSchedule => 'Schedule';

  @override
  String accountScheduleHint(String principal) {
    return '$principal borrowed';
  }

  @override
  String get accountTransactions => 'Transactions';

  @override
  String get accountArchive => 'Archive';

  @override
  String get accountUnarchive => 'Restore from archive';

  @override
  String get accountDeleteTitle => 'Delete account?';

  @override
  String get accountDeleteBody =>
      'The account has no transactions, nothing else is lost.';

  @override
  String get accountDeleteBlocked =>
      'An account with transactions can only be archived.';

  @override
  String get accountLoanOpened => 'Loan opened';

  @override
  String get accountOpening => 'Opening balance';

  @override
  String get accountNew => 'New account';

  @override
  String get accountEdit => 'Edit account';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldCurrency => 'Currency';

  @override
  String get fieldBalance => 'Current balance';

  @override
  String get fieldIcon => 'Icon';

  @override
  String get fieldColor => 'Color';

  @override
  String get fieldIncludeInTotal => 'Count in own funds';

  @override
  String get fieldTarget => 'Goal';

  @override
  String get fieldTargetDate => 'Goal date';

  @override
  String get fieldEndDate => 'End date';

  @override
  String get fieldLimit => 'Credit limit';

  @override
  String get fieldCurrentDebt => 'Current debt';

  @override
  String get fieldDueDay => 'Payment day';

  @override
  String get fieldMinPayment => 'Minimum payment';

  @override
  String get fieldPayFrom => 'Pay from';

  @override
  String get fieldKind => 'Kind';

  @override
  String dayOfMonth(int day) {
    return '$day of each month';
  }

  @override
  String get nameRequired => 'Enter a name';

  @override
  String get amountRequired => 'Enter an amount';

  @override
  String get currencyLocked =>
      'The currency cannot change once there are transactions';

  @override
  String get loanNew => 'New loan';

  @override
  String get loanAmount => 'Amount';

  @override
  String get loanRate => 'Rate';

  @override
  String get loanTotal => 'Total';

  @override
  String loanMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String loanTimes(String amount) {
    return '× $amount';
  }

  @override
  String get loanDrag => 'drag · 1 to 60 months';

  @override
  String get loanPerMonth => '/ mo';

  @override
  String get loanPerYear => '/ yr';

  @override
  String get loanPayment => 'Monthly payment';

  @override
  String get loanFirstPayment => 'First payment';

  @override
  String get loanMoreFields => 'More · name, pay from, reminders';

  @override
  String get loanCreate => 'Create loan';

  @override
  String loanDefaultName(String amount) {
    return 'Loan · $amount';
  }

  @override
  String get loanRecalcTitle => 'Recalculate schedule';

  @override
  String get loanRecalcKeepPayment => 'Keep the payment, fewer months';

  @override
  String get loanRecalcKeepTerm => 'Keep the term, smaller payment';

  @override
  String get loanRecalcNothing => 'Nothing left to pay';

  @override
  String get creditLineNew => 'New credit line';

  @override
  String get create => 'Create';

  @override
  String get paymentsUpcoming => 'Upcoming';

  @override
  String get paymentsRules => 'Rules';

  @override
  String get paymentsNext30 => 'Next 30 days';

  @override
  String get paymentsNewTooltip => 'New payment';

  @override
  String get groupOverdue => 'Overdue';

  @override
  String get groupToday => 'Today';

  @override
  String groupTomorrow(String date) {
    return 'Tomorrow · $date';
  }

  @override
  String get groupThisWeek => 'This week';

  @override
  String get groupLater => 'Later';

  @override
  String payAmount(String amount) {
    return 'Pay $amount';
  }

  @override
  String get enterAmount => 'Enter amount';

  @override
  String get payEllipsis => 'Pay…';

  @override
  String get skip => 'Skip';

  @override
  String overdueDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Overdue $count days',
      one: 'Overdue 1 day',
    );
    return '$_temp0';
  }

  @override
  String inDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count days',
      one: 'In 1 day',
    );
    return '$_temp0';
  }

  @override
  String get autoPayShort => 'auto-pay';

  @override
  String seqOf(int seq, int total) {
    return '$seq of $total';
  }

  @override
  String fromAccount(String name) {
    return 'from $name';
  }

  @override
  String get estimate => 'estimate';

  @override
  String minPaymentShort(String amount) {
    return 'min $amount';
  }

  @override
  String get rulesLoans => 'Loans';

  @override
  String get rulesCreditLines => 'Credit lines';

  @override
  String get rulesSubscriptions => 'Subscriptions';

  @override
  String get rulesUtilities => 'Utilities';

  @override
  String get rulesOther => 'Other';

  @override
  String perMonth(String amount) {
    return '$amount / month';
  }

  @override
  String pausedUntil(String date) {
    return 'Paused until $date';
  }

  @override
  String get paused => 'Paused';

  @override
  String get paymentsEmptyTitle => 'No payments yet';

  @override
  String get paymentsEmptyBody =>
      'Add subscriptions, utilities and loans — reminders will come by themselves.';

  @override
  String get nothingToPay => 'Nothing to pay';

  @override
  String occDue(String date) {
    return 'Due $date';
  }

  @override
  String get occAmountOnBill => 'Amount on the bill';

  @override
  String get occAmount => 'Amount';

  @override
  String occLastTime(String amount) {
    return 'Last time · $amount';
  }

  @override
  String occFrom(String name) {
    return 'From $name';
  }

  @override
  String occFull(String amount) {
    return 'Full $amount';
  }

  @override
  String occMinimum(String amount) {
    return 'Minimum $amount';
  }

  @override
  String get occOther => 'Other';

  @override
  String occApprox(String foreign, String local, String rate) {
    return '$foreign ≈ $local · $rate';
  }

  @override
  String get occEditRule => 'Edit payment';

  @override
  String occPaidOn(String date) {
    return 'Paid $date';
  }

  @override
  String get occSkipped => 'Skipped';

  @override
  String get occRestore => 'Restore';

  @override
  String get occChooseAccount => 'Choose an account to pay from';

  @override
  String get ruleNew => 'New payment';

  @override
  String get ruleEdit => 'Edit payment';

  @override
  String get ruleKindSubscription => 'Subscription';

  @override
  String get ruleKindUtility => 'Utility';

  @override
  String get ruleKindOther => 'Other';

  @override
  String get ruleKindLoan => 'Loan payment';

  @override
  String get ruleKindCreditLine => 'Card payment';

  @override
  String get ruleAmountVaries => 'Amount varies';

  @override
  String get ruleNextCharge => 'Next charge';

  @override
  String get ruleRepeat => 'Repeat';

  @override
  String get freqMonthly => 'Monthly';

  @override
  String get freqWeekly => 'Weekly';

  @override
  String get freqYearly => 'Yearly';

  @override
  String freqEveryNDays(int n) {
    return 'Every $n days';
  }

  @override
  String freqEveryNMonths(int n) {
    return 'Every $n months';
  }

  @override
  String get ruleEnds => 'Ends';

  @override
  String get ruleNoEnd => 'Never';

  @override
  String get ruleRemind => 'Remind';

  @override
  String remindDaysBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days before',
      one: '1 day before',
      zero: 'On the day',
    );
    return '$_temp0';
  }

  @override
  String get remindOff => 'Off';

  @override
  String get ruleRemindTime => 'Reminder time';

  @override
  String get ruleAutoPay => 'Auto-pay';

  @override
  String get ruleAutoPayHint => 'Charged by the bank, mark paid automatically';

  @override
  String get rulePauseUntil => 'Pause until…';

  @override
  String get rulePauseForever => 'Pause';

  @override
  String get ruleResume => 'Resume';

  @override
  String get ruleDeleteTitle => 'Delete payment?';

  @override
  String get ruleDeleteBody =>
      'Paid history stays; future reminders are removed.';

  @override
  String get ruleHistory => 'History';

  @override
  String get ruleNameHint => 'Netflix, rent, electricity…';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get statsSpent => 'Spent';

  @override
  String get statsIncome => 'Income';

  @override
  String get statsSaved => 'Saved';

  @override
  String get statsDebt => 'Debt';

  @override
  String get statsByCategory => 'By category';

  @override
  String get statsSixMonths => '6 months';

  @override
  String get statsDebtTrend => 'Debt, 12 months';

  @override
  String get statsEmpty => 'No expenses in this period';

  @override
  String get statsBudgets => 'Budgets';

  @override
  String get budgetsTitle => 'Budgets';

  @override
  String get budgetWholeMonth => 'Whole month';

  @override
  String get budgetSet => 'Set budget';

  @override
  String budgetOf(String spent, String budget) {
    return '$spent of $budget';
  }

  @override
  String budgetLeft(String amount) {
    return '$amount left';
  }

  @override
  String budgetOver(String amount) {
    return '$amount over';
  }

  @override
  String get budgetFromNextMonth => 'Apply from next month';

  @override
  String get budgetRemove => 'Remove budget';

  @override
  String get budgetNoCategories => 'Categories without a budget';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoryNew => 'New category';

  @override
  String get categoryEdit => 'Edit category';

  @override
  String get categoryDeleteTitle => 'Delete category?';

  @override
  String get categoryDeleteEmpty => 'There are no transactions in it.';

  @override
  String categoryMoveTo(String name) {
    return 'Its transactions move to $name.';
  }

  @override
  String get groceries => 'Groceries';

  @override
  String get cafe => 'Cafe';

  @override
  String get transport => 'Transport';

  @override
  String get taxi => 'Taxi';

  @override
  String get housing => 'Housing';

  @override
  String get utilities => 'Utilities';

  @override
  String get phone => 'Phone';

  @override
  String get subscriptions => 'Subscriptions';

  @override
  String get health => 'Health';

  @override
  String get clothes => 'Clothes';

  @override
  String get entertainment => 'Fun';

  @override
  String get education => 'Education';

  @override
  String get gifts => 'Gifts';

  @override
  String get travel => 'Travel';

  @override
  String get kids => 'Kids';

  @override
  String get pets => 'Pets';

  @override
  String get otherExpense => 'Other';

  @override
  String get salary => 'Salary';

  @override
  String get freelance => 'Side job';

  @override
  String get giftIncome => 'Gifts';

  @override
  String get interest => 'Interest';

  @override
  String get otherIncome => 'Other';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get settingsBaseCurrency => 'Main currency';

  @override
  String get settingsRates => 'Exchange rates';

  @override
  String get settingsMonthStart => 'Month starts on';

  @override
  String get settingsReminders => 'Reminders';

  @override
  String get settingsReminderTime => 'Default time';

  @override
  String get settingsDigest => 'Morning digest';

  @override
  String get settingsDigestTime => 'Digest time';

  @override
  String get settingsNotificationsOff =>
      'Notifications are turned off in iOS Settings';

  @override
  String get settingsFaceId => 'Face ID lock';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get settingsCategories => 'Categories';

  @override
  String get settingsBudgets => 'Budgets';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAboutBody =>
      'Your data stays on this iPhone and is not encrypted; Face ID only locks the screen. Make a backup from time to time.';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get ratesTitle => 'Exchange rates';

  @override
  String get ratesBase => 'Main currency';

  @override
  String get ratesRefresh => 'Refresh from NBKR';

  @override
  String get ratesManual => 'manual';

  @override
  String get ratesNbkr => 'NBKR';

  @override
  String ratesUpdated(String date) {
    return 'Updated $date';
  }

  @override
  String ratesSetTitle(String code, String base) {
    return '1 $code in $base';
  }

  @override
  String get ratesEmpty =>
      'Rates appear here when an account or a payment uses another currency.';

  @override
  String get ratesFetchFailed =>
      'Could not reach NBKR. Enter the rate by hand.';

  @override
  String get ratesNoRate => 'no rate';

  @override
  String get ratesChangeBaseTitle => 'Change main currency?';

  @override
  String get ratesChangeBaseBody =>
      'Totals, statistics and budgets will be recalculated at the current rates.';

  @override
  String ratesMissingRate(String code) {
    return 'Enter the rate for $code first';
  }

  @override
  String get ratesAdd => 'Add currency';

  @override
  String get change => 'Change';

  @override
  String get backupTitle => 'Backup';

  @override
  String get backupExport => 'Make a backup';

  @override
  String get backupImport => 'Restore from a file…';

  @override
  String get backupFiles => 'Saved backups';

  @override
  String get backupHint =>
      'The backup is a JSON file. Keep it in Files, iCloud Drive or send it to yourself.';

  @override
  String get backupImportTitle => 'Replace all data?';

  @override
  String get backupImportBody =>
      'Everything in the app now will be replaced with the backup.';

  @override
  String get backupReplace => 'Replace';

  @override
  String get backupRestored => 'Data restored';

  @override
  String get backupErrorFormat => 'This file is not a backup of this app';

  @override
  String get backupErrorVersion => 'Update the app to open this backup';

  @override
  String backupErrorBroken(String detail) {
    return 'The backup is damaged: $detail';
  }

  @override
  String get lockUnlock => 'Unlock with Face ID';

  @override
  String get lockReason => 'Unlock to see your finances';

  @override
  String get lockUnavailable => 'Face ID is not set up on this iPhone';

  @override
  String get notifDigestTitle => 'Payments today';

  @override
  String notifDigestBody(int count, String total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payments · $total',
      one: '1 payment · $total',
    );
    return '$_temp0';
  }

  @override
  String notifDueToday(String amount) {
    return 'Due today · $amount';
  }

  @override
  String notifDueTomorrow(String amount) {
    return 'Due tomorrow · $amount';
  }

  @override
  String notifDueIn(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Due in $count days · $amount',
    );
    return '$_temp0';
  }

  @override
  String get notifAmountNotSet => 'amount not set';

  @override
  String get notifActionPaid => 'Paid';

  @override
  String get notifActionSnooze => 'Remind tomorrow';

  @override
  String notifResumes(String name, String date) {
    return '$name resumes $date';
  }

  @override
  String get notifAlreadyPaid => 'Already paid';

  @override
  String get statsLoanPayments => 'Loan payments';

  @override
  String get statsPrevMonth => 'Previous month';

  @override
  String get statsNextMonth => 'Next month';

  @override
  String get budgetAmount => 'Budget for the month';

  @override
  String get settingsRemindersHint =>
      'Reminders before payments and the morning digest';

  @override
  String ratesLine(String code, String rate) {
    return '1 $code = $rate';
  }
}
