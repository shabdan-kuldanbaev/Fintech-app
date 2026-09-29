// Бюджет месяца (spec.md §9.4): строка с максимальным from_month ≤ M.
import 'package:fintech/features/budgets/data/budget_repository.dart';
import 'package:fintech/features/budgets/domain/budget.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  late Harness h;
  late BudgetRepository repo;
  setUp(() async {
    h = await Harness.create();
    repo = BudgetRepository(h.db, h.clock);
  });
  tearDown(() => h.dispose());

  test('действует последняя строка не позже месяца; прошлое не переписывается', () async {
    final cafe = await h.categoryId('cafe');
    await repo.set(cafe, 500000, '2026-07');
    await repo.set(cafe, 800000, '2026-10'); // «со следующего месяца»
    final rows = await repo.all();
    expect(effectiveBudget(rows, cafe, '2026-06'), isNull);
    expect(effectiveBudget(rows, cafe, '2026-09')!.amount, 500000);
    expect(effectiveBudget(rows, cafe, '2026-10')!.amount, 800000);
    expect(effectiveBudget(rows, cafe, '2027-01')!.amount, 800000);
    expect(effectiveBudget(rows, null, '2026-09'), isNull, reason: 'общий — отдельная строка');
  });

  test('тот же месяц правится, не дублируется; «Remove» — с месяца, история остаётся', () async {
    final cafe = await h.categoryId('cafe');
    await repo.set(cafe, 500000, '2026-09');
    await repo.set(cafe, 600000, '2026-09');
    expect((await repo.all()).where((b) => b.categoryId == cafe), hasLength(1));
    await repo.remove(cafe, '2026-11');
    final rows = await repo.all();
    expect(effectiveBudget(rows, cafe, '2026-10')!.amount, 600000);
    expect(effectiveBudget(rows, cafe, '2026-11'), isNull);
  });

  test('прогресс: осталось и перерасход', () {
    const ok = BudgetProgress(spent: 30000, budget: 50000);
    expect((ok.left, ok.over), (20000, 0));
    const over = BudgetProgress(spent: 70000, budget: 50000);
    expect((over.left, over.over, over.ratio), (-20000, 20000, 1.4));
  });
}
