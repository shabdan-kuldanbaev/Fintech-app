import 'package:flutter/material.dart';

/// Заглушка до своего этапа (spec.md §11): экран появится там.
class RuleScreen extends StatelessWidget {
  const RuleScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => const Scaffold();
}
