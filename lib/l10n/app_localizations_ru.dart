// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Fintech';

  @override
  String get tabHome => 'Главная';

  @override
  String get tabPayments => 'Платежи';

  @override
  String get tabAccounts => 'Счета';

  @override
  String get actionAddExpense => 'Добавить расход';

  @override
  String get close => 'Закрыть';

  @override
  String get back => 'Назад';

  @override
  String get more => 'Ещё';

  @override
  String get save => 'Сохранить';

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String get edit => 'Изменить';

  @override
  String get undo => 'Отменить';

  @override
  String get done => 'Готово';

  @override
  String get next => 'Далее';

  @override
  String get retry => 'Повторить';

  @override
  String get all => 'Все';

  @override
  String get today => 'Сегодня';

  @override
  String get yesterday => 'Вчера';

  @override
  String get tomorrow => 'Завтра';

  @override
  String get notFoundTitle => 'Не найдено';

  @override
  String get notFoundBody => 'Возможно, его удалили.';

  @override
  String get optional => 'необязательно';

  @override
  String get none => 'Нет';

  @override
  String get startupIncompatibleTitle => 'Переустановите приложение';

  @override
  String get startupIncompatibleBody =>
      'Эта сборка не может открыть данные прошлой. Удалите приложение и установите заново.';

  @override
  String get startupUnknownTitle => 'Что-то пошло не так';

  @override
  String get startupUnknownBody =>
      'Приложение не запустилось. Попробуйте ещё раз.';

  @override
  String get startupDetails => 'Подробности';

  @override
  String homeSafeToSpend(String date) {
    return 'Можно тратить до $date';
  }

  @override
  String get homeOwnFunds => 'Свои деньги';

  @override
  String get homeToPay => 'К оплате';

  @override
  String get homeQuickAdd => 'Быстро · 1 касание';

  @override
  String get homeUpcoming => 'Скоро платить';

  @override
  String homeUpcomingTotal(String total) {
    return '30 дней · $total';
  }

  @override
  String get homeRecent => 'Недавние';

  @override
  String get homeEmptyTitle => 'Добавьте первый расход';

  @override
  String get homeEmptyBody =>
      'Нажмите + сразу после покупки: сумма, категория — записано.';

  @override
  String homeCurrency(String code) {
    return 'Валюта: $code';
  }

  @override
  String get homeStats => 'Статистика';

  @override
  String get homeSettings => 'Настройки';

  @override
  String get homeNoRate => 'У части счетов нет курса — они не учтены';

  @override
  String get addTitle => 'Добавить';

  @override
  String get kindExpense => 'Расход';

  @override
  String get kindIncome => 'Доход';

  @override
  String get kindTransfer => 'Перевод';

  @override
  String get addNote => 'Заметка';

  @override
  String get addNoteHint => 'На что?';

  @override
  String get addCategoryHint => 'Категория · касание сохраняет';

  @override
  String get addQuick => 'Частые · 1 касание';

  @override
  String get addFrom => 'Откуда';

  @override
  String get addToHint => 'Куда · касание сохраняет';

  @override
  String get addEnterAmount => 'Сначала введите сумму';

  @override
  String addCounterAmount(String currency) {
    return 'Сумма в $currency';
  }

  @override
  String addRateHint(String rate) {
    return 'По курсу $rate';
  }

  @override
  String get addNoOtherAccount =>
      'Другого счёта пока нет. Добавьте его во вкладке «Счета».';

  @override
  String addMissingRate(String code) {
    return 'Нет курса $code. Введите его в Настройках → Курсы валют.';
  }

  @override
  String get pickAccount => 'Счёт';

  @override
  String get pickDate => 'Дата';

  @override
  String get pickCategory => 'Категория';

  @override
  String savedToast(String label) {
    return 'Записано · $label';
  }

  @override
  String get deletedToast => 'Удалено';

  @override
  String paidToast(String label) {
    return 'Оплачено · $label';
  }

  @override
  String skippedToast(String label) {
    return 'Пропущено · $label';
  }

  @override
  String get changesSaved => 'Сохранено';

  @override
  String get txAmount => 'Сумма';

  @override
  String get txCategory => 'Категория';

  @override
  String get txAccount => 'Счёт';

  @override
  String get txFrom => 'Откуда';

  @override
  String get txTo => 'Куда';

  @override
  String get txDate => 'Дата';

  @override
  String get txNote => 'Заметка';

  @override
  String txPaymentFor(String rule, String date) {
    return 'Оплата «$rule» · $date';
  }

  @override
  String get txUndoPayment => 'Отменить оплату';

  @override
  String get txAllTitle => 'Операции';

  @override
  String get txSearchHint => 'Поиск по заметкам и категориям';

  @override
  String get txEmpty => 'Здесь пока пусто';

  @override
  String get filterAccount => 'Счёт';

  @override
  String get filterCategory => 'Категория';

  @override
  String get filterKind => 'Вид';

  @override
  String get filterMonth => 'Месяц';

  @override
  String get filterAny => 'Любой';

  @override
  String get adjustment => 'Корректировка';

  @override
  String get accountsTitle => 'Счета';

  @override
  String get accountsMoney => 'Деньги';

  @override
  String get accountsCredit => 'Кредиты';

  @override
  String accountsArchived(int count) {
    return 'В архиве · $count';
  }

  @override
  String get accountsNewMenu => 'Новый счёт';

  @override
  String get accountKindCash => 'Наличные';

  @override
  String get accountKindCard => 'Карта';

  @override
  String get accountKindCreditLine => 'Кредитная линия';

  @override
  String get accountKindLoan => 'Кредит';

  @override
  String get accountKindSavings => 'Копилка';

  @override
  String get accountKindDeposit => 'Вклад';

  @override
  String get accountsNewCashOrCard => 'Наличные или карта';

  @override
  String get cashDefaultName => 'Наличные';

  @override
  String accountThisMonth(String amount) {
    return '$amount за месяц';
  }

  @override
  String accountAvailableOf(String available, String limit) {
    return 'доступно $available из $limit';
  }

  @override
  String accountLoanProgress(int paid, int total, String payment) {
    return 'оплачено $paid из $total · $payment в месяц';
  }

  @override
  String accountGoalOf(String target, int percent) {
    return 'из $target · $percent%';
  }

  @override
  String accountByDate(String date) {
    return 'к $date';
  }

  @override
  String accountDueDate(String date) {
    return 'до $date';
  }

  @override
  String accountNextDate(String date) {
    return 'следующий $date';
  }

  @override
  String accountDebtTotal(String amount) {
    return 'долг $amount';
  }

  @override
  String get accountNoRate => 'нет курса';

  @override
  String get accountBalance => 'Баланс';

  @override
  String get accountDebt => 'Долг';

  @override
  String get accountRemaining => 'Осталось';

  @override
  String get accountLimit => 'Лимит';

  @override
  String get accountAvailable => 'Доступно';

  @override
  String get accountDueDay => 'День оплаты';

  @override
  String get accountMonthly => 'В месяц';

  @override
  String get accountPaid => 'Оплачено';

  @override
  String accountPaidOf(int paid, int total) {
    return '$paid из $total';
  }

  @override
  String get accountNext => 'Следующий';

  @override
  String get accountGoal => 'Цель';

  @override
  String get accountLeft => 'Осталось';

  @override
  String get accountEnds => 'До';

  @override
  String get accountSpentMonth => 'Потрачено';

  @override
  String get accountIncomeMonth => 'Получено';

  @override
  String accountOverpaid(String amount) {
    return 'переплата $amount';
  }

  @override
  String get actionAddIncome => 'Доход';

  @override
  String get actionTransfer => 'Перевод';

  @override
  String get actionExpense => 'Расход';

  @override
  String actionPayAmount(String amount) {
    return 'Оплатить $amount';
  }

  @override
  String get actionPayEllipsis => 'Оплатить…';

  @override
  String get actionExtraPayment => 'Досрочно';

  @override
  String get actionRecalculate => 'Пересчитать';

  @override
  String get actionAddPurchase => 'Покупка';

  @override
  String get actionTopUp => 'Пополнить';

  @override
  String get accountSchedule => 'График';

  @override
  String accountScheduleHint(String principal) {
    return 'взято $principal';
  }

  @override
  String get accountTransactions => 'Операции';

  @override
  String get accountArchive => 'В архив';

  @override
  String get accountUnarchive => 'Вернуть из архива';

  @override
  String get accountDeleteTitle => 'Удалить счёт?';

  @override
  String get accountDeleteBody =>
      'У счёта нет операций — больше ничего не потеряется.';

  @override
  String get accountDeleteBlocked =>
      'Счёт с операциями можно только отправить в архив.';

  @override
  String get accountLoanOpened => 'Кредит оформлен';

  @override
  String get accountOpening => 'Начальный баланс';

  @override
  String get accountNew => 'Новый счёт';

  @override
  String get accountEdit => 'Изменить счёт';

  @override
  String get fieldName => 'Название';

  @override
  String get fieldCurrency => 'Валюта';

  @override
  String get fieldBalance => 'Сейчас на счёте';

  @override
  String get fieldIcon => 'Иконка';

  @override
  String get fieldColor => 'Цвет';

  @override
  String get fieldIncludeInTotal => 'Считать в своих деньгах';

  @override
  String get fieldTarget => 'Цель';

  @override
  String get fieldTargetDate => 'К дате';

  @override
  String get fieldEndDate => 'Дата окончания';

  @override
  String get fieldLimit => 'Кредитный лимит';

  @override
  String get fieldCurrentDebt => 'Текущий долг';

  @override
  String get fieldDueDay => 'День оплаты';

  @override
  String get fieldMinPayment => 'Минимальный платёж';

  @override
  String get fieldPayFrom => 'Платить с';

  @override
  String get fieldKind => 'Вид';

  @override
  String dayOfMonth(int day) {
    return '$day-е число';
  }

  @override
  String get nameRequired => 'Введите название';

  @override
  String get amountRequired => 'Введите сумму';

  @override
  String get currencyLocked => 'Валюту нельзя сменить, когда есть операции';

  @override
  String get loanNew => 'Новый кредит';

  @override
  String get loanAmount => 'Сумма';

  @override
  String get loanRate => 'Ставка';

  @override
  String get loanTotal => 'Итого';

  @override
  String loanMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count месяца',
      many: '$count месяцев',
      few: '$count месяца',
      one: '$count месяц',
    );
    return '$_temp0';
  }

  @override
  String loanTimes(String amount) {
    return '× $amount';
  }

  @override
  String get loanDrag => 'листайте · от 1 до 60 месяцев';

  @override
  String get loanPerMonth => '/ мес';

  @override
  String get loanPerYear => '/ год';

  @override
  String get loanPayment => 'Платёж в месяц';

  @override
  String get loanFirstPayment => 'Первый платёж';

  @override
  String get loanMoreFields => 'Ещё · название, счёт, напоминания';

  @override
  String get loanCreate => 'Создать кредит';

  @override
  String loanDefaultName(String amount) {
    return 'Кредит · $amount';
  }

  @override
  String get loanRecalcTitle => 'Пересчитать график';

  @override
  String get loanRecalcKeepPayment => 'Платёж тот же, месяцев меньше';

  @override
  String get loanRecalcKeepTerm => 'Срок тот же, платёж меньше';

  @override
  String get loanRecalcNothing => 'Платить больше нечего';

  @override
  String get creditLineNew => 'Новая кредитная линия';

  @override
  String get create => 'Создать';

  @override
  String get paymentsUpcoming => 'Скоро';

  @override
  String get paymentsRules => 'Правила';

  @override
  String get paymentsNext30 => 'Ближайшие 30 дней';

  @override
  String get paymentsNewTooltip => 'Новый платёж';

  @override
  String get groupOverdue => 'Просрочено';

  @override
  String get groupToday => 'Сегодня';

  @override
  String groupTomorrow(String date) {
    return 'Завтра · $date';
  }

  @override
  String get groupThisWeek => 'На этой неделе';

  @override
  String get groupLater => 'Позже';

  @override
  String payAmount(String amount) {
    return 'Оплатить $amount';
  }

  @override
  String get enterAmount => 'Ввести сумму';

  @override
  String get payEllipsis => 'Оплатить…';

  @override
  String get skip => 'Пропустить';

  @override
  String overdueDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Просрочено на $count дня',
      many: 'Просрочено на $count дней',
      few: 'Просрочено на $count дня',
      one: 'Просрочено на $count день',
    );
    return '$_temp0';
  }

  @override
  String inDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Через $count дня',
      many: 'Через $count дней',
      few: 'Через $count дня',
      one: 'Через $count день',
    );
    return '$_temp0';
  }

  @override
  String get autoPayShort => 'автосписание';

  @override
  String seqOf(int seq, int total) {
    return '$seq из $total';
  }

  @override
  String fromAccount(String name) {
    return 'с «$name»';
  }

  @override
  String get estimate => 'примерно';

  @override
  String minPaymentShort(String amount) {
    return 'мин. $amount';
  }

  @override
  String get rulesLoans => 'Кредиты';

  @override
  String get rulesCreditLines => 'Кредитные линии';

  @override
  String get rulesSubscriptions => 'Подписки';

  @override
  String get rulesUtilities => 'Коммуналка';

  @override
  String get rulesOther => 'Другое';

  @override
  String perMonth(String amount) {
    return '$amount в месяц';
  }

  @override
  String pausedUntil(String date) {
    return 'Пауза до $date';
  }

  @override
  String get paused => 'На паузе';

  @override
  String get paymentsEmptyTitle => 'Платежей пока нет';

  @override
  String get paymentsEmptyBody =>
      'Добавьте подписки, коммуналку и кредиты — напоминания придут сами.';

  @override
  String get nothingToPay => 'Платить нечего';

  @override
  String occDue(String date) {
    return 'Срок $date';
  }

  @override
  String get occAmountOnBill => 'Сумма по счёту';

  @override
  String get occAmount => 'Сумма';

  @override
  String occLastTime(String amount) {
    return 'В прошлый раз · $amount';
  }

  @override
  String occFrom(String name) {
    return 'С «$name»';
  }

  @override
  String occFull(String amount) {
    return 'Весь долг $amount';
  }

  @override
  String occMinimum(String amount) {
    return 'Минимум $amount';
  }

  @override
  String get occOther => 'Другая сумма';

  @override
  String occApprox(String foreign, String local, String rate) {
    return '$foreign ≈ $local · $rate';
  }

  @override
  String get occEditRule => 'Изменить платёж';

  @override
  String occPaidOn(String date) {
    return 'Оплачено $date';
  }

  @override
  String get occSkipped => 'Пропущено';

  @override
  String get occRestore => 'Вернуть';

  @override
  String get occChooseAccount => 'Выберите счёт для оплаты';

  @override
  String get ruleNew => 'Новый платёж';

  @override
  String get ruleEdit => 'Изменить платёж';

  @override
  String get ruleKindSubscription => 'Подписка';

  @override
  String get ruleKindUtility => 'Коммуналка';

  @override
  String get ruleKindOther => 'Другое';

  @override
  String get ruleKindLoan => 'Платёж по кредиту';

  @override
  String get ruleKindCreditLine => 'Погашение карты';

  @override
  String get ruleAmountVaries => 'Сумма меняется';

  @override
  String get ruleNextCharge => 'Следующее списание';

  @override
  String get ruleRepeat => 'Повтор';

  @override
  String get freqMonthly => 'Каждый месяц';

  @override
  String get freqWeekly => 'Каждую неделю';

  @override
  String get freqYearly => 'Каждый год';

  @override
  String freqEveryNDays(int n) {
    return 'Каждые $n дн.';
  }

  @override
  String freqEveryNMonths(int n) {
    return 'Каждые $n мес.';
  }

  @override
  String get ruleEnds => 'До';

  @override
  String get ruleNoEnd => 'Без срока';

  @override
  String get ruleRemind => 'Напомнить';

  @override
  String remindDaysBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'За $count дня',
      many: 'За $count дней',
      few: 'За $count дня',
      one: 'За $count день',
      zero: 'В день платежа',
    );
    return '$_temp0';
  }

  @override
  String get remindOff => 'Не напоминать';

  @override
  String get ruleRemindTime => 'Время напоминания';

  @override
  String get ruleAutoPay => 'Автосписание';

  @override
  String get ruleAutoPayHint =>
      'Банк списывает сам — отмечать оплату автоматически';

  @override
  String get rulePauseUntil => 'Пауза до…';

  @override
  String get rulePauseForever => 'Поставить на паузу';

  @override
  String get ruleResume => 'Возобновить';

  @override
  String get ruleDeleteTitle => 'Удалить платёж?';

  @override
  String get ruleDeleteBody =>
      'История оплат останется, будущие напоминания исчезнут.';

  @override
  String get ruleHistory => 'История';

  @override
  String get ruleNameHint => 'Netflix, аренда, свет…';

  @override
  String get statsTitle => 'Статистика';

  @override
  String get statsSpent => 'Потрачено';

  @override
  String get statsIncome => 'Доход';

  @override
  String get statsSaved => 'Отложено';

  @override
  String get statsDebt => 'Долг';

  @override
  String get statsByCategory => 'По категориям';

  @override
  String get statsSixMonths => '6 месяцев';

  @override
  String get statsDebtTrend => 'Долг за 12 месяцев';

  @override
  String get statsEmpty => 'За этот период расходов нет';

  @override
  String get statsBudgets => 'Бюджеты';

  @override
  String get budgetsTitle => 'Бюджеты';

  @override
  String get budgetWholeMonth => 'Весь месяц';

  @override
  String get budgetSet => 'Задать бюджет';

  @override
  String budgetOf(String spent, String budget) {
    return '$spent из $budget';
  }

  @override
  String budgetLeft(String amount) {
    return 'осталось $amount';
  }

  @override
  String budgetOver(String amount) {
    return 'перерасход $amount';
  }

  @override
  String get budgetFromNextMonth => 'Со следующего месяца';

  @override
  String get budgetRemove => 'Убрать бюджет';

  @override
  String get budgetNoCategories => 'Категории без бюджета';

  @override
  String get categoriesTitle => 'Категории';

  @override
  String get categoryNew => 'Новая категория';

  @override
  String get categoryEdit => 'Изменить категорию';

  @override
  String get categoryDeleteTitle => 'Удалить категорию?';

  @override
  String get categoryDeleteEmpty => 'Операций в ней нет.';

  @override
  String categoryMoveTo(String name) {
    return 'Её операции перейдут в «$name».';
  }

  @override
  String get groceries => 'Продукты';

  @override
  String get cafe => 'Кафе';

  @override
  String get transport => 'Транспорт';

  @override
  String get taxi => 'Такси';

  @override
  String get housing => 'Жильё';

  @override
  String get utilities => 'Коммуналка';

  @override
  String get phone => 'Связь';

  @override
  String get subscriptions => 'Подписки';

  @override
  String get health => 'Здоровье';

  @override
  String get clothes => 'Одежда';

  @override
  String get entertainment => 'Досуг';

  @override
  String get education => 'Учёба';

  @override
  String get gifts => 'Подарки';

  @override
  String get travel => 'Поездки';

  @override
  String get kids => 'Дети';

  @override
  String get pets => 'Питомцы';

  @override
  String get otherExpense => 'Другое';

  @override
  String get salary => 'Зарплата';

  @override
  String get freelance => 'Подработка';

  @override
  String get giftIncome => 'Подарки';

  @override
  String get interest => 'Проценты';

  @override
  String get otherIncome => 'Другое';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get languageSystem => 'Как в системе';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get settingsBaseCurrency => 'Основная валюта';

  @override
  String get settingsRates => 'Курсы валют';

  @override
  String get settingsMonthStart => 'Месяц начинается';

  @override
  String get settingsReminders => 'Напоминания';

  @override
  String get settingsReminderTime => 'Время по умолчанию';

  @override
  String get settingsDigest => 'Утренняя сводка';

  @override
  String get settingsDigestTime => 'Время сводки';

  @override
  String get settingsNotificationsOff =>
      'Уведомления выключены в настройках iOS';

  @override
  String get settingsFaceId => 'Вход по Face ID';

  @override
  String get settingsBackup => 'Резервная копия';

  @override
  String get settingsCategories => 'Категории';

  @override
  String get settingsBudgets => 'Бюджеты';

  @override
  String get settingsAbout => 'О приложении';

  @override
  String get settingsAboutBody =>
      'Данные хранятся только на этом iPhone и не шифруются; Face ID лишь закрывает экран. Время от времени делайте резервную копию.';

  @override
  String settingsVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get ratesTitle => 'Курсы валют';

  @override
  String get ratesBase => 'Основная валюта';

  @override
  String get ratesRefresh => 'Обновить с НБКР';

  @override
  String get ratesManual => 'вручную';

  @override
  String get ratesNbkr => 'НБКР';

  @override
  String ratesUpdated(String date) {
    return 'Обновлено $date';
  }

  @override
  String ratesSetTitle(String code, String base) {
    return '1 $code в $base';
  }

  @override
  String get ratesEmpty =>
      'Курсы появятся здесь, когда у счёта или платежа будет другая валюта.';

  @override
  String get ratesFetchFailed =>
      'Не удалось связаться с НБКР. Введите курс вручную.';

  @override
  String get ratesNoRate => 'нет курса';

  @override
  String get ratesChangeBaseTitle => 'Сменить основную валюту?';

  @override
  String get ratesChangeBaseBody =>
      'Итоги, статистика и бюджеты пересчитаются по текущим курсам.';

  @override
  String ratesMissingRate(String code) {
    return 'Сначала введите курс $code';
  }

  @override
  String get ratesAdd => 'Добавить валюту';

  @override
  String get change => 'Сменить';

  @override
  String get backupTitle => 'Резервная копия';

  @override
  String get backupExport => 'Сделать копию';

  @override
  String get backupImport => 'Восстановить из файла…';

  @override
  String get backupFiles => 'Сохранённые копии';

  @override
  String get backupHint =>
      'Копия — это JSON-файл. Сохраните его в «Файлы», iCloud Drive или отправьте себе.';

  @override
  String get backupImportTitle => 'Заменить все данные?';

  @override
  String get backupImportBody =>
      'Всё, что сейчас в приложении, заменится данными из копии.';

  @override
  String get backupReplace => 'Заменить';

  @override
  String get backupRestored => 'Данные восстановлены';

  @override
  String get backupErrorFormat => 'Это не резервная копия этого приложения';

  @override
  String get backupErrorVersion =>
      'Обновите приложение, чтобы открыть эту копию';

  @override
  String backupErrorBroken(String detail) {
    return 'Копия повреждена: $detail';
  }

  @override
  String get lockUnlock => 'Открыть по Face ID';

  @override
  String get lockReason => 'Откройте, чтобы увидеть финансы';

  @override
  String get lockUnavailable => 'Face ID на этом iPhone не настроен';

  @override
  String get notifDigestTitle => 'Платежи сегодня';

  @override
  String notifDigestBody(int count, String total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count платежа · $total',
      many: '$count платежей · $total',
      few: '$count платежа · $total',
      one: '$count платёж · $total',
    );
    return '$_temp0';
  }

  @override
  String notifDueToday(String amount) {
    return 'Сегодня · $amount';
  }

  @override
  String notifDueTomorrow(String amount) {
    return 'Завтра · $amount';
  }

  @override
  String notifDueIn(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Через $count дня · $amount',
      many: 'Через $count дней · $amount',
      few: 'Через $count дня · $amount',
      one: 'Через $count день · $amount',
    );
    return '$_temp0';
  }

  @override
  String get notifAmountNotSet => 'сумма не указана';

  @override
  String get notifActionPaid => 'Оплачено';

  @override
  String get notifActionSnooze => 'Напомнить завтра';

  @override
  String notifResumes(String name, String date) {
    return '«$name» снова с $date';
  }

  @override
  String get notifAlreadyPaid => 'Уже оплачено';
}
