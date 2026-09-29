import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/calendar.dart';
import '../../../core/clock.dart';
import '../../../core/uuid.dart';
import '../../../data/db/database.dart';
import '../../categories/domain/category.dart';
import '../../currencies/data/rates_repository.dart';
import '../../settings/domain/settings.dart';
import '../domain/transaction.dart';

/// Фильтр ленты операций (§8.3 «All transactions»).
class TxnFilter {
  const TxnFilter({
    this.from,
    this.until,
    this.accountId,
    this.categoryId,
    this.kind,
    this.limit,
  });

  /// `[from, until)` по календарной дате.
  final LocalDate? from;
  final LocalDate? until;

  /// Операции, где счёт — откуда или куда.
  final String? accountId;
  final String? categoryId;
  final TxKind? kind;
  final int? limit;

  @override
  bool operator ==(Object other) =>
      other is TxnFilter &&
      other.from == from &&
      other.until == until &&
      other.accountId == accountId &&
      other.categoryId == categoryId &&
      other.kind == kind &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(from, until, accountId, categoryId, kind, limit);
}

/// Операции (spec.md §3.4, I3, I8).
class TransactionRepository {
  TransactionRepository(this._db, this._clock, this._rates);

  final AppDatabase _db;
  final Clock _clock;
  final RatesRepository _rates;

