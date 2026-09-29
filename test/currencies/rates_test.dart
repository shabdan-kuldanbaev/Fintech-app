// Загрузка курсов: ручной курс сеть не перезаписывает; «старше суток» (§4.2).
import 'dart:io';

import 'package:fintech/data/rates/nbkr_client.dart';
import 'package:fintech/features/currencies/data/rates_updater.dart';
import 'package:fintech/features/currencies/domain/rate.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

class FixtureSource implements KgsRatesSource {
  int calls = 0;
  @override
  Future<Map<String, int>> fetch() async {
    calls++;
    return parseNbkrDaily(File('test/fixtures/nbkr_daily.xml').readAsStringSync());
  }
}

void main() {
  late Harness h;
  late RatesUpdater updater;
  setUp(() async {
    h = await Harness.create(); // KG → база KGS
    updater = RatesUpdater(FixtureSource(), h.rates, h.settings, h.clock);
  });
  tearDown(() => h.dispose());

  test('курсы из НБКР ложатся, ручной — нет; отметка времени пишется', () async {
    await h.rates.setRate('EUR', 100000000, RateSource.manual);
    expect(await updater.isStale(), isTrue);
    await updater.refresh();
    final c = await h.rates.converter();
    expect(c.base, 'KGS');
    expect(c.rates['USD'], 87450000);
    expect(c.rates['EUR'], 100000000, reason: 'ручной курс не перезаписан');
    expect(await updater.isStale(), isFalse);
    h.clock.advance(const Duration(hours: 25));
    expect(await updater.isStale(), isTrue);
  });
}
