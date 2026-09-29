import 'package:flutter/foundation.dart';

/// Справочник валют ISO 4217 (spec.md §4.1). Данные, а не текст интерфейса:
/// имена валют берутся отсюда в том языке, на котором открыто приложение.
@immutable
class CurrencyInfo {
  const CurrencyInfo(
    this.code,
    this.minorUnits,
    this.nameEn,
    this.nameRu, {
    this.symbol,
    this.symbolRu,
    this.prefix = false,
  });

  final String code;

  /// Число знаков дробной части: 2 у сома и доллара, 0 у иены.
  final int minorUnits;
  final String nameEn;
  final String nameRu;

  /// Знак валюты; `null` — пишется код.
  final String? symbol;

  /// Знак в русском тексте, если отличается («сом» вместо «som»).
  final String? symbolRu;

  /// В английском тексте знак стоит перед числом ($9.99); в русском —
  /// всегда после (9,99 $).
  final bool prefix;

  String name(String languageCode) => languageCode == 'ru' ? nameRu : nameEn;

  String sign(String languageCode) =>
      (languageCode == 'ru' ? symbolRu ?? symbol : symbol) ?? code;
}

/// Глиф `⃀` (U+20C0) не используется, пока spec.md §12.1 не подтвердит его
/// отрисовку на устройстве: сом пишется словом.
const List<CurrencyInfo> currencies = [
  CurrencyInfo('KGS', 2, 'Kyrgyz som', 'Киргизский сом', symbol: 'som', symbolRu: 'сом'),
  CurrencyInfo('USD', 2, 'US dollar', 'Доллар США', symbol: r'$', prefix: true),
  CurrencyInfo('EUR', 2, 'Euro', 'Евро', symbol: '€', prefix: true),
  CurrencyInfo('RUB', 2, 'Russian ruble', 'Российский рубль', symbol: '₽'),
  CurrencyInfo('KZT', 2, 'Kazakh tenge', 'Казахский тенге', symbol: '₸'),
  CurrencyInfo('UZS', 2, 'Uzbek som', 'Узбекский сум', symbol: 'UZS', symbolRu: 'сум'),
  CurrencyInfo('TJS', 2, 'Tajik somoni', 'Таджикский сомони'),
  CurrencyInfo('CNY', 2, 'Chinese yuan', 'Китайский юань', symbol: '¥', prefix: true),
  CurrencyInfo('TRY', 2, 'Turkish lira', 'Турецкая лира', symbol: '₺'),
  CurrencyInfo('GBP', 2, 'Pound sterling', 'Фунт стерлингов', symbol: '£', prefix: true),
  CurrencyInfo('AED', 2, 'UAE dirham', 'Дирхам ОАЭ'),
  CurrencyInfo('JPY', 0, 'Japanese yen', 'Японская иена', symbol: '¥', prefix: true),
  CurrencyInfo('KRW', 0, 'South Korean won', 'Южнокорейская вона', symbol: '₩', prefix: true),
  CurrencyInfo('CHF', 2, 'Swiss franc', 'Швейцарский франк'),
  CurrencyInfo('CAD', 2, 'Canadian dollar', 'Канадский доллар'),
  CurrencyInfo('AUD', 2, 'Australian dollar', 'Австралийский доллар'),
  CurrencyInfo('INR', 2, 'Indian rupee', 'Индийская рупия', symbol: '₹', prefix: true),
  CurrencyInfo('AMD', 2, 'Armenian dram', 'Армянский драм', symbol: '֏'),
  CurrencyInfo('GEL', 2, 'Georgian lari', 'Грузинский лари', symbol: '₾'),
  CurrencyInfo('AZN', 2, 'Azerbaijani manat', 'Азербайджанский манат', symbol: '₼'),
  CurrencyInfo('BYN', 2, 'Belarusian ruble', 'Белорусский рубль'),
  CurrencyInfo('UAH', 2, 'Ukrainian hryvnia', 'Украинская гривна', symbol: '₴'),
  CurrencyInfo('PLN', 2, 'Polish zloty', 'Польский злотый', symbol: 'zł'),
  CurrencyInfo('CZK', 2, 'Czech koruna', 'Чешская крона'),
  CurrencyInfo('SEK', 2, 'Swedish krona', 'Шведская крона'),
  CurrencyInfo('NOK', 2, 'Norwegian krone', 'Норвежская крона'),
  CurrencyInfo('DKK', 2, 'Danish krone', 'Датская крона'),
  CurrencyInfo('HKD', 2, 'Hong Kong dollar', 'Гонконгский доллар'),
  CurrencyInfo('SGD', 2, 'Singapore dollar', 'Сингапурский доллар'),
  CurrencyInfo('THB', 2, 'Thai baht', 'Тайский бат', symbol: '฿'),
  CurrencyInfo('VND', 0, 'Vietnamese dong', 'Вьетнамский донг', symbol: '₫'),
  CurrencyInfo('IDR', 2, 'Indonesian rupiah', 'Индонезийская рупия'),
  CurrencyInfo('MYR', 2, 'Malaysian ringgit', 'Малайзийский ринггит'),
  CurrencyInfo('ILS', 2, 'Israeli shekel', 'Израильский шекель', symbol: '₪'),
  CurrencyInfo('SAR', 2, 'Saudi riyal', 'Саудовский риял'),
  CurrencyInfo('BRL', 2, 'Brazilian real', 'Бразильский реал'),
  CurrencyInfo('MXN', 2, 'Mexican peso', 'Мексиканское песо'),
  CurrencyInfo('MNT', 2, 'Mongolian tögrög', 'Монгольский тугрик', symbol: '₮'),
  CurrencyInfo('KWD', 3, 'Kuwaiti dinar', 'Кувейтский динар'),
];

final Map<String, CurrencyInfo> _byCode = {
  for (final c in currencies) c.code: c,
};

/// Сведения о валюте; неизвестный код — два знака и код вместо имени.
CurrencyInfo currencyInfo(String code) =>
    _byCode[code] ?? CurrencyInfo(code, 2, code, code);

int minorUnits(String code) => currencyInfo(code).minorUnits;

/// Базовая валюта по стране локали устройства (spec.md §3.3).
String defaultCurrencyForCountry(String? countryCode) =>
    switch (countryCode?.toUpperCase()) {
      'KG' => 'KGS',
      'RU' => 'RUB',
      'KZ' => 'KZT',
      'UZ' => 'UZS',
      'US' => 'USD',
      'AT' || 'BE' || 'HR' || 'CY' || 'EE' || 'FI' || 'FR' || 'DE' || 'GR' ||
      'IE' || 'IT' || 'LV' || 'LT' || 'LU' || 'MT' || 'NL' || 'PT' || 'SK' ||
      'SI' || 'ES' => 'EUR',
      _ => 'USD',
    };
