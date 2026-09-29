import 'package:flutter/material.dart';

import '../domain/account.dart';

/// Действия и график по кредиту / кредитной линии — этап 3 (spec.md §11).
class ObligationActions extends StatelessWidget {
  const ObligationActions({super.key, required this.account});
  final Account account;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class LoanScheduleSection extends StatelessWidget {
  const LoanScheduleSection({super.key, required this.account});
  final Account account;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
