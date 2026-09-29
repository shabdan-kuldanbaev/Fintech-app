import 'package:flutter/material.dart';

import '../../../app/format.dart';
import '../../../app/widgets/dialogs.dart';

/// Наборы напоминаний (§5.3): «за 3 дня и в день» по умолчанию.
const List<List<int>> remindOptions = [
  [3, 0],
  [1, 0],
  [0],
  [3],
  [7, 1],
  [],
];

/// «3 days before · On the day», «Off».
String remindText(BuildContext context, List<int> days) {
  final l = context.l10n;
  if (days.isEmpty) return l.remindOff;
  return days.map((d) => l.remindDaysBefore(d)).join(' · ');
}

Future<List<int>?> pickRemindDays(BuildContext context) async {
  final picked = await showPickSheet<int>(
    context,
    title: context.l10n.ruleRemind,
    items: [
      for (var i = 0; i < remindOptions.length; i++) PickItem(value: i, label: remindText(context, remindOptions[i])),
    ],
  );
  return picked == null ? null : remindOptions[picked];
}
