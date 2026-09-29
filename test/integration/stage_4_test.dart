// Сквозной тест этапа 4 (spec.md §11, §13.3) с подменённой сетью на фикстуре
// XML: счёт в USD, расход в долларах виден в сомах по курсу НБКР; бюджет
// категории краснеет (перерасход) при превышении; смена базы пересчитывает.
import 'dart:io';

import 'package:fintech/core/calendar.dart';
import 'package:fintech/data/rates/nbkr_client.dart';
import 'package:fintech/features/accounts/domain/balances.dart';
import 'package:fintech/features/budgets/data/budget_repository.dart';
import 'package:fintech/features/budgets/domain/budget.dart';
import 'package:fintech/features/currencies/data/rates_updater.dart';
import 'package:fintech/features/stats/domain/stats.dart';
import 'package:fintech/features/transactions/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

class _Fixture implements KgsRatesSource {
  @override
  Future<Map<String, int>> fetch() async =>
      parseNbkrDaily(File('test/fixtures/nbkr_daily.xml').readAsStringSync());
}

void main() {
  test('этап 4: курс НБКР, расход в долларах в сомах, бюджет с перерасходом', () async {
    final h = await Harness.create(); // KG → база KGS
    addTearDown(h.dispose);
    await RatesUpdater(_Fixture(), h.rates, h.settings, h.clock).refresh();

    final usd = await h.card(currency: 'USD', balance: 20000, name: 'Dollars'); // 200 $
    await h.expense(usd, 1500, category: 'cafe'); // 15 $
    final tx = (await h.transactions.list(const TxnFilter())).single;
    expect(tx.baseAmount, 131175, reason: '15 USD × 87,45 = 1 311,75 KGS');

    // Главная: свои деньги в сомах — наличные (0) + 185 $ по курсу.
    final totals = computeTotals(await h.accounts.watchAll().first, await h.accounts.balances(), await h.rates.converter());
    expect(totals.ownFunds, 1617825);

    // Бюджет «Кафе» 1 000 сом — 1 311,75 потрачено: перерасход 311,75.
    final budgets = BudgetRepository(h.db, h.clock);
    final period = MonthPeriod.containing(h.today, 1);
    await budgets.set(await h.categoryId('cafe'), 100000, period.monthKey);
    final stats = periodStats(
      await h.transactions.list(const TxnFilter()),
      period: period,
      accounts: {for (final a in await h.accounts.watchAll().first) a.id: a},
      excluded: const {},
    );
    final cafe = await h.categoryId('cafe');
    final spent = stats.byCategory.firstWhere((e) => e.key == cafe).value;
    final progress = BudgetProgress(spent: spent, budget: effectiveBudget(await budgets.all(), cafe, period.monthKey)!.amount);
    expect(progress.over, 31175);

    // База → USD: операция в долларах — 15 $, бюджет — 1 000 / 87,45 = 11,44 $.
    await h.rates.changeBase('USD');
    expect((await h.transactions.list(const TxnFilter())).single.baseAmount, 1500);
    expect((await budgets.all()).single.amount, 1144);
  });
}
