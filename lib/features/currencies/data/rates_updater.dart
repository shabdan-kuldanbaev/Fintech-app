import '../../../core/clock.dart';
import '../../../data/rates/nbkr_client.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/domain/settings.dart';
import 'rates_repository.dart';

/// Загрузка курсов НБКР (spec.md §4.2): при открытии «Currencies», если
/// прошлой загрузке больше суток, и по «Refresh». Ручные курсы сеть не
/// трогает (`RatesRepository.applyFetched`).
class RatesUpdater {
  RatesUpdater(this._source, this._rates, this._settings, this._clock);

  final KgsRatesSource _source;
  final RatesRepository _rates;
  final SettingsRepository _settings;
  final Clock _clock;

  static const Duration staleAfter = Duration(hours: 24);

  /// Сколько курсов обновлено. Сеть недоступна — исключение наверх: экран
  /// показывает «введите курс вручную».
  Future<int> refresh() async {
    final kgs = await _source.fetch();
    final base = (await _settings.load()).baseCurrency;
    final applied = await _rates.applyFetched(ratesToBase(kgs, base));
    await _settings.write(SettingKeys.ratesLastFetch, _clock.now().toUtc().toIso8601String());
    return applied;
  }

  Future<bool> isStale() async {
    final last = (await _settings.load()).ratesLastFetch;
    return last == null || _clock.now().difference(last) > staleAfter;
  }
}
