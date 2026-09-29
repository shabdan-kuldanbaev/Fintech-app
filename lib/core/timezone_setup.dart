import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Инициализация `tz.local` (spec.md §6): `flutter_timezone` ≥ 5 возвращает
/// `TimezoneInfo`, IANA-идентификатор — в `.identifier`.
///
/// Если идентификатор недоступен или неизвестен базе `timezone`, используется
/// локация с фиксированным смещением текущего устройства, чтобы граница дня
/// (§1 I6) не считалась по UTC.
Future<void> setupLocalTimezone() async {
  tzdata.initializeTimeZones();
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  } catch (_) {
    tz.setLocalLocation(fixedOffsetLocation(DateTime.now().timeZoneOffset));
  }
}

/// Локация без правил перехода, со смещением [offset].
tz.Location fixedOffsetLocation(Duration offset) {
  final zone = tz.TimeZone(offset, isDst: false, abbreviation: 'LOCAL');
  return tz.Location('Local/Fixed', [tz.minTime], [0], [zone]);
}
