import 'package:uuid/uuid.dart';

import '../../core/search/search_service.dart';
import '../../core/database/app_database.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/date_time_utils.dart';
import '../../domain/entities/entities.dart';
import '../../domain/entities/enums.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/local/reminder_cleanup.dart';
import '../models/row_mappers.dart';

class FinanceRepositoryImpl implements FinanceRepository {
  FinanceRepositoryImpl(this._db);

  final AppDatabase _db;
  static const Uuid _uuid = Uuid();

  // ---- Akun & saldo ------------------------------------------------------

  @override
  Future<List<Account>> accounts({bool activeOnly = true}) =>
      dbGuard(() async {
        final rows = await _db.raw.query(
          'accounts',
          where: activeOnly ? 'is_active = 1' : null,
          orderBy: 'created_at ASC',
        );
        return rows.map(AccountRow.fromRow).toList();
      });

  @override
  Future<Account> createAccount(Account account) => dbGuard(() async {
        if (account.name.trim().isEmpty) {
          throw const ValidationException('Nama akun tidak boleh kosong.');
        }
        if (account.confirmedBalance < 0) {
          throw const ValidationException('Saldo tidak boleh negatif.');
        }
        await _db.raw.insert('accounts', AccountRow.toRow(account));
        return account;
      });

  @override
  Future<void> renameAccount(String id, String name) => dbGuard(() async {
        if (name.trim().isEmpty) {
          throw const ValidationException('Nama akun tidak boleh kosong.');
        }
        await _db.raw.update(
          'accounts',
          {'name': name.trim(), 'updated_at': DateTimeUtils.nowIso()},
          where: 'id = ?',
          whereArgs: [id],
        );
      });

  @override
  Future<void> deactivateAccount(String id) => dbGuard(() async {
        await _db.raw.update(
          'accounts',
          {'is_active': 0, 'updated_at': DateTimeUtils.nowIso()},
          where: 'id = ?',
          whereArgs: [id],
        );
      });

  /// Koreksi saldo: update `accounts` dan insert `balance_adjustments`
  /// dalam SATU transaksi (TDD 5), sehingga tidak pernah setengah tersimpan.
  @override
  Future<void> confirmBalance(
    String accountId,
    int correctedBalance, {
    String? reason,
    DateTime? at,
  }) =>
      dbGuard(() async {
        if (correctedBalance < 0) {
          throw const ValidationException('Saldo tidak boleh negatif.');
        }
        final when = DateTimeUtils.toIso(at ?? DateTime.now());
        await _db.raw.transaction((txn) async {
          final rows = await txn.query(
            'accounts',
            columns: ['confirmed_balance'],
            where: 'id = ?',
            whereArgs: [accountId],
            limit: 1,
          );
          if (rows.isEmpty) {
            throw const ValidationException('Akun tidak ditemukan.');
          }
          final previous = rows.first['confirmed_balance'] as int;
          await txn.insert('balance_adjustments', {
            'id': _uuid.v4(),
            'account_id': accountId,
            'previous_balance': previous,
            'corrected_balance': correctedBalance,
            'reason': blankToNull(reason),
            'adjusted_at': when,
          });
          await txn.update(
            'accounts',
            {
              'confirmed_balance': correctedBalance,
              'balance_confirmed_at': when,
              'updated_at': when,
            },
            where: 'id = ?',
            whereArgs: [accountId],
          );
        });
      });

  @override
  Future<List<BalanceAdjustment>> adjustments(
    String accountId, {
    int limit = 20,
  }) =>
      dbGuard(() async {
        final rows = await _db.raw.query(
          'balance_adjustments',
          where: 'account_id = ?',
          whereArgs: [accountId],
          orderBy: 'adjusted_at DESC',
          limit: limit,
        );
        return rows.map(AdjustmentRow.fromRow).toList();
      });

  // ---- Transaksi opsional (histori saja) ----------------------------------

  @override
  Future<MoneyTransaction> addTransaction(MoneyTransaction transaction) =>
      dbGuard(() async {
        if (transaction.amount <= 0) {
          throw const ValidationException('Nominal harus lebih dari 0.');
        }
        await _db.raw
            .insert('transactions', TransactionRow.toRow(transaction));
        return transaction;
      });

