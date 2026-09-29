import 'package:flutter/material.dart';

import '../format.dart';
import '../startup.dart';
import '../theme.dart';

/// Экран отказа запуска: что случилось и что сделать.
class StartupFailureScreen extends StatelessWidget {
  const StartupFailureScreen({
    super.key,
    required this.reason,
    required this.details,
    this.onRetry,
  });

  final StartupFailureReason reason;
  final String details;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final (title, body) = switch (reason) {
      StartupFailureReason.incompatibleDatabase => (l.startupIncompatibleTitle, l.startupIncompatibleBody),
      StartupFailureReason.unknown => (l.startupUnknownTitle, l.startupUnknownBody),
    };
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(title, style: text.headlineSmall),
              const SizedBox(height: AppSpacing.s12),
              Text(body, style: text.bodyLarge),
              const SizedBox(height: AppSpacing.s16),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(l.startupDetails, style: text.bodySmall),
                children: [SelectableText(details, style: text.bodySmall)],
              ),
              const Spacer(),
              if (onRetry != null) FilledButton(onPressed: onRetry, child: Text(l.retry)),
            ],
          ),
        ),
      ),
    );
  }
}
