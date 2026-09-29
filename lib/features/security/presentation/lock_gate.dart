import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/format.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../app_lock.dart';

/// Замок поверх приложения (spec.md §8.3 «Lock»): при `lock.enabled` —
/// холодный старт и возврат из фона после `lock.after_seconds`. Пока
/// приложение неактивно (переключатель приложений), содержимое не рисуется:
/// в снимок iOS попадает заглушка.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> {
  late final AppLifecycleListener _lifecycle;

  /// `null` — настройки ещё не прочитаны (холодный старт).
  bool? _locked;
  bool _cover = false;
  bool _busy = false;
  bool _failed = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onInactive: () => setState(() => _cover = true),
      onHide: () => setState(() => _cover = true),
      onPause: () => _pausedAt = ref.read(clockProvider).now(),
      onResume: _onResume,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onResume() {
    final s = ref.read(settingsProvider).value;
    final lock = s != null &&
        shouldLock(enabled: s.lockEnabled, pausedAt: _pausedAt, now: ref.read(clockProvider).now(), afterSeconds: s.lockAfterSeconds);
    _pausedAt = null;
    setState(() {
      _cover = false;
      if (lock) _locked = true;
    });
    if (lock) unawaited(_unlock());
  }

  Future<void> _unlock() async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final result = await ref.read(authenticatorProvider).unlock(context.l10n.lockReason);
    if (!mounted) return;
    setState(() {
      _busy = false;
      // Face ID и код-пароль сняли с iPhone — замок иначе запер бы навсегда.
      _locked = result == UnlockResult.failed;
      _failed = result == UnlockResult.failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    if (settings != null && _locked == null) {
      _locked = settings.lockEnabled;
      if (_locked!) WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_unlock()));
    }
    if (settings != null && !settings.lockEnabled) _locked = false;
    final hidden = settings == null || _locked! || _cover;
    return Stack(
      children: [
        Visibility(visible: !hidden, maintainState: true, child: widget.child),
        if (settings != null && _locked!)
          _LockScreen(busy: _busy, failed: _failed, onUnlock: () => unawaited(_unlock()))
        else if (hidden)
          const _Cover(),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: const Center(child: IconBubble(iconKey: 'wallet', colorKey: 'lavender', size: 72)),
  );
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.busy, required this.failed, required this.onUnlock});

  final bool busy;
  final bool failed;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    return Material(
      key: const ValueKey('lock-screen'),
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            children: [
              const Spacer(),
              const IconBubble(iconKey: 'wallet', colorKey: 'lavender', size: 72),
              const SizedBox(height: AppSpacing.s16),
              Text(l.appTitle, style: text.titleLarge),
              const SizedBox(height: AppSpacing.s6),
              Text(l.lockReason, textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const Spacer(),
              FilledButton.icon(
                key: const ValueKey('lock-unlock'),
                onPressed: busy ? null : onUnlock,
                icon: const Icon(Icons.face_rounded),
                label: Text(failed ? l.retry : l.lockUnlock),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
