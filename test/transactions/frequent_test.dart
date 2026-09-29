import 'package:fintech/core/calendar.dart';
import 'package:fintech/features/transactions/domain/frequent.dart';
import 'package:fintech/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

final today = LocalDate.parse('2026-09-29');
var _n = 0;

Txn tx(int amount, {String cat = 'transport', String acc = 'card', String? note, int daysAgo = 0,
    TxKind kind = TxKind.expense, String? occ, String? to}) => Txn(
  id: 't${_n++}',
  kind: kind,
  accountId: acc,
  counterAccountId: to,
  amount: amount,
  currency: 'KGS',
  baseAmount: amount,
  categoryId: kind == TxKind.transfer ? null : cat,
  occurrenceId: occ,
  date: today.addDays(-daysAgo),
  note: note,
  createdAt: DateTime.utc(2026, 9, 29).subtract(Duration(minutes: _n)),
);

void main() {
  test('две одинаковые поездки — чип; одна — нет', () {
    final r = frequentOps([tx(1700), tx(1700, daysAgo: 1), tx(35000, cat: 'cafe')], today: today);
    expect(r, hasLength(1));
    expect(r.single.amount, 1700);
    expect(r.single.count, 2);
  });

  test('сортировка по числу повторов, затем по свежести; не больше 6', () {
    final list = <Txn>[
      for (var i = 0; i < 3; i++) tx(35000, cat: 'cafe', daysAgo: 10 + i),
      for (var i = 0; i < 2; i++) tx(1700, daysAgo: i),
      for (var i = 0; i < 2; i++) tx(20000, cat: 'taxi', daysAgo: 5 + i),
    ];
    final r = frequentOps(list, today: today);
    expect(r.map((q) => q.amount), [35000, 1700, 20000]);
    final many = [for (var k = 0; k < 8; k++) for (var i = 0; i < 2; i++) tx(100 + k, daysAgo: i)];
    expect(frequentOps(many, today: today), hasLength(6));
  });

  test('заметка без учёта регистра и пробелов; разные счета — разные чипы', () {
    final r = frequentOps([
      tx(35000, cat: 'cafe', note: 'Lunch'),
      tx(35000, cat: 'cafe', note: ' lunch ', daysAgo: 1),
      tx(35000, cat: 'cafe', note: 'lunch', acc: 'cash', daysAgo: 2),
    ], today: today);
    expect(r, hasLength(1));
    expect(r.single.note, 'Lunch');
  });

  test('старше 60 дней, оплаты наступлений и корректировки не в счёт', () {
    final r = frequentOps([
      tx(1700, daysAgo: 61), tx(1700, daysAgo: 70),
      tx(500, occ: 'o1'), tx(500, occ: 'o2'),
      tx(900, cat: 'adj'), tx(900, cat: 'adj'),
    ], today: today, excludedCategoryIds: {'adj'});
    expect(r, isEmpty);
  });

  test('переводы группируются по счёту назначения; фильтр видов', () {
    final list = [
      tx(1000000, kind: TxKind.transfer, to: 'cash'),
      tx(1000000, kind: TxKind.transfer, to: 'cash', daysAgo: 7),
    ];
    final r = frequentOps(list, today: today);
    expect(r.single.kind, TxKind.transfer);
    expect(r.single.counterAccountId, 'cash');
    expect(frequentOps(list, today: today, kinds: {TxKind.expense}), isEmpty);
  });
}
