import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import '../../core/money.dart';

/// Источник официальных курсов к сому: код → сомов за 1 единицу × 10⁶.
abstract interface class KgsRatesSource {
  Future<Map<String, int>> fetch();
}

/// Ежедневные курсы НБКР (spec.md §4.2). Единственное место с сетью (I12).
class NbkrClient implements KgsRatesSource {
  NbkrClient([Dio? dio]) : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10)));

  static const String url = 'https://www.nbkr.kg/XML/daily.xml';

  final Dio _dio;

  @override
  Future<Map<String, int>> fetch() async {
    final response = await _dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
    // Файл в windows-1251; коды валют и числа — ASCII, их latin1 не портит.
    return parseNbkrDaily(latin1.decode(response.data ?? const []));
  }
}

/// Разбор `CurrencyRates/Currency[@ISOCode]/{Nominal, Value}`: значение с
/// запятой («87,4500») — сомов за [Nominal] единиц. Результат — за 1 единицу
/// × 10⁶, без `double` (I4). Битые строки пропускаются.
Map<String, int> parseNbkrDaily(String xml) {
  final doc = XmlDocument.parse(xml);
  final result = <String, int>{};
  for (final c in doc.findAllElements('Currency')) {
    final code = c.getAttribute('ISOCode')?.trim().toUpperCase();
    final nominal = int.tryParse(c.getElement('Nominal')?.innerText.trim() ?? '');
    final value = parseRateMicro(c.getElement('Value')?.innerText ?? '');
    if (code == null || code.length != 3 || nominal == null || nominal <= 0 || value == null || value <= 0) continue;
    result[code] = mulDivRound(value, 1, nominal);
  }
  return result;
}

/// Курсы к сому → курсы к базовой валюте [base] (сом — опорная, §4.2):
/// `rate(X→base) = rate(X→KGS) / rate(base→KGS)`. Базы нет в списке НБКР —
/// пусто: остаётся ручной ввод.
Map<String, int> ratesToBase(Map<String, int> kgs, String base) {
  if (base == 'KGS') return Map.of(kgs)..remove('KGS');
  final baseRate = kgs[base];
  if (baseRate == null) return const {};
  return {
    for (final e in kgs.entries)
      if (e.key != base) e.key: mulDivRound(e.value, rateScale, baseRate),
    'KGS': mulDivRound(rateScale, rateScale, baseRate),
  };
}