  @override
  Future<void> deleteTransaction(String id) => dbGuard(() async {
        await _db.raw
            .delete('transactions', where: 'id = ?', whereArgs: [id]);
      });

  @override
  Future<List<MoneyTransaction>> recentTransactions({int limit = 30}) =>
      dbGuard(() async {
        final rows = await _db.raw.query(
          'transactions',
          orderBy: 'occurred_at DESC',
          limit: limit,
        );
        return rows.map(TransactionRow.fromRow).toList();
      });

  // ---- Tagihan -------------------------------------------------------------

  @override
  Future<Bill> createBill(Bill bill) => dbGuard(() async {
        await _db.raw.insert('bills', BillRow.toRow(bill));
        return bill;
      });

  @override
  Future<Bill?> getBill(String id) => dbGuard(() async {
        final rows = await _db.raw
            .query('bills', where: 'id = ?', whereArgs: [id], limit: 1);
        return rows.isEmpty ? null : BillRow.fromRow(rows.first);
      });

  @override
  Future<NotificationIds> updateBill(Bill bill) =>
      dbGuard(() => _db.raw.transaction((txn) async {
            final row = BillRow.toRow(bill)
              ..remove('created_at')
              ..['updated_at'] = DateTimeUtils.nowIso();
            await txn.update('bills', row, where: 'id = ?', whereArgs: [bill.id]);
            if (bill.status != BillStatus.unpaid) {
              return deleteRemindersFor(txn, ReminderTargetType.bill, bill.id);
            }
            return <int>[];
          }));

  @override
  Future<NotificationIds> markBillPaid(String id, DateTime paidAt) =>
      dbGuard(() => _db.raw.transaction((txn) async {
            await txn.update(
              'bills',
              {
                'status': BillStatus.paid.value,
                'paid_at': DateTimeUtils.toIso(paidAt),
                'updated_at': DateTimeUtils.nowIso(),
              },
              where: 'id = ?',
              whereArgs: [id],
            );
            return deleteRemindersFor(txn, ReminderTargetType.bill, id);
          }));

  @override
  Future<NotificationIds> deleteBill(String id) =>
      dbGuard(() => _db.raw.transaction((txn) async {
            final ids =
                await deleteRemindersFor(txn, ReminderTargetType.bill, id);
            await txn.delete('bills', where: 'id = ?', whereArgs: [id]);
            return ids;
          }));

  @override
  Future<List<Bill>> bills({Set<BillStatus>? statuses}) => dbGuard(() async {
        String? where;
        List<Object?>? args;
        if (statuses != null) {
          if (statuses.isEmpty) return <Bill>[];
          where = 'status IN (${List.filled(statuses.length, '?').join(',')})';
          args = statuses.map((s) => s.value).toList();
        }
        final rows = await _db.raw.query(
          'bills',
          where: where,
          whereArgs: args,
          orderBy: 'due_at ASC',
        );
        return rows.map(BillRow.fromRow).toList();
      });

  @override
  Future<List<Bill>> searchBills(String query, {int limit = 50}) =>
      dbGuard(() async {
        final like = SearchService.build(query, const ['title', 'note']);
        final rows = await _db.raw.query(
          'bills',
          where: like.where,
          whereArgs: like.args,
          orderBy: 'due_at DESC',
          limit: limit,
        );
        return rows.map(BillRow.fromRow).toList();
      });

  @override
  Future<Bill?> createNextBillIfAbsent(Bill paid, DateTime nextDue) =>
      dbGuard(() => _db.raw.transaction((txn) async {
            final dueIso = DateTimeUtils.toIso(nextDue);
            final exists = await txn.query(
              'bills',
              columns: ['id'],
              where: "title = ? AND due_at = ? AND status = 'unpaid'",
              whereArgs: [paid.title, dueIso],
              limit: 1,
            );
            if (exists.isNotEmpty) return null;
            final now = DateTime.now();
            final next = paid.copyWith(
              id: _uuid.v4(),
              dueAt: nextDue,
              status: BillStatus.unpaid,
              clearPaidAt: true,
              createdAt: now,
              updatedAt: now,
            );
            await txn.insert('bills', BillRow.toRow(next));
            return next;
          }));
}
