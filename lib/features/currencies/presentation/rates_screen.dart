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
import '../../../app/widgets/toast.dart';
import '../../../core/calendar.dart';
import '../../../core/currencies.dart';
import '../../../core/money.dart';
import '../../accounts/presentation/style_pickers.dart';
import '../data/rates_repository.dart';
import '../domain/rate.dart';

/// «Currencies» (§8.3, §4.2): основная валюта (смена — с диалогом), курсы
/// нужных валют к ней: источник и дата; тап — ручной курс; «Refresh» —
/// НБКР. При открытии курсы подтягиваются, если им больше суток.
class RatesScreen extends ConsumerStatefulWidget {
  const RatesScreen({super.key});

  @override
  ConsumerState<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends ConsumerState<RatesScreen> {
  bool _busy = false;

  /// Добавленные руками валюты без курса — пока курс не введён.
  final Set<String> _added = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_refreshIfStale()));
  }

  Future<void> _refreshIfStale() async {
    final updater = ref.read(ratesUpdaterProvider);
    if (await updater.isStale()) await _refresh(quiet: true);
  }

  Future<void> _refresh({bool quiet = false}) async {
    if (_busy) return;
    final l = context.l10n;
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    setState(() => _busy = true);
    try {
      await ref.read(ratesUpdaterProvider).refresh();
      if (!quiet && overlay != null) showActionToastOn(overlay, l.changesSaved);
    } catch (_) {
      // Сети нет или формат сменился: курс вводится руками (§4.2).
      if (!quiet && overlay != null) {
        showActionToastOn(overlay, l.ratesFetchFailed, icon: Icons.info_outline_rounded);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setManual(String code, String base, int? current) async {
    final l = context.l10n;
    final value = await showInputSheet(
      context,
      title: l.ratesSetTitle(code, base),
      action: l.save,
      numeric: true,
      initial: current == null ? '' : context.rate(current),
      validate: (v) => parseRateMicro(v) == null ? l.amountRequired : null,
    );
    if (value == null) return;
    await ref.read(ratesRepositoryProvider).setRate(code, parseRateMicro(value)!, RateSource.manual);
    setState(() => _added.remove(code));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GlassScaffold(
      header: ScreenHeader(
        leading: HeaderBack(tooltip: l.back),
        title: l.ratesTitle,
        trailing: GlassIconButton(
          icon: Icons.add_rounded,
          tooltip: l.ratesAdd,
          onPressed: () async {
            final base = ref.read(settingsProvider).value?.baseCurrency;
            final code = await pickCurrency(context);
            if (code == null || code == base) return;
            setState(() => _added.add(code));
          },
        ),
      ),
      bar: FilledButton.tonal(
        key: const ValueKey('rates-refresh'),
        onPressed: _busy ? null : () => unawaited(_refresh()),
        child: Text(l.ratesRefresh),
      ),
      body: (context) => _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final l = context.l10n;
    final rates = ref.watch(ratesProvider).value;
    final foreign = ref.watch(foreignCurrenciesProvider).value;
    final settings = ref.watch(settingsProvider).value;
    if (rates == null || foreign == null || settings == null) return const SizedBox.shrink();
    final base = settings.baseCurrency;
    final byCode = {for (final r in rates) r.code: r};
    final codes = {...foreign, ..._added, ...byCode.keys}..remove(base);
    final sorted = codes.toList()
      ..sort((a, b) {
        final need = (foreign.contains(b) ? 1 : 0) - (foreign.contains(a) ? 1 : 0);
        return need != 0 ? need : a.compareTo(b);
      });
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors.of(context);

    return ListView(
      padding: AppSpacing.scroll(context, top: AppSpacing.s8).copyWith(left: AppSpacing.s16, right: AppSpacing.s16),
      children: [
        RowsCard(
          children: [
            ValueRow(
              key: const ValueKey('rates-base'),
              label: l.ratesBase,
              value: '$base · ${currencyInfo(base).name(context.lang)}',
              onTap: () => unawaited(changeBaseCurrency(context, ref, base)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        if (sorted.isEmpty)
          SoftCard(
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: Text(l.ratesEmpty, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          )
        else
          RowsCard(
            children: [
              for (final code in sorted)
                AppRow(
                  key: ValueKey('rate-$code'),
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: scheme.surfaceContainerHigh,
                    child: Text(currencyInfo(code).sign(context.lang), maxLines: 1, style: text.labelLarge),
                  ),
                  title: l.ratesLine(code, byCode[code] == null ? '—' : context.money(_perUnit(byCode[code]!.rateMicro, base), base)),
                  subtitle: byCode[code] == null
                      ? l.ratesNoRate
                      : '${byCode[code]!.source == RateSource.manual ? l.ratesManual : l.ratesNbkr} · '
                            '${l.ratesUpdated(context.day(LocalDate.of(byCode[code]!.updatedAt.toLocal())))}',
                  subtitleColor: byCode[code] == null && foreign.contains(code) ? colors.onBlush : null,
                  trailing: Icon(Icons.edit_outlined, size: 20, color: scheme.onSurfaceVariant),
                  onTap: () => unawaited(_setManual(code, base, byCode[code]?.rateMicro)),
                ),
            ],
          ),
      ],
    );
  }

  /// Сколько минимальных единиц базы стоит 1 единица валюты: курс ×10⁶ —
  /// за целую единицу; в копейках базы — × 10^minorUnits(base).
  int _perUnit(int rateMicro, String base) {
    var p = 1;
    for (var i = 0; i < minorUnits(base); i++) {
      p *= 10;
    }
    return mulDivRound(rateMicro, p, rateScale);
  }
}

/// Смена основной валюты (§4.2): выбор, диалог, пересчёт одной транзакцией;
/// нет курса новой базы — подсказка ввести его. Общая для «Currencies» и
/// «Settings».
Future<void> changeBaseCurrency(BuildContext context, WidgetRef ref, String base) async {
  final l = context.l10n;
  final picked = await pickCurrency(context, selected: base);
  if (picked == null || picked == base || !context.mounted) return;
  final ok = await showConfirm(
    context,
    title: l.ratesChangeBaseTitle,
    body: l.ratesChangeBaseBody,
    cancel: l.cancel,
    confirm: l.change,
  );
  if (!ok || !context.mounted) return;
  final overlay = Navigator.of(context, rootNavigator: true).overlay;
  try {
    await ref.read(ratesRepositoryProvider).changeBase(picked);
    if (overlay != null) showActionToastOn(overlay, l.changesSaved);
  } on MissingBaseRate catch (e) {
    if (overlay != null) showActionToastOn(overlay, l.ratesMissingRate(e.currency), icon: Icons.info_outline_rounded);
  }
}
