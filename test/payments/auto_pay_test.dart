import 'package:fintech/core/calendar.dart';
import 'package:fintech/features/payments/domain/rule.dart';
import 'package:fintech/features/transactions/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  late Harness h;
  setUp(() async => h = await Harness.create());
  tearDown(() => h.dispose());

  test('автосписание: в день списания наступление оплачено датой due_date', () async {
    final card = await h.card(balance: 1000000);
    final id = await h.rule(start: LocalDate.parse('2026-10-03'), accountId: card, autoPay: true);
    await h.planner.replan();
    expect((await h.occurrencesOf(id)).first.status, OccStatus.planned);
    h.clock.advance(const Duration(days: 5)); // 4 октября
    final r = await h.planner.replan();
    expect(r.autoPaid, 1);
    final occ = (await h.occurrencesOf(id)).first;
    expect(occ.status, OccStatus.paid);
    final t = (await h.transactions.list(const TxnFilter())).single;
    expect(t.date.iso, '2026-10-03');
    expect((await h.planner.replan()).autoPaid, 0, reason: 'дважды не списывается');
  });

  test('без auto_pay ничего не оплачивается само (I10)', () async {
    final card = await h.card(balance: 1000000);
    final id = await h.rule(start: h.today, accountId: card);
    await h.planner.replan();
    h.clock.advance(const Duration(days: 3));
    await h.planner.replan();
    expect((await h.occurrencesOf(id)).first.status, OccStatus.planned);
  });

  test('автосписание без курса ждёт человека', () async {
    final card = await h.card(balance: 1000000);
    final id = await h.rule(start: h.today, currency: 'USD', amount: 999, accountId: card, autoPay: true);
    await h.planner.replan();
    expect((await h.occurrencesOf(id)).first.status, OccStatus.planned);
  });
}
