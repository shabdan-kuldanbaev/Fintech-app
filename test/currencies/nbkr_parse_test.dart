// Разбор курсов НБКР на сохранённом XML (spec.md §4.2, §12.2) и перевод к
// базовой валюте через сом.
import 'dart:io';

import 'package:fintech/data/rates/nbkr_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final xml = File('test/fixtures/nbkr_daily.xml').readAsStringSync();

  test('запятая в числе, номинал, битые строки пропускаются', () {
    final r = parseNbkrDaily(xml);
    expect(r['USD'], 87450000);
    expect(r['EUR'], 102345600);
    expect(r['KZT'], 165400);
    expect(r['UZS'], 6850, reason: '0,6850 сом за 100 сумов');
    expect(r.containsKey('XXX'), isFalse);
  });

  test('база KGS — как есть; база USD — через сом; нет базы в списке — пусто', () {
    final kgs = parseNbkrDaily(xml);
    expect(ratesToBase(kgs, 'KGS')['USD'], 87450000);
    final usd = ratesToBase(kgs, 'USD');
    expect(usd.containsKey('USD'), isFalse);
    // 1 сом = 1 / 87,45 $ = 0,011435 $; 1 € = 102,3456 / 87,45 = 1,170333 $.
    expect(usd['KGS'], 11435);
    expect(usd['EUR'], 1170333);
    expect(ratesToBase(kgs, 'GBP'), isEmpty);
  });
}
