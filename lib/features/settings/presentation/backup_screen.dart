import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/format.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/dialogs.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/header.dart';
import '../../../data/backup/backup_codec.dart';

/// «Backup» (§7, §8.3): «Make a backup» — файл дня и «Поделиться»;
/// список прошлых копий; «Restore from a file…» — проверка до записи,
/// диалог «Replace all data?», полная замена и перезапуск.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  /// Почему копия не подошла — текстом на экране (§7), не тостом.
  String? _error;

  String _errorText(BackupError e) {
    final l = context.l10n;
    return switch (e.kind) {
      BackupErrorKind.format => l.backupErrorFormat,
      BackupErrorKind.version => l.backupErrorVersion,
      BackupErrorKind.broken => l.backupErrorBroken(e.detail),
    };
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final service = ref.read(backupServiceProvider);
    try {
      final path = await service.export();
      ref.invalidate(backupListProvider);
      await service.share(path);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final l = context.l10n;
    final service = ref.read(backupServiceProvider);
    setState(() => _error = null);
    final BackupData? data;
    try {
      data = await service.pick();
    } on BackupError catch (e) {
      setState(() => _error = _errorText(e));
      return;
    }
    if (data == null || !mounted) return;
    final ok = await showConfirm(
      context,
      title: l.backupImportTitle,
      body: l.backupImportBody,
      cancel: l.cancel,
      confirm: l.backupReplace,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final restart = ref.read(appRestartProvider);
    final done = l.backupRestored;
    final failed = l.backupErrorBroken;
    await restart(
      work: () => service.replaceAll(data!),
      toast: done,
      failToast: (e) => e is BackupError ? failed(e.detail) : failed('$e'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final files = ref.watch(backupListProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return GlassScaffold(
      header: ScreenHeader(leading: HeaderBack(tooltip: l.back), title: l.backupTitle),
      body: (context) => ListView(
        padding: AppSpacing.scroll(context, top: AppSpacing.s8).copyWith(left: AppSpacing.s16, right: AppSpacing.s16),
        children: [
          SoftCard(
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.backupHint, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.s16),
                FilledButton.icon(
                  key: const ValueKey('backup-export'),
                  onPressed: _busy ? null : () => unawaited(_export()),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(l.backupExport),
                ),
                const SizedBox(height: AppSpacing.s8),
                OutlinedButton.icon(
                  key: const ValueKey('backup-import'),
                  onPressed: _busy ? null : () => unawaited(_import()),
                  icon: const Icon(Icons.restore_rounded),
                  label: Text(l.backupImport),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.s12),
                  Text(_error!, key: const ValueKey('backup-error'), style: text.bodyMedium?.copyWith(color: AppColors.of(context).onBlush)),
                ],
              ],
            ),
          ),
          if (files.value?.isNotEmpty ?? false) ...[
            GroupLabel(l.backupFiles),
            RowsCard(
              children: [
                for (final path in files.value!)
                  AppRow(
                    leading: const IconBubble(iconKey: 'wallet', colorKey: 'sky', size: 36),
                    title: path.split('/').last,
                    trailing: Icon(Icons.ios_share_rounded, size: 20, color: scheme.onSurfaceVariant),
                    onTap: () => unawaited(ref.read(backupServiceProvider).share(path)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