  SimpleSelectStatement<$TransactionsTable, TransactionRow> _query(TxnFilter f) {
    final q = _db.select(_db.transactions)..where((t) => t.deletedAt.isNull());
    if (f.from != null) q.where((t) => t.date.isBiggerOrEqualValue(f.from!.iso));
    if (f.until != null) q.where((t) => t.date.isSmallerThanValue(f.until!.iso));
    if (f.accountId != null) {
      q.where((t) => t.accountId.equals(f.accountId!) | t.counterAccountId.equals(f.accountId!));
    }
    if (f.categoryId != null) q.where((t) => t.categoryId.equals(f.categoryId!));
    if (f.kind != null) q.where((t) => t.kind.equals(f.kind!.db));
    q.orderBy([
      (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
    ]);
    if (f.limit != null) q.limit(f.limit!);
    return q;
  }

  Stream<List<Txn>> watch(TxnFilter filter) =>
      _query(filter).watch().map((rows) => rows.map(toTxn).toList());

  Future<List<Txn>> list(TxnFilter filter) async =>
      (await _query(filter).get()).map(toTxn).toList();

  Future<Txn?> get(String id) async {
    final row = await (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : toTxn(row);
  }

  Stream<Txn?> watchOne(String id) =>
      (_db.select(_db.transactions)..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
          .watchSingleOrNull()
          .map((r) => r == null ? null : toTxn(r));

  /// Запись операции (§3.4). Одна транзакция БД: сама операция,
  /// `last_account_id` и счёт по умолчанию категории. Внутри чужой
  /// транзакции (оплата наступления) — в ней же.
  Future<String> create(TxnInput input) async {
    final id = newId();
    await _db.transaction(() async {
      final companion = await _validated(input, id: id);
      await _db.into(_db.transactions).insert(companion);
      await _rememberAccount(input);
    });
    return id;
  }

  /// Правка существующей операции. Оплату наступления меняют только сумма,
  /// дата и заметка — связь с наступлением не рвётся.
  Future<void> update(String id, TxnInput input) async {
    await _db.transaction(() async {
      final old = await get(id);
      if (old == null) throw const TxnValidationError('missing');
      final companion = await _validated(
        TxnInput(
          kind: input.kind,
          accountId: input.accountId,
          amount: input.amount,
          date: input.date,
          counterAccountId: input.counterAccountId,
          counterAmount: input.counterAmount,
          categoryId: input.categoryId,
          note: input.note,
          occurrenceId: old.occurrenceId,
        ),
        id: id,
        createdAt: old.createdAt,
      );
      await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(companion);
    });
  }

  /// Удаление (soft). Оплату наступления удаляют отменой оплаты (I9).
  Future<void> delete(String id) async {
    final old = await get(id);
    if (old == null) return;
    if (old.occurrenceId != null) {
      throw const TxnValidationError('linked_to_occurrence');
    }
    final now = _clock.now();
    await (_db.update(_db.transactions)..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  /// «Undo» после удаления.
  Future<void> restore(String id) async {
    await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(deletedAt: const Value(null), updatedAt: Value(_clock.now())),
    );
  }

  /// Правка баланса — операция системной категории «Корректировка» на
  /// разницу (I3). Ничего не пишет, если разницы нет.
  Future<String?> adjustBalance({
    required String accountId,
    required int currentBalance,
    required int targetBalance,
    required LocalDate date,
  }) async {
    final diff = targetBalance - currentBalance;
    if (diff == 0) return null;
    final adjustment = await (_db.select(_db.categories)
          ..where((c) => c.key.equals(adjustmentKey) & c.deletedAt.isNull()))
        .getSingle();
    return create(
      TxnInput(
        kind: diff > 0 ? TxKind.income : TxKind.expense,
        accountId: accountId,
        amount: diff.abs(),
        date: date,
        categoryId: adjustment.id,
      ),
    );
  }

  Future<TransactionsCompanion> _validated(
    TxnInput input, {
    required String id,
    DateTime? createdAt,
  }) async {
    if (input.amount <= 0) throw const TxnValidationError('amount');
    final account = await (_db.select(_db.accounts)
          ..where((a) => a.id.equals(input.accountId) & a.deletedAt.isNull()))
        .getSingleOrNull();
    if (account == null) throw const TxnValidationError('account');

    int? counterAmount;
    String? categoryId;
    String? counterAccountId;
    switch (input.kind) {
      case TxKind.transfer:
        final counterId = input.counterAccountId;
        if (counterId == null || counterId == input.accountId) {
          throw const TxnValidationError('counter_account');
        }
        final counter = await (_db.select(_db.accounts)
              ..where((a) => a.id.equals(counterId) & a.deletedAt.isNull()))
            .getSingleOrNull();
        if (counter == null) throw const TxnValidationError('counter_account');
        counterAccountId = counterId;
        if (counter.currency == account.currency) {
          counterAmount = input.amount;
        } else {
          counterAmount = input.counterAmount;
          if (counterAmount == null || counterAmount <= 0) {
            throw const TxnValidationError('counter_amount');
          }
        }
      case TxKind.expense:
      case TxKind.income:
        final catId = input.categoryId;
        if (catId == null) throw const TxnValidationError('category');
        final cat = await (_db.select(_db.categories)
              ..where((c) => c.id.equals(catId)))
            .getSingleOrNull();
        if (cat == null) throw const TxnValidationError('category');
        if (cat.key != adjustmentKey && cat.kind != input.kind.db) {
          throw const TxnValidationError('category_kind');
        }
        categoryId = catId;
    }

    final converter = await _rates.converter();
    final base = converter.toBase(input.amount, account.currency);
    if (base == null) throw MissingRate(account.currency);

    final now = _clock.now();
    final note = input.note?.trim();
    return TransactionsCompanion.insert(
      id: id,
      createdAt: createdAt ?? now,
      updatedAt: now,
      kind: input.kind.db,
      accountId: input.accountId,
      counterAccountId: Value(counterAccountId),
      amount: input.amount,
      currency: account.currency,
      counterAmount: Value(counterAmount),
      baseAmount: base,
      categoryId: Value(categoryId),
      occurrenceId: Value(input.occurrenceId),
      date: input.date.iso,
      note: Value(note == null || note.isEmpty ? null : note),
    );
  }

  Future<void> _rememberAccount(TxnInput input) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(
        key: SettingKeys.lastAccountId,
        value: jsonEncode(input.accountId),
      ),
    );
    final catId = input.categoryId;
    if (catId != null && input.kind != TxKind.transfer) {
      await (_db.update(_db.categories)..where((c) => c.id.equals(catId)))
          .write(CategoriesCompanion(lastAccountId: Value(input.accountId)));
    }
  }

  static Txn toTxn(TransactionRow r) => Txn(
    id: r.id,
    kind: TxKind.fromDb(r.kind),
    accountId: r.accountId,
    counterAccountId: r.counterAccountId,
    amount: r.amount,
    currency: r.currency,
    counterAmount: r.counterAmount,
    baseAmount: r.baseAmount,
    categoryId: r.categoryId,
    occurrenceId: r.occurrenceId,
    date: LocalDate.parse(r.date),
    note: r.note,
    createdAt: r.createdAt.toUtc(),
  );
}
