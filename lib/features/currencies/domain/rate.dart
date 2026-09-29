import 'package:flutter/foundation.dart';

enum RateSource {
  manual('manual'),
  nbkr('nbkr');

  const RateSource(this.db);
  final String db;

  static RateSource fromDb(String value) =>
      values.firstWhere((s) => s.db == value, orElse: () => manual);
}

/// Курс валюты к базовой (`exchange_rates`, spec.md §3.1).
@immutable
class Rate {
  const Rate({
    required this.code,
    required this.rateMicro,
    required this.source,
    required this.updatedAt,
  });

  final String code;

  /// Единиц базовой валюты за 1 единицу [code] × 10⁶.
  final int rateMicro;
  final RateSource source;

  /// UTC.
  final DateTime updatedAt;
}
