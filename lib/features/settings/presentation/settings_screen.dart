import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/format.dart';
import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/version.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/dialogs.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/header.dart';
import '../../../app/widgets/toast.dart';
import '../../accounts/presentation/style_pickers.dart';
import '../../currencies/presentation/rates_screen.dart';
import '../domain/settings.dart';

/// «Settings» (§8.3): язык, основная валюта, курсы, начало месяца,
/// напоминания и сводка, бюджеты, категории, резервная копия, «About».
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return GlassScaffold(
      header: ScreenHeader(leading: HeaderBack(tooltip: l.back), title: l.settingsTitle),
      body: (context) => const _SettingsBody(),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody();

  Future<void> _write(WidgetRef ref, String key, Object? value) =>
      ref.read(settingsRepositoryProvider).write(key, value);

  Future<int?> _pickTime(BuildContext context, int minutes) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
    return t == null ? null : t.hour * 60 + t.minute;
  }

  /// Напоминания: включить — спросить разрешение iOS; выключить можно
  /// только в настройках iOS — об этом и подсказка.
  Future<void> _toggleReminders(BuildContext context, WidgetRef ref, bool on) async {
    final l = context.l10n;
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    if (!on) {
      if (overlay != null) showActionToastOn(overlay, l.settingsNotificationsOff, icon: Icons.info_outline_rounded);
      return;
    }
    final granted = await ref.read(notificationGatewayProvider).requestPermission();
    ref.invalidate(notificationPermissionProvider);
    if (granted) {
      await ref.read(reminderServiceProvider).replanQuietly();
    } else if (overlay != null) {
      showActionToastOn(overlay, l.settingsNotificationsOff, icon: Icons.info_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider).value;
    final permitted = ref.watch(notificationPermissionProvider).value;
    if (s == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final languageName = switch (s.language) {
      AppLanguage.system => l.languageSystem,
      AppLanguage.en => l.languageEnglish,
      AppLanguage.ru => l.languageRussian,
    };

    return ListView(
      padding: AppSpacing.scroll(context, top: AppSpacing.s8).copyWith(left: AppSpacing.s16, right: AppSpacing.s16),
      children: [
        RowsCard(
          children: [
            ValueRow(
              key: const ValueKey('settings-language'),
              label: l.settingsLanguage,
              value: languageName,
              onTap: () async {
                final picked = await showPickSheet<AppLanguage>(
                  context,
                  title: l.settingsLanguage,
                  selected: s.language,
                  items: [
                    PickItem(value: AppLanguage.system, label: l.languageSystem),
                    PickItem(value: AppLanguage.en, label: l.languageEnglish),
                    PickItem(value: AppLanguage.ru, label: l.languageRussian),
                  ],
                );
                if (picked != null) await _write(ref, SettingKeys.locale, picked.db);
              },
            ),
            const RowDivider(),
            ValueRow(
              key: const ValueKey('settings-base'),
              label: l.settingsBaseCurrency,
              value: s.baseCurrency,
              onTap: () => unawaited(changeBaseCurrency(context, ref, s.baseCurrency)),
            ),
            const RowDivider(),
            ValueRow(
              label: l.settingsRates,
              value: '',
              onTap: () => unawaited(context.push(Routes.rates)),
            ),
            const RowDivider(),
            ValueRow(
              key: const ValueKey('settings-month-start'),
              label: l.settingsMonthStart,
              value: l.dayOfMonth(s.monthStartDay),
              onTap: () async {
                final d = await pickDayOfMonth(context, title: l.settingsMonthStart, selected: s.monthStartDay);
                if (d != null) await _write(ref, SettingKeys.monthStartDay, d);
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        RowsCard(
          children: [
            SwitchListTile(
              key: const ValueKey('settings-reminders'),
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s18),
              title: Text(l.settingsReminders),
              subtitle: Text(l.settingsRemindersHint),
              value: permitted ?? false,
              onChanged: (v) => unawaited(_toggleReminders(context, ref, v)),
            ),
            const RowDivider(),
            ValueRow(
              label: l.settingsReminderTime,
              value: context.minutes(s.defaultReminderMinutes),
              onTap: () async {
                final m = await _pickTime(context, s.defaultReminderMinutes);
                if (m != null) await _write(ref, SettingKeys.defaultReminderMinutes, m);
              },
            ),
            const RowDivider(),
            SwitchListTile(
              key: const ValueKey('settings-digest'),
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s18),
              title: Text(l.settingsDigest),
              value: s.digestEnabled,
              onChanged: (v) => unawaited(_write(ref, SettingKeys.digestEnabled, v)),
            ),
            if (s.digestEnabled) ...[
              const RowDivider(),
              ValueRow(
                label: l.settingsDigestTime,
                value: context.minutes(s.digestMinutes),
                onTap: () async {
                  final m = await _pickTime(context, s.digestMinutes);
                  if (m != null) await _write(ref, SettingKeys.digestMinutes, m);
                },
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        RowsCard(
          children: [
            ValueRow(label: l.settingsBudgets, value: '', onTap: () => unawaited(context.push(Routes.budgets))),
            const RowDivider(),
            ValueRow(label: l.settingsCategories, value: '', onTap: () => unawaited(context.push(Routes.categories))),
            const RowDivider(),
            ValueRow(label: l.settingsBackup, value: '', onTap: () => unawaited(context.push(Routes.backup))),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        GroupLabel(l.settingsAbout),
        SoftCard(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s18, AppSpacing.s16, AppSpacing.s18, AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.settingsAboutBody, style: text.bodyMedium),
              const SizedBox(height: AppSpacing.s10),
              Text(l.settingsVersion(appVersion), style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
