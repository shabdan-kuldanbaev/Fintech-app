import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/notifications/domain/reminder_plan.dart';
import '../features/payments/domain/rule.dart';
import 'format.dart';
import 'providers.dart';
import 'router.dart';
import 'widgets/toast.dart';

/// Куда ведёт тап по уведомлению (§6).
sealed class NotificationTarget {
  const NotificationTarget();
}

/// Запланированное наступление — его экран.
final class OpenOccurrence extends NotificationTarget {
  const OpenOccurrence(this.id);
  final String id;
}

/// Сводка — вкладка Payments.
final class OpenPayments extends NotificationTarget {
  const OpenPayments({this.alreadyPaid = false});

  /// Наступление уже оплачено или удалено — тост «Already paid».
  final bool alreadyPaid;
}

/// Цель по [payload] (§6): id наступления или [digestPayload].
Future<NotificationTarget> resolveNotificationTarget(
  String payload,
  Future<Occurrence?> Function(String id) occurrence,
) async {
  if (payload == digestPayload) return const OpenPayments();
  final o = await occurrence(payload);
  if (o == null || o.status != OccStatus.planned) return const OpenPayments(alreadyPaid: true);
  return OpenOccurrence(o.id);
}

/// Переход по тапу. Верхний экран уже цель — второй тап поверх не кладёт.
/// Ошибка чтения базы не роняет приложение и не теряется.
Future<void> openFromNotification({
  required ProviderContainer container,
  required GoRouter router,
  required String payload,
}) async {
  try {
    final target = await resolveNotificationTarget(
      payload,
      container.read(ruleRepositoryProvider).occurrence,
    );
    switch (target) {
      case OpenOccurrence(:final id):
        final location = Routes.occurrence(id);
        if (router.state.uri.toString() == location) return;
        unawaited(router.push<void>(location));
      case OpenPayments(:final alreadyPaid):
        router.go(Routes.payments);
        if (!alreadyPaid) return;
        final overlay = router.routerDelegate.navigatorKey.currentState?.overlay;
        final context = router.routerDelegate.navigatorKey.currentContext;
        if (overlay == null || context == null || !context.mounted) return;
        showActionToastOn(overlay, context.l10n.notifAlreadyPaid, icon: Icons.info_outline_rounded);
    }
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'notifications'),
    );
  }
}
