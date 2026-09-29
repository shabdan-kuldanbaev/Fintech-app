import 'package:flutter/material.dart';

/// Иконки категорий, счетов и правил по ключу (spec.md §3.5). В базе лежит
/// ключ, а не код символа: так иконку можно заменить, не трогая данные.
/// Единственное место, где ключ превращается в `IconData`.
const Map<String, IconData> appIcons = {
  'wallet': Icons.account_balance_wallet_outlined,
  'card': Icons.credit_card_rounded,
  'bank': Icons.account_balance_outlined,
  'loan': Icons.request_quote_outlined,
  'credit_line': Icons.credit_score_outlined,
  'savings': Icons.savings_outlined,
  'deposit': Icons.lock_clock_outlined,
  'cash': Icons.payments_outlined,
  'groceries': Icons.shopping_cart_outlined,
  'cafe': Icons.local_cafe_outlined,
  'transport': Icons.directions_bus_outlined,
  'taxi': Icons.local_taxi_outlined,
  'housing': Icons.home_outlined,
  'utilities': Icons.bolt_outlined,
  'phone': Icons.smartphone_outlined,
  'internet': Icons.wifi_rounded,
  'subscriptions': Icons.autorenew_rounded,
  'health': Icons.favorite_border_rounded,
  'clothes': Icons.checkroom_outlined,
  'entertainment': Icons.confirmation_number_outlined,
  'education': Icons.menu_book_outlined,
  'gifts': Icons.card_giftcard_outlined,
  'travel': Icons.flight_outlined,
  'kids': Icons.toys_outlined,
  'pets': Icons.pets_outlined,
  'sport': Icons.fitness_center_outlined,
  'beauty': Icons.spa_outlined,
  'car': Icons.directions_car_outlined,
  'fuel': Icons.local_gas_station_outlined,
  'restaurant': Icons.restaurant_outlined,
  'water': Icons.water_drop_outlined,
  'heating': Icons.local_fire_department_outlined,
  'tv': Icons.tv_outlined,
  'music': Icons.music_note_outlined,
  'charity': Icons.volunteer_activism_outlined,
  'tax': Icons.account_balance_outlined,
  'salary': Icons.work_outline_rounded,
  'freelance': Icons.laptop_mac_outlined,
  'interest': Icons.percent_rounded,
  'adjustment': Icons.tune_rounded,
  'other': Icons.more_horiz_rounded,
};

/// Ключи, которые предлагаются в выборе иконки (без служебных).
const List<String> pickableIconKeys = [
  'groceries', 'cafe', 'restaurant', 'transport', 'taxi', 'car', 'fuel',
  'housing', 'utilities', 'water', 'heating', 'internet', 'phone', 'tv',
  'subscriptions', 'music', 'health', 'sport', 'beauty', 'clothes',
  'entertainment', 'education', 'gifts', 'travel', 'kids', 'pets', 'charity',
  'tax', 'salary', 'freelance', 'interest', 'wallet', 'card', 'bank', 'loan',
  'credit_line', 'savings', 'deposit', 'cash', 'other',
];

IconData iconFor(String key) => appIcons[key] ?? Icons.more_horiz_rounded;
