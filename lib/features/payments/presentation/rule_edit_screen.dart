import 'package:flutter/material.dart';

import '../domain/rule.dart';

/// Заглушка до этапа 3 (spec.md §11).
class RuleEditScreen extends StatelessWidget {
  const RuleEditScreen({super.key, this.id, this.kind = RuleKind.subscription});
  final String? id;
  final RuleKind kind;

  @override
  Widget build(BuildContext context) => const Scaffold();
}
