// Когда запирать при возвращении из фона (spec.md §8.3 «Lock»).
import 'package:fintech/features/security/app_lock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime.utc(2026, 9, 29, 12);

  test('замок выключен или в фон не уходили — не запирать', () {
    expect(shouldLock(enabled: false, pausedAt: t0, now: t0.add(const Duration(hours: 1)), afterSeconds: 60), isFalse);
    expect(shouldLock(enabled: true, pausedAt: null, now: t0, afterSeconds: 60), isFalse);
  });

  test('ровно после after_seconds — запирать, раньше — нет', () {
    expect(shouldLock(enabled: true, pausedAt: t0, now: t0.add(const Duration(seconds: 59)), afterSeconds: 60), isFalse);
    expect(shouldLock(enabled: true, pausedAt: t0, now: t0.add(const Duration(seconds: 60)), afterSeconds: 60), isTrue);
  });
}
