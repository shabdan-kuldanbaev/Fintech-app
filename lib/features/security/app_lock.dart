import 'package:local_auth/local_auth.dart';

/// Итог попытки разблокировки.
enum UnlockResult {
  unlocked,

  /// Отмена, неверное лицо, таймаут — «Try again».
  failed,

  /// На iPhone нет ни Face ID, ни код-пароля: включить замок нельзя.
  unavailable,
}

/// Проверка личности (spec.md §8.3 «Lock», I18): замок — экран, не
/// шифрование. `local_auth` вызывается только отсюда.
abstract interface class Authenticator {
  Future<UnlockResult> unlock(String reason);
}

class LocalAuthenticator implements Authenticator {
  LocalAuthenticator([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<UnlockResult> unlock(String reason) async {
    try {
      if (!await _auth.isDeviceSupported()) return UnlockResult.unavailable;
      // Не только биометрия: без Face ID остаётся код-пароль iPhone.
      final ok = await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
      return ok ? UnlockResult.unlocked : UnlockResult.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricHardware => UnlockResult.unavailable,
        _ => UnlockResult.failed,
      };
    }
  }
}

/// Пора ли запереть при возвращении: замок включён и в фоне пробыли
/// не меньше [afterSeconds]. Без I/O — для теста.
bool shouldLock({required bool enabled, required DateTime? pausedAt, required DateTime now, required int afterSeconds}) =>
    enabled && pausedAt != null && now.difference(pausedAt).inSeconds >= afterSeconds;
