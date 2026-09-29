import 'package:fintech/core/calendar.dart';
import 'package:fintech/features/payments/domain/rule.dart';
import 'package:fintech/features/payments/domain/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  late Harness h;
  setUp(() async => h = await Harness.create());
  tearDown(() => h.dispose());

  test('горизонт 92 дня, повторный прогон ничего не добавляет', () async {
    final id = await h.rule(start: LocalDate.parse('2026-10-03'));
    final first = await h.planner.replan();
    final occ = await h.occurrencesOf(id);
    // 29.09 + 92 = 30.12: 3.10, 3.11, 3.12.
    expect(occ.map((o) => o.dueDate.iso), ['2026-10-03', '2026-11-03', '2026-12-03']);
    expect(occ.map((o) => o.seq), [1, 2, 3]);
    expect(first.added, 3);
    expect((await h.planner.replan()).added, 0);
    expect(await h.occurrencesOf(id), hasLength(3));
  });

  test('на следующий день горизонт растёт, нумерация продолжается', () async {
    final id = await h.rule(start: LocalDate.parse('2026-10-03'));
    await h.planner.replan();
    h.clock.advance(const Duration(days: 40));
    await h.planner.replan();
    final occ = await h.occurrencesOf(id);
    // 8 ноября + 92 дня = 8 февраля.
    expect(occ.last.dueDate.iso, '2027-02-03');
    expect(occ.last.seq, 5);
  });

  test('годовая подписка далеко за горизонтом — одно будущее наступление', () async {
    final id = await h.rule(frequency: Frequency.yearly, start: LocalDate.parse('2027-03-15'));
    await h.planner.replan();
    expect((await h.occurrencesOf(id)).single.dueDate.iso, '2027-03-15');
  });

  test('правка правила не трогает оплаченные и пропущенные (I10)', () async {
    final card = await h.card(balance: 1000000);
    final id = await h.rule(start: h.today, accountId: card);
    await h.planner.replan();
    var occ = await h.occurrencesOf(id);
    await h.rules.pay(occ[0].id, amount: 99900, accountId: card);
    await h.rules.skip(occ[1].id);
    final r = (await h.rules.rule(id))!;
    await h.rules.update(
      id,
      RuleInput(
        name: r.name, kind: r.kind, currency: r.currency, frequency: r.frequency,
        startDate: r.startDate, amount: 120000, categoryId: r.categoryId, accountId: card,
      ),
    );
    await h.planner.replan();
    occ = await h.occurrencesOf(id);
    expect(occ[0].status, OccStatus.paid);
    expect(occ[0].amountExpected, 99900);
    expect(occ[1].status, OccStatus.skipped);
    expect(occ.where((o) => o.status == OccStatus.planned).every((o) => o.amountExpected == 120000), isTrue);
    // Уникальность (rule_id, due_date) среди живых держится.
    final dates = occ.map((o) => o.dueDate).toList();
    expect(dates.toSet().length, dates.length);
  });

  test('пауза до даты: наступлений в окне нет, после — появляются сами', () async {
    final id = await h.rule(name: 'Heating', kind: RuleKind.utility, category: 'utilities', amount: null, start: LocalDate.parse('2026-10-25'));
    await h.planner.replan();
    await h.rules.pause(id, LocalDate.parse('2026-12-01'));
    await h.planner.replan();
    var occ = await h.occurrencesOf(id);
    expect(occ.map((o) => o.dueDate.iso), ['2026-12-25']);
    await h.rules.resume(id);
    await h.planner.replan();
    occ = await h.occurrencesOf(id);
    expect(occ.map((o) => o.dueDate.iso), ['2026-12-25'], reason: 'снятые паузой не возвращаются задним числом');
  });

  test('удаление правила: запланированные уходят, оплаченные и операция остаются', () async {
    final card = await h.card(balance: 1000000);
    final id = await h.rule(start: h.today, accountId: card);
    await h.planner.replan();
    final occ = await h.occurrencesOf(id);
    final tx = await h.rules.pay(occ.first.id, amount: 99900, accountId: card);
    await h.rules.delete(id);
    final left = await h.rules.watchOfRule(id).first;
    expect(left.single.status, OccStatus.paid);
    expect(await h.transactions.get(tx), isNotNull);
    expect(await h.balance(card), 1000000 - 99900);
  });
}
