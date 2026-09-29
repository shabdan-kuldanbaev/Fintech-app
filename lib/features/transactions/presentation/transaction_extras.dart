import 'package:flutter/material.dart';

import '../domain/transaction.dart';

/// Плашка «Payment for `rule` · `date`» с «Undo payment» — этап 3.
class OccurrenceLinkCard extends StatelessWidget {
  const OccurrenceLinkCard({super.key, required this.txn});

  final Txn txn;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
