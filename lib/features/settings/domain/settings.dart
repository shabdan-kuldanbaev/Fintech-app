import 'package:flutter/foundation.dart';

/// Ключи `app_settings` (spec.md §3.3).
abstract final class SettingKeys {
  static const baseCurrency = 'base_currency';
  static const locale = 'locale';
  static const bootstrapDone = 'bootstrap_done';
  static const nextNotificationId = 'notifications.next_id';
  static const defaultReminderMinutes = 'notifications.default_minutes';
  static const digestEnabled = 'notifications.digest_enabled';
  static const digestMinutes = 'notifications.digest_minutes';
  static const lockEnabled = 'lock.enabled';
  static const lockAfterSeconds = 'lock.after_seconds';
  static const ratesLastFetch = 'rates.last_fetch';
  static const lastAccountId = 'last_account_id';
  static const monthStartDay = 'home.month_start_day';
}

/// Язык приложения (`app_settings.locale`).
enum AppLanguage {
  system('system'),
  en('en'),
  ru('ru');

  const AppLanguage(this.db);
  final String db;

  static AppLanguage fromDb(String? value) =>
      values.firstWhere((l) => l.db == value, orElse: () => system);
}

/// Снимок настроек с дефолтами §3.3 — то, что читают экраны.
@immutable
class Settings {
  const Settings({
    this.baseCurrency = 'USD',
    this.language = AppLanguage.system,
    this.defaultReminderMinutes = 600,
    this.digestEnabled = true,
    this.digestMinutes = 540,
    this.lockEnabled = false,
    this.lockAfterSeconds = 60,
    this.ratesLastFetch,
    this.lastAccountId,
    this.monthStartDay = 1,
  });

  final String baseCurrency;
  final AppLanguage language;
  final int defaultReminderMinutes;
  final bool digestEnabled;
  final int digestMinutes;
  final bool lockEnabled;
  final int lockAfterSeconds;
  final DateTime? ratesLastFetch;
  final String? lastAccountId;
  final int monthStartDay;

  /// Разбор строк `app_settings` (value — JSON, уже декодированный).
  factory Settings.fromMap(Map<String, Object?> m) {
    T? get<T>(String key) {
      final v = m[key];
      return v is T ? v : null;
    }

    final fetched = get<String>(SettingKeys.ratesLastFetch);
    return Settings(
      baseCurrency: get<String>(SettingKeys.baseCurrency) ?? 'USD',
      language: AppLanguage.fromDb(get<String>(SettingKeys.locale)),
      defaultReminderMinutes:
          get<int>(SettingKeys.defaultReminderMinutes) ?? 600,
      digestEnabled: get<bool>(SettingKeys.digestEnabled) ?? true,
      digestMinutes: get<int>(SettingKeys.digestMinutes) ?? 540,
      lockEnabled: get<bool>(SettingKeys.lockEnabled) ?? false,
      lockAfterSeconds: get<int>(SettingKeys.lockAfterSeconds) ?? 60,
      ratesLastFetch: fetched == null ? null : DateTime.tryParse(fetched)?.toUtc(),
      lastAccountId: get<String>(SettingKeys.lastAccountId),
      monthStartDay: (get<int>(SettingKeys.monthStartDay) ?? 1).clamp(1, 28),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Settings &&
      other.baseCurrency == baseCurrency &&
      other.language == language &&
      other.defaultReminderMinutes == defaultReminderMinutes &&
      other.digestEnabled == digestEnabled &&
      other.digestMinutes == digestMinutes &&
      other.lockEnabled == lockEnabled &&
      other.lockAfterSeconds == lockAfterSeconds &&
      other.ratesLastFetch == ratesLastFetch &&
      other.lastAccountId == lastAccountId &&
      other.monthStartDay == monthStartDay;

  @override
  int get hashCode => Object.hash(
    baseCurrency,
    language,
    defaultReminderMinutes,
    digestEnabled,
    digestMinutes,
    lockEnabled,
    lockAfterSeconds,
    ratesLastFetch,
    lastAccountId,
    monthStartDay,
  );
}
