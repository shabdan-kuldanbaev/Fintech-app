import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Fintech'**
  String get appTitle;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get tabPayments;

  /// No description provided for @tabAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get tabAccounts;

  /// No description provided for @actionAddExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get actionAddExpense;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @notFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get notFoundTitle;

  /// No description provided for @notFoundBody.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted.'**
  String get notFoundBody;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get optional;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @startupIncompatibleTitle.
  ///
  /// In en, this message translates to:
  /// **'Reinstall the app'**
  String get startupIncompatibleTitle;

  /// No description provided for @startupIncompatibleBody.
  ///
  /// In en, this message translates to:
  /// **'This build cannot open the data of the previous one. Delete the app and install it again.'**
  String get startupIncompatibleBody;

  /// No description provided for @startupUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get startupUnknownTitle;

  /// No description provided for @startupUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'The app could not start. Try again.'**
  String get startupUnknownBody;

  /// No description provided for @startupDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get startupDetails;

  /// No description provided for @homeSafeToSpend.
  ///
  /// In en, this message translates to:
  /// **'Safe to spend until {date}'**
  String homeSafeToSpend(String date);

  /// No description provided for @homeOwnFunds.
  ///
  /// In en, this message translates to:
  /// **'Own funds'**
  String get homeOwnFunds;

  /// No description provided for @homeToPay.
  ///
  /// In en, this message translates to:
  /// **'To pay'**
  String get homeToPay;

  /// No description provided for @homeQuickAdd.
  ///
  /// In en, this message translates to:
  /// **'Quick add · 1 tap'**
  String get homeQuickAdd;

  /// No description provided for @homeUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get homeUpcoming;

  /// No description provided for @homeUpcomingTotal.
  ///
  /// In en, this message translates to:
  /// **'30 days · {total}'**
  String homeUpcomingTotal(String total);

  /// No description provided for @homeRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get homeRecent;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first expense'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap + right after a purchase: amount, category — saved.'**
  String get homeEmptyBody;

  /// No description provided for @homeCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency: {code}'**
  String homeCurrency(String code);

  /// No description provided for @homeStats.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get homeStats;

  /// No description provided for @homeSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettings;

  /// No description provided for @homeNoRate.
  ///
  /// In en, this message translates to:
  /// **'Some accounts have no exchange rate and are not counted'**
  String get homeNoRate;

  /// No description provided for @addTitle.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addTitle;

  /// No description provided for @kindExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get kindExpense;

  /// No description provided for @kindIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get kindIncome;

  /// No description provided for @kindTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get kindTransfer;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get addNote;

  /// No description provided for @addNoteHint.
  ///
  /// In en, this message translates to:
  /// **'What was it?'**
  String get addNoteHint;

  /// No description provided for @addCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Category · tap to save'**
  String get addCategoryHint;

  /// No description provided for @addQuick.
  ///
  /// In en, this message translates to:
  /// **'Frequent · 1 tap'**
  String get addQuick;

  /// No description provided for @addFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get addFrom;

  /// No description provided for @addToHint.
  ///
  /// In en, this message translates to:
  /// **'To · tap to save'**
  String get addToHint;

  /// No description provided for @addEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount first'**
  String get addEnterAmount;

  /// No description provided for @addCounterAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount in {currency}'**
  String addCounterAmount(String currency);

  /// No description provided for @addRateHint.
  ///
  /// In en, this message translates to:
  /// **'At the rate {rate}'**
  String addRateHint(String rate);

  /// No description provided for @addNoOtherAccount.
  ///
  /// In en, this message translates to:
  /// **'No other account yet. Add one on the Accounts tab.'**
  String get addNoOtherAccount;

  /// No description provided for @addMissingRate.
  ///
  /// In en, this message translates to:
  /// **'No rate for {code}. Enter it in Settings → Exchange rates.'**
  String addMissingRate(String code);

  /// No description provided for @pickAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get pickAccount;

  /// No description provided for @pickDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get pickDate;

  /// No description provided for @pickCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get pickCategory;

  /// No description provided for @savedToast.
  ///
  /// In en, this message translates to:
  /// **'Saved · {label}'**
  String savedToast(String label);

  /// No description provided for @deletedToast.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deletedToast;

  /// No description provided for @paidToast.
  ///
  /// In en, this message translates to:
  /// **'Paid · {label}'**
  String paidToast(String label);

  /// No description provided for @skippedToast.
  ///
  /// In en, this message translates to:
  /// **'Skipped · {label}'**
  String skippedToast(String label);

  /// No description provided for @unpaidToast.
  ///
  /// In en, this message translates to:
  /// **'Payment undone · {label}'**
  String unpaidToast(String label);

  /// No description provided for @changesSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get changesSaved;

  /// No description provided for @txAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get txAmount;

  /// No description provided for @txCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get txCategory;

  /// No description provided for @txAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get txAccount;

  /// No description provided for @txFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get txFrom;

  /// No description provided for @txTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get txTo;

  /// No description provided for @txDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get txDate;

  /// No description provided for @txNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get txNote;

  /// No description provided for @txPaymentFor.
  ///
  /// In en, this message translates to:
  /// **'Payment for {rule} · {date}'**
  String txPaymentFor(String rule, String date);

  /// No description provided for @txUndoPayment.
  ///
  /// In en, this message translates to:
  /// **'Undo payment'**
  String get txUndoPayment;

  /// No description provided for @txAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get txAllTitle;

  /// No description provided for @txSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search notes and categories'**
  String get txSearchHint;

  /// No description provided for @txEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get txEmpty;

  /// No description provided for @filterAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get filterAccount;

  /// No description provided for @filterCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get filterCategory;

  /// No description provided for @filterKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get filterKind;

  /// No description provided for @filterMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get filterMonth;

  /// No description provided for @filterAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get filterAny;

  /// No description provided for @adjustment.
  ///
  /// In en, this message translates to:
  /// **'Balance correction'**
  String get adjustment;

  /// No description provided for @accountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountsTitle;

  /// No description provided for @accountsMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get accountsMoney;

  /// No description provided for @accountsCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get accountsCredit;

  /// No description provided for @accountsArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived accounts · {count}'**
  String accountsArchived(int count);

  /// No description provided for @accountsNewMenu.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get accountsNewMenu;

  /// No description provided for @accountKindCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get accountKindCash;

  /// No description provided for @accountKindCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get accountKindCard;

  /// No description provided for @accountKindCreditLine.
  ///
  /// In en, this message translates to:
  /// **'Credit line'**
  String get accountKindCreditLine;

  /// No description provided for @accountKindLoan.
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get accountKindLoan;

  /// No description provided for @accountKindSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings goal'**
  String get accountKindSavings;

  /// No description provided for @accountKindDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get accountKindDeposit;

  /// No description provided for @accountsNewCashOrCard.
  ///
  /// In en, this message translates to:
  /// **'Cash or card'**
  String get accountsNewCashOrCard;

  /// No description provided for @cashDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cashDefaultName;

  /// No description provided for @accountThisMonth.
  ///
  /// In en, this message translates to:
  /// **'{amount} this month'**
  String accountThisMonth(String amount);

  /// No description provided for @accountAvailableOf.
  ///
  /// In en, this message translates to:
  /// **'{available} available of {limit}'**
  String accountAvailableOf(String available, String limit);

  /// No description provided for @accountLoanProgress.
  ///
  /// In en, this message translates to:
  /// **'{paid} of {total} paid · {payment} / month'**
  String accountLoanProgress(int paid, int total, String payment);

  /// No description provided for @accountGoalOf.
  ///
  /// In en, this message translates to:
  /// **'of {target} · {percent}%'**
  String accountGoalOf(String target, int percent);

  /// No description provided for @accountByDate.
  ///
  /// In en, this message translates to:
  /// **'by {date}'**
  String accountByDate(String date);

  /// No description provided for @accountDueDate.
  ///
  /// In en, this message translates to:
  /// **'due {date}'**
  String accountDueDate(String date);

  /// No description provided for @accountNextDate.
  ///
  /// In en, this message translates to:
  /// **'next {date}'**
  String accountNextDate(String date);

  /// No description provided for @accountDebtTotal.
  ///
  /// In en, this message translates to:
  /// **'debt {amount}'**
  String accountDebtTotal(String amount);

  /// No description provided for @accountNoRate.
  ///
  /// In en, this message translates to:
  /// **'no rate'**
  String get accountNoRate;

  /// No description provided for @accountBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get accountBalance;

  /// No description provided for @accountDebt.
  ///
  /// In en, this message translates to:
  /// **'Debt'**
  String get accountDebt;

  /// No description provided for @accountRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get accountRemaining;

  /// No description provided for @accountLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get accountLimit;

  /// No description provided for @accountAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get accountAvailable;

  /// No description provided for @accountDueDay.
  ///
  /// In en, this message translates to:
  /// **'Due day'**
  String get accountDueDay;

  /// No description provided for @accountMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get accountMonthly;

  /// No description provided for @accountPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get accountPaid;

  /// No description provided for @accountPaidOf.
  ///
  /// In en, this message translates to:
  /// **'{paid} of {total}'**
  String accountPaidOf(int paid, int total);

  /// No description provided for @accountNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get accountNext;

  /// No description provided for @accountGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get accountGoal;

  /// No description provided for @accountLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get accountLeft;

  /// No description provided for @accountEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get accountEnds;

  /// No description provided for @accountSpentMonth.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get accountSpentMonth;

  /// No description provided for @accountIncomeMonth.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get accountIncomeMonth;

  /// No description provided for @accountOverpaid.
  ///
  /// In en, this message translates to:
  /// **'{amount} overpaid'**
  String accountOverpaid(String amount);

  /// No description provided for @actionAddIncome.
  ///
  /// In en, this message translates to:
  /// **'Add income'**
  String get actionAddIncome;

  /// No description provided for @actionTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get actionTransfer;

  /// No description provided for @actionExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get actionExpense;

  /// No description provided for @actionPayAmount.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String actionPayAmount(String amount);

  /// No description provided for @actionPayEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Pay…'**
  String get actionPayEllipsis;

  /// No description provided for @actionExtraPayment.
  ///
  /// In en, this message translates to:
  /// **'Extra payment'**
  String get actionExtraPayment;

  /// No description provided for @actionRecalculate.
  ///
  /// In en, this message translates to:
  /// **'Recalculate'**
  String get actionRecalculate;

  /// No description provided for @actionAddPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get actionAddPurchase;

  /// No description provided for @actionTopUp.
  ///
  /// In en, this message translates to:
  /// **'Top up'**
  String get actionTopUp;

  /// No description provided for @accountSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get accountSchedule;

  /// No description provided for @accountScheduleHint.
  ///
  /// In en, this message translates to:
  /// **'{principal} borrowed'**
  String accountScheduleHint(String principal);

  /// No description provided for @accountTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get accountTransactions;

  /// No description provided for @accountArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get accountArchive;

  /// No description provided for @accountUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Restore from archive'**
  String get accountUnarchive;

  /// No description provided for @accountDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get accountDeleteTitle;

  /// No description provided for @accountDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The account has no transactions, nothing else is lost.'**
  String get accountDeleteBody;

  /// No description provided for @accountDeleteBlocked.
  ///
  /// In en, this message translates to:
  /// **'An account with transactions can only be archived.'**
  String get accountDeleteBlocked;

  /// No description provided for @accountLoanOpened.
  ///
  /// In en, this message translates to:
  /// **'Loan opened'**
  String get accountLoanOpened;

  /// No description provided for @accountOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get accountOpening;

  /// No description provided for @accountNew.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get accountNew;

  /// No description provided for @accountEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit account'**
  String get accountEdit;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @fieldCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get fieldCurrency;

  /// No description provided for @fieldBalance.
  ///
  /// In en, this message translates to:
  /// **'Current balance'**
  String get fieldBalance;

  /// No description provided for @fieldIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get fieldIcon;

  /// No description provided for @fieldColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get fieldColor;

  /// No description provided for @fieldIncludeInTotal.
  ///
  /// In en, this message translates to:
  /// **'Count in own funds'**
  String get fieldIncludeInTotal;

  /// No description provided for @fieldTarget.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get fieldTarget;

  /// No description provided for @fieldTargetDate.
  ///
  /// In en, this message translates to:
  /// **'Goal date'**
  String get fieldTargetDate;

  /// No description provided for @fieldEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get fieldEndDate;

  /// No description provided for @fieldLimit.
  ///
  /// In en, this message translates to:
  /// **'Credit limit'**
  String get fieldLimit;

  /// No description provided for @fieldCurrentDebt.
  ///
  /// In en, this message translates to:
  /// **'Current debt'**
  String get fieldCurrentDebt;

  /// No description provided for @fieldDueDay.
  ///
  /// In en, this message translates to:
  /// **'Payment day'**
  String get fieldDueDay;

  /// No description provided for @fieldMinPayment.
  ///
  /// In en, this message translates to:
  /// **'Minimum payment'**
  String get fieldMinPayment;

  /// No description provided for @fieldPayFrom.
  ///
  /// In en, this message translates to:
  /// **'Pay from'**
  String get fieldPayFrom;

  /// No description provided for @fieldKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get fieldKind;

  /// No description provided for @dayOfMonth.
  ///
  /// In en, this message translates to:
  /// **'{day} of each month'**
  String dayOfMonth(int day);

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get nameRequired;

  /// No description provided for @amountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get amountRequired;

  /// No description provided for @currencyLocked.
  ///
  /// In en, this message translates to:
  /// **'The currency cannot change once there are transactions'**
  String get currencyLocked;

  /// No description provided for @loanNew.
  ///
  /// In en, this message translates to:
  /// **'New loan'**
  String get loanNew;

  /// No description provided for @loanAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get loanAmount;

  /// No description provided for @loanRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get loanRate;

  /// No description provided for @loanTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get loanTotal;

  /// No description provided for @loanMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String loanMonths(int count);

  /// No description provided for @loanTimes.
  ///
  /// In en, this message translates to:
  /// **'× {amount}'**
  String loanTimes(String amount);

  /// No description provided for @loanDrag.
  ///
  /// In en, this message translates to:
  /// **'drag · 1 to 60 months'**
  String get loanDrag;

  /// No description provided for @loanPerMonth.
  ///
  /// In en, this message translates to:
  /// **'/ mo'**
  String get loanPerMonth;

  /// No description provided for @loanPerYear.
  ///
  /// In en, this message translates to:
  /// **'/ yr'**
  String get loanPerYear;

  /// No description provided for @loanPayment.
  ///
  /// In en, this message translates to:
  /// **'Monthly payment'**
  String get loanPayment;

  /// No description provided for @loanFirstPayment.
  ///
  /// In en, this message translates to:
  /// **'First payment'**
  String get loanFirstPayment;

  /// No description provided for @loanMoreFields.
  ///
  /// In en, this message translates to:
  /// **'More · name, pay from, reminders'**
  String get loanMoreFields;

  /// No description provided for @loanCreate.
  ///
  /// In en, this message translates to:
  /// **'Create loan'**
  String get loanCreate;

  /// No description provided for @loanDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Loan · {amount}'**
  String loanDefaultName(String amount);

  /// No description provided for @loanRecalcTitle.
  ///
  /// In en, this message translates to:
  /// **'Recalculate schedule'**
  String get loanRecalcTitle;

  /// No description provided for @loanRecalcKeepPayment.
  ///
  /// In en, this message translates to:
  /// **'Keep the payment, fewer months'**
  String get loanRecalcKeepPayment;

  /// No description provided for @loanRecalcKeepTerm.
  ///
  /// In en, this message translates to:
  /// **'Keep the term, smaller payment'**
  String get loanRecalcKeepTerm;

  /// No description provided for @loanRecalcNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing left to pay'**
  String get loanRecalcNothing;

  /// No description provided for @creditLineNew.
  ///
  /// In en, this message translates to:
  /// **'New credit line'**
  String get creditLineNew;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @paymentsUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get paymentsUpcoming;

  /// No description provided for @paymentsRules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get paymentsRules;

  /// No description provided for @paymentsNext30.
  ///
  /// In en, this message translates to:
  /// **'Next 30 days'**
  String get paymentsNext30;

  /// No description provided for @paymentsNewTooltip.
  ///
  /// In en, this message translates to:
  /// **'New payment'**
  String get paymentsNewTooltip;

  /// No description provided for @groupOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get groupOverdue;

  /// No description provided for @groupToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get groupToday;

  /// No description provided for @groupTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow · {date}'**
  String groupTomorrow(String date);

  /// No description provided for @groupThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get groupThisWeek;

  /// No description provided for @groupLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get groupLater;

  /// No description provided for @payAmount.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String payAmount(String amount);

  /// No description provided for @enterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get enterAmount;

  /// No description provided for @payEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Pay…'**
  String get payEllipsis;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @overdueDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Overdue 1 day} other{Overdue {count} days}}'**
  String overdueDays(int count);

  /// No description provided for @inDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{In 1 day} other{In {count} days}}'**
  String inDays(int count);

  /// No description provided for @autoPayShort.
  ///
  /// In en, this message translates to:
  /// **'auto-pay'**
  String get autoPayShort;

  /// No description provided for @seqOf.
  ///
  /// In en, this message translates to:
  /// **'{seq} of {total}'**
  String seqOf(int seq, int total);

  /// No description provided for @fromAccount.
  ///
  /// In en, this message translates to:
  /// **'from {name}'**
  String fromAccount(String name);

  /// No description provided for @estimate.
  ///
  /// In en, this message translates to:
  /// **'estimate'**
  String get estimate;

  /// No description provided for @minPaymentShort.
  ///
  /// In en, this message translates to:
  /// **'min {amount}'**
  String minPaymentShort(String amount);

  /// No description provided for @rulesLoans.
  ///
  /// In en, this message translates to:
  /// **'Loans'**
  String get rulesLoans;

  /// No description provided for @rulesCreditLines.
  ///
  /// In en, this message translates to:
  /// **'Credit lines'**
  String get rulesCreditLines;

  /// No description provided for @rulesSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get rulesSubscriptions;

  /// No description provided for @rulesUtilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get rulesUtilities;

  /// No description provided for @rulesOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get rulesOther;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'{amount} / month'**
  String perMonth(String amount);

  /// No description provided for @pausedUntil.
  ///
  /// In en, this message translates to:
  /// **'Paused until {date}'**
  String pausedUntil(String date);

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @paymentsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No payments yet'**
  String get paymentsEmptyTitle;

  /// No description provided for @paymentsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add subscriptions, utilities and loans — reminders will come by themselves.'**
  String get paymentsEmptyBody;

  /// No description provided for @nothingToPay.
  ///
  /// In en, this message translates to:
  /// **'Nothing to pay'**
  String get nothingToPay;

  /// No description provided for @occDue.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String occDue(String date);

  /// No description provided for @occAmountOnBill.
  ///
  /// In en, this message translates to:
  /// **'Amount on the bill'**
  String get occAmountOnBill;

  /// No description provided for @occAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get occAmount;

  /// No description provided for @occLastTime.
  ///
  /// In en, this message translates to:
  /// **'Last time · {amount}'**
  String occLastTime(String amount);

  /// No description provided for @occFrom.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String occFrom(String name);

  /// No description provided for @occFull.
  ///
  /// In en, this message translates to:
  /// **'Full {amount}'**
  String occFull(String amount);

  /// No description provided for @occMinimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum {amount}'**
  String occMinimum(String amount);

  /// No description provided for @occOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get occOther;

  /// No description provided for @occApprox.
  ///
  /// In en, this message translates to:
  /// **'{foreign} ≈ {local} · {rate}'**
  String occApprox(String foreign, String local, String rate);

  /// No description provided for @occEditRule.
  ///
  /// In en, this message translates to:
  /// **'Edit payment'**
  String get occEditRule;

  /// No description provided for @occPaidOn.
  ///
  /// In en, this message translates to:
  /// **'Paid {date}'**
  String occPaidOn(String date);

  /// No description provided for @occSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get occSkipped;

  /// No description provided for @occRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get occRestore;

  /// No description provided for @occChooseAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose an account to pay from'**
  String get occChooseAccount;

  /// No description provided for @ruleNew.
  ///
  /// In en, this message translates to:
  /// **'New payment'**
  String get ruleNew;

  /// No description provided for @ruleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit payment'**
  String get ruleEdit;

  /// No description provided for @ruleKindSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get ruleKindSubscription;

  /// No description provided for @ruleKindUtility.
  ///
  /// In en, this message translates to:
  /// **'Utility'**
  String get ruleKindUtility;

  /// No description provided for @ruleKindOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get ruleKindOther;

  /// No description provided for @ruleKindLoan.
  ///
  /// In en, this message translates to:
  /// **'Loan payment'**
  String get ruleKindLoan;

  /// No description provided for @ruleKindCreditLine.
  ///
  /// In en, this message translates to:
  /// **'Card payment'**
  String get ruleKindCreditLine;

  /// No description provided for @ruleAmountVaries.
  ///
  /// In en, this message translates to:
  /// **'Amount varies'**
  String get ruleAmountVaries;

  /// No description provided for @ruleNextCharge.
  ///
  /// In en, this message translates to:
  /// **'Next charge'**
  String get ruleNextCharge;

  /// No description provided for @ruleRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get ruleRepeat;

  /// No description provided for @freqMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get freqMonthly;

  /// No description provided for @freqWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get freqWeekly;

  /// No description provided for @freqYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get freqYearly;

  /// No description provided for @freqEveryNDays.
  ///
  /// In en, this message translates to:
  /// **'Every {n} days'**
  String freqEveryNDays(int n);

  /// No description provided for @freqEveryNMonths.
  ///
  /// In en, this message translates to:
  /// **'Every {n} months'**
  String freqEveryNMonths(int n);

  /// No description provided for @ruleEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get ruleEnds;

  /// No description provided for @ruleNoEnd.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get ruleNoEnd;

  /// No description provided for @ruleRemind.
  ///
  /// In en, this message translates to:
  /// **'Remind'**
  String get ruleRemind;

  /// No description provided for @remindDaysBefore.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{On the day} =1{1 day before} other{{count} days before}}'**
  String remindDaysBefore(int count);

  /// No description provided for @remindOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get remindOff;

  /// No description provided for @ruleRemindTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get ruleRemindTime;

  /// No description provided for @ruleAutoPay.
  ///
  /// In en, this message translates to:
  /// **'Auto-pay'**
  String get ruleAutoPay;

  /// No description provided for @ruleAutoPayHint.
  ///
  /// In en, this message translates to:
  /// **'Charged by the bank, mark paid automatically'**
  String get ruleAutoPayHint;

  /// No description provided for @rulePauseUntil.
  ///
  /// In en, this message translates to:
  /// **'Pause until…'**
  String get rulePauseUntil;

  /// No description provided for @rulePauseForever.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get rulePauseForever;

  /// No description provided for @ruleResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get ruleResume;

  /// No description provided for @ruleDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete payment?'**
  String get ruleDeleteTitle;

  /// No description provided for @ruleDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Paid history stays; future reminders are removed.'**
  String get ruleDeleteBody;

  /// No description provided for @ruleHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get ruleHistory;

  /// No description provided for @ruleNameHint.
  ///
  /// In en, this message translates to:
  /// **'Netflix, rent, electricity…'**
  String get ruleNameHint;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsTitle;

  /// No description provided for @statsSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get statsSpent;

  /// No description provided for @statsIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get statsIncome;

  /// No description provided for @statsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get statsSaved;

  /// No description provided for @statsDebt.
  ///
  /// In en, this message translates to:
  /// **'Debt'**
  String get statsDebt;

  /// No description provided for @statsByCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get statsByCategory;

  /// No description provided for @statsSixMonths.
  ///
  /// In en, this message translates to:
  /// **'6 months'**
  String get statsSixMonths;

  /// No description provided for @statsDebtTrend.
  ///
  /// In en, this message translates to:
  /// **'Debt, 12 months'**
  String get statsDebtTrend;

  /// No description provided for @statsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No expenses in this period'**
  String get statsEmpty;

  /// No description provided for @statsBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get statsBudgets;

  /// No description provided for @budgetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get budgetsTitle;

  /// No description provided for @budgetWholeMonth.
  ///
  /// In en, this message translates to:
  /// **'Whole month'**
  String get budgetWholeMonth;

  /// No description provided for @budgetSet.
  ///
  /// In en, this message translates to:
  /// **'Set budget'**
  String get budgetSet;

  /// No description provided for @budgetOf.
  ///
  /// In en, this message translates to:
  /// **'{spent} of {budget}'**
  String budgetOf(String spent, String budget);

  /// No description provided for @budgetLeft.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String budgetLeft(String amount);

  /// No description provided for @budgetOver.
  ///
  /// In en, this message translates to:
  /// **'{amount} over'**
  String budgetOver(String amount);

  /// No description provided for @budgetFromNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Apply from next month'**
  String get budgetFromNextMonth;

  /// No description provided for @budgetRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove budget'**
  String get budgetRemove;

  /// No description provided for @budgetNoCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories without a budget'**
  String get budgetNoCategories;

  /// No description provided for @categoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// No description provided for @categoryNew.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get categoryNew;

  /// No description provided for @categoryEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get categoryEdit;

  /// No description provided for @categoryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete category?'**
  String get categoryDeleteTitle;

  /// No description provided for @categoryDeleteEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no transactions in it.'**
  String get categoryDeleteEmpty;

  /// No description provided for @categoryMoveTo.
  ///
  /// In en, this message translates to:
  /// **'Its transactions move to {name}.'**
  String categoryMoveTo(String name);

  /// No description provided for @groceries.
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get groceries;

  /// No description provided for @cafe.
  ///
  /// In en, this message translates to:
  /// **'Cafe'**
  String get cafe;

  /// No description provided for @transport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get transport;

  /// No description provided for @taxi.
  ///
  /// In en, this message translates to:
  /// **'Taxi'**
  String get taxi;

  /// No description provided for @housing.
  ///
  /// In en, this message translates to:
  /// **'Housing'**
  String get housing;

  /// No description provided for @utilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get utilities;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @subscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get subscriptions;

  /// No description provided for @health.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get health;

  /// No description provided for @clothes.
  ///
  /// In en, this message translates to:
  /// **'Clothes'**
  String get clothes;

  /// No description provided for @entertainment.
  ///
  /// In en, this message translates to:
  /// **'Fun'**
  String get entertainment;

  /// No description provided for @education.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get education;

  /// No description provided for @gifts.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get gifts;

  /// No description provided for @travel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get travel;

  /// No description provided for @kids.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get kids;

  /// No description provided for @pets.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get pets;

  /// No description provided for @otherExpense.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get otherExpense;

  /// No description provided for @salary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get salary;

  /// No description provided for @freelance.
  ///
  /// In en, this message translates to:
  /// **'Side job'**
  String get freelance;

  /// No description provided for @giftIncome.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get giftIncome;

  /// No description provided for @interest.
  ///
  /// In en, this message translates to:
  /// **'Interest'**
  String get interest;

  /// No description provided for @otherIncome.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get otherIncome;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @settingsBaseCurrency.
  ///
  /// In en, this message translates to:
  /// **'Main currency'**
  String get settingsBaseCurrency;

  /// No description provided for @settingsRates.
  ///
  /// In en, this message translates to:
  /// **'Exchange rates'**
  String get settingsRates;

  /// No description provided for @settingsMonthStart.
  ///
  /// In en, this message translates to:
  /// **'Month starts on'**
  String get settingsMonthStart;

  /// No description provided for @settingsReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsReminders;

  /// No description provided for @settingsReminderTime.
  ///
  /// In en, this message translates to:
  /// **'Default time'**
  String get settingsReminderTime;

  /// No description provided for @settingsDigest.
  ///
  /// In en, this message translates to:
  /// **'Morning digest'**
  String get settingsDigest;

  /// No description provided for @settingsDigestTime.
  ///
  /// In en, this message translates to:
  /// **'Digest time'**
  String get settingsDigestTime;

  /// No description provided for @settingsNotificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off in iOS Settings'**
  String get settingsNotificationsOff;

  /// No description provided for @settingsFaceId.
  ///
  /// In en, this message translates to:
  /// **'Face ID lock'**
  String get settingsFaceId;

  /// No description provided for @settingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsBackup;

  /// No description provided for @settingsCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get settingsCategories;

  /// No description provided for @settingsBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get settingsBudgets;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAboutBody.
  ///
  /// In en, this message translates to:
  /// **'Your data stays on this iPhone and is not encrypted; Face ID only locks the screen. Make a backup from time to time.'**
  String get settingsAboutBody;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// No description provided for @ratesTitle.
  ///
  /// In en, this message translates to:
  /// **'Exchange rates'**
  String get ratesTitle;

  /// No description provided for @ratesBase.
  ///
  /// In en, this message translates to:
  /// **'Main currency'**
  String get ratesBase;

  /// No description provided for @ratesRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh from NBKR'**
  String get ratesRefresh;

  /// No description provided for @ratesManual.
  ///
  /// In en, this message translates to:
  /// **'manual'**
  String get ratesManual;

  /// No description provided for @ratesNbkr.
  ///
  /// In en, this message translates to:
  /// **'NBKR'**
  String get ratesNbkr;

  /// No description provided for @ratesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String ratesUpdated(String date);

  /// No description provided for @ratesSetTitle.
  ///
  /// In en, this message translates to:
  /// **'1 {code} in {base}'**
  String ratesSetTitle(String code, String base);

  /// No description provided for @ratesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Rates appear here when an account or a payment uses another currency.'**
  String get ratesEmpty;

  /// No description provided for @ratesFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reach NBKR. Enter the rate by hand.'**
  String get ratesFetchFailed;

  /// No description provided for @ratesNoRate.
  ///
  /// In en, this message translates to:
  /// **'no rate'**
  String get ratesNoRate;

  /// No description provided for @ratesChangeBaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Change main currency?'**
  String get ratesChangeBaseTitle;

  /// No description provided for @ratesChangeBaseBody.
  ///
  /// In en, this message translates to:
  /// **'Totals, statistics and budgets will be recalculated at the current rates.'**
  String get ratesChangeBaseBody;

  /// No description provided for @ratesMissingRate.
  ///
  /// In en, this message translates to:
  /// **'Enter the rate for {code} first'**
  String ratesMissingRate(String code);

  /// No description provided for @ratesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add currency'**
  String get ratesAdd;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupTitle;

  /// No description provided for @backupExport.
  ///
  /// In en, this message translates to:
  /// **'Make a backup'**
  String get backupExport;

  /// No description provided for @backupImport.
  ///
  /// In en, this message translates to:
  /// **'Restore from a file…'**
  String get backupImport;

  /// No description provided for @backupFiles.
  ///
  /// In en, this message translates to:
  /// **'Saved backups'**
  String get backupFiles;

  /// No description provided for @backupHint.
  ///
  /// In en, this message translates to:
  /// **'The backup is a JSON file. Keep it in Files, iCloud Drive or send it to yourself.'**
  String get backupHint;

  /// No description provided for @backupImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace all data?'**
  String get backupImportTitle;

  /// No description provided for @backupImportBody.
  ///
  /// In en, this message translates to:
  /// **'Everything in the app now will be replaced with the backup.'**
  String get backupImportBody;

  /// No description provided for @backupReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get backupReplace;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Data restored'**
  String get backupRestored;

  /// No description provided for @backupErrorFormat.
  ///
  /// In en, this message translates to:
  /// **'This file is not a backup of this app'**
  String get backupErrorFormat;

  /// No description provided for @backupErrorVersion.
  ///
  /// In en, this message translates to:
  /// **'Update the app to open this backup'**
  String get backupErrorVersion;

  /// No description provided for @backupErrorBroken.
  ///
  /// In en, this message translates to:
  /// **'The backup is damaged: {detail}'**
  String backupErrorBroken(String detail);

  /// No description provided for @lockUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock with Face ID'**
  String get lockUnlock;

  /// No description provided for @lockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock to see your finances'**
  String get lockReason;

  /// No description provided for @lockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Face ID is not set up on this iPhone'**
  String get lockUnavailable;

  /// No description provided for @notifDigestTitle.
  ///
  /// In en, this message translates to:
  /// **'Payments today'**
  String get notifDigestTitle;

  /// No description provided for @notifDigestBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 payment · {total}} other{{count} payments · {total}}}'**
  String notifDigestBody(int count, String total);

  /// No description provided for @notifDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today · {amount}'**
  String notifDueToday(String amount);

  /// No description provided for @notifDueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Due tomorrow · {amount}'**
  String notifDueTomorrow(String amount);

  /// No description provided for @notifDueIn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{Due in {count} days · {amount}}}'**
  String notifDueIn(int count, String amount);

  /// No description provided for @notifAmountNotSet.
  ///
  /// In en, this message translates to:
  /// **'amount not set'**
  String get notifAmountNotSet;

  /// No description provided for @notifActionPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get notifActionPaid;

  /// No description provided for @notifActionSnooze.
  ///
  /// In en, this message translates to:
  /// **'Remind tomorrow'**
  String get notifActionSnooze;

  /// No description provided for @notifResumes.
  ///
  /// In en, this message translates to:
  /// **'{name} resumes {date}'**
  String notifResumes(String name, String date);

  /// No description provided for @notifAlreadyPaid.
  ///
  /// In en, this message translates to:
  /// **'Already paid'**
  String get notifAlreadyPaid;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
