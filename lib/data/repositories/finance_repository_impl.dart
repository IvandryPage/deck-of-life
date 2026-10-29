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
  Future<List<Account>> accounts({bool activeOnly = true}) => dbGuard(() async {
    final rows = await _db.raw.rawQuery('''
          SELECT a.*,
            a.confirmed_balance + COALESCE(SUM(
              CASE WHEN t.direction = 'income' THEN t.amount ELSE -t.amount END
            ), 0) AS current_balance
          FROM accounts a
          LEFT JOIN transactions t
            ON t.account_id = a.id
            AND t.affects_balance = 1
            AND t.occurred_at > a.balance_confirmed_at
          ${activeOnly ? 'WHERE a.is_active = 1' : ''}
          GROUP BY a.id
          ORDER BY a.created_at ASC
          ''');
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
  }) => dbGuard(() async {
    if (correctedBalance < 0) {
      throw const ValidationException('Saldo tidak boleh negatif.');
    }
    final when = DateTimeUtils.toIso(at ?? DateTime.now());
    await _db.raw.transaction((txn) async {
      final rows = await txn.rawQuery(
        '''
            SELECT a.confirmed_balance + COALESCE(SUM(
              CASE WHEN t.direction = 'income' THEN t.amount ELSE -t.amount END
            ), 0) AS current_balance
            FROM accounts a
            LEFT JOIN transactions t
              ON t.account_id = a.id
              AND t.affects_balance = 1
              AND t.occurred_at > a.balance_confirmed_at
            WHERE a.id = ?
            GROUP BY a.id
            ''',
        [accountId],
      );
      if (rows.isEmpty) {
        throw const ValidationException('Akun tidak ditemukan.');
      }
      final previous = rows.first['current_balance'] as int;
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
  }) => dbGuard(() async {
    final rows = await _db.raw.query(
      'balance_adjustments',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'adjusted_at DESC',
      limit: limit,
    );
    return rows.map(AdjustmentRow.fromRow).toList();
  });

  // ---- Ledger transactions ------------------------------------------------

  @override
  Future<MoneyTransaction> addTransaction(MoneyTransaction transaction) =>
      dbGuard(() async {
        if (transaction.amount <= 0) {
          throw const ValidationException('Nominal harus lebih dari 0.');
        }
        if (transaction.transferId != null || transaction.billId != null) {
          throw const ValidationException(
            'Transaksi tertaut hanya dapat dibuat melalui alur khusus.',
          );
        }
        final row = TransactionRow.toRow(transaction)..['affects_balance'] = 1;
        await _db.raw.insert('transactions', row);
        return MoneyTransaction(
          id: transaction.id,
          accountId: transaction.accountId,
          amount: transaction.amount,
          direction: transaction.direction,
          category: transaction.category,
          note: transaction.note,
          occurredAt: transaction.occurredAt,
          createdAt: transaction.createdAt,
          affectsBalance: true,
        );
      });

  @override
  Future<void> updateTransaction(MoneyTransaction transaction) =>
      dbGuard(() async {
        if (transaction.amount <= 0) {
          throw const ValidationException('Nominal harus lebih dari 0.');
        }
        await _db.raw.transaction((txn) async {
          final existing = await txn.query(
            'transactions',
            columns: ['transfer_id', 'bill_id', 'affects_balance'],
            where: 'id = ?',
            whereArgs: [transaction.id],
            limit: 1,
          );
          if (existing.isEmpty) {
            throw const ValidationException('Transaksi tidak ditemukan.');
          }
          if (existing.first['transfer_id'] != null ||
              existing.first['bill_id'] != null) {
            throw const ValidationException(
              'Transaksi transfer atau tagihan harus diubah dari data asalnya.',
            );
          }
          final row = TransactionRow.toRow(transaction)
            ..remove('created_at')
            ..['affects_balance'] = existing.first['affects_balance'];
          final changed = await txn.update(
            'transactions',
            row,
            where: 'id = ?',
            whereArgs: [transaction.id],
          );
          if (changed != 1) {
            throw const ValidationException('Transaksi tidak ditemukan.');
          }
        });
      });

  @override
  Future<void> deleteTransaction(String id) => dbGuard(() async {
    await _db.raw.transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        columns: ['transfer_id', 'bill_id'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      if (rows.first['bill_id'] != null) {
        throw const ValidationException(
          'Pembayaran tagihan harus dibatalkan dari tagihannya.',
        );
      }
      final transferId = rows.first['transfer_id'] as String?;
      if (transferId == null) {
        await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
      } else {
        await txn.delete(
          'transactions',
          where: 'transfer_id = ?',
          whereArgs: [transferId],
        );
      }
    });
  });

  @override
  Future<void> restoreTransactions(List<MoneyTransaction> transactions) =>
      dbGuard(() async {
        if (transactions.isEmpty) return;
        await _db.raw.transaction((txn) async {
          for (final entry in transactions) {
            await txn.insert(
              'transactions',
              TransactionRow.toRow(entry)
                ..['affects_balance'] = entry.affectsBalance ? 1 : 0,
            );
          }
        });
      });

  @override
  Future<List<MoneyTransaction>> transfer({
    required String fromAccountId,
    required String toAccountId,
    required int amount,
    required DateTime occurredAt,
    String? note,
  }) => dbGuard(() async {
    if (amount <= 0) {
      throw const ValidationException('Nominal harus lebih dari 0.');
    }
    if (fromAccountId == toAccountId) {
      throw const ValidationException(
        'Pilih dua wallet yang berbeda untuk transfer.',
      );
    }
    final now = DateTime.now();
    final transferId = _uuid.v4();
    final outgoing = MoneyTransaction(
      id: _uuid.v4(),
      accountId: fromAccountId,
      amount: amount,
      direction: TransactionDirection.expense,
      category: 'Transfer',
      note: note,
      occurredAt: occurredAt,
      createdAt: now,
      transferId: transferId,
      affectsBalance: true,
    );
    final incoming = MoneyTransaction(
      id: _uuid.v4(),
      accountId: toAccountId,
      amount: amount,
      direction: TransactionDirection.income,
      category: 'Transfer',
      note: note,
      occurredAt: occurredAt,
      createdAt: now,
      transferId: transferId,
      affectsBalance: true,
    );
    await _db.raw.transaction((txn) async {
      for (final entry in [outgoing, incoming]) {
        await txn.insert(
          'transactions',
          TransactionRow.toRow(entry)..['affects_balance'] = 1,
        );
      }
    });
    return [outgoing, incoming];
  });

  @override
  Future<void> updateTransfer({
    required String transferId,
    required String fromAccountId,
    required String toAccountId,
    required int amount,
    required DateTime occurredAt,
    String? note,
  }) => dbGuard(() async {
    if (amount <= 0) {
      throw const ValidationException('Nominal harus lebih dari 0.');
    }
    if (fromAccountId == toAccountId) {
      throw const ValidationException(
        'Pilih dua wallet yang berbeda untuk transfer.',
      );
    }
    await _db.raw.transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'transfer_id = ?',
        whereArgs: [transferId],
      );
      final outgoing = rows
          .where(
            (row) => row['direction'] == TransactionDirection.expense.value,
          )
          .toList();
      final incoming = rows
          .where((row) => row['direction'] == TransactionDirection.income.value)
          .toList();
      if (rows.length != 2 || outgoing.length != 1 || incoming.length != 1) {
        throw const ValidationException('Pasangan transfer tidak ditemukan.');
      }

      final accounts = await txn.query(
        'accounts',
        columns: ['id'],
        where: 'is_active = 1 AND id IN (?, ?)',
        whereArgs: [fromAccountId, toAccountId],
      );
      if (accounts.length != 2) {
        throw const ValidationException('Wallet tidak ditemukan.');
      }

      final when = DateTimeUtils.toIso(occurredAt);
      await txn.update(
        'transactions',
        {
          'account_id': fromAccountId,
          'amount': amount,
          'note': blankToNull(note),
          'occurred_at': when,
        },
        where: 'id = ?',
        whereArgs: [outgoing.single['id']],
      );
      await txn.update(
        'transactions',
        {
          'account_id': toAccountId,
          'amount': amount,
          'note': blankToNull(note),
          'occurred_at': when,
        },
        where: 'id = ?',
        whereArgs: [incoming.single['id']],
      );
    });
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
    final rows = await _db.raw.query(
      'bills',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : BillRow.fromRow(rows.first);
  });

  @override
  Future<NotificationIds> updateBill(Bill bill) => dbGuard(
    () => _db.raw.transaction((txn) async {
      final row = BillRow.toRow(bill)
        ..remove('created_at')
        ..['updated_at'] = DateTimeUtils.nowIso();
      await txn.update('bills', row, where: 'id = ?', whereArgs: [bill.id]);
      if (bill.status != BillStatus.unpaid) {
        return deleteRemindersFor(txn, ReminderTargetType.bill, bill.id);
      }
      return <int>[];
    }),
  );

  @override
  Future<NotificationIds> markBillPaid(
    String id,
    String accountId,
    DateTime paidAt,
  ) => dbGuard(
    () => _db.raw.transaction((txn) async {
      final bills = await txn.query(
        'bills',
        where: 'id = ? AND status = ?',
        whereArgs: [id, BillStatus.unpaid.value],
        limit: 1,
      );
      if (bills.isEmpty) {
        throw const ValidationException(
          'Tagihan tidak ditemukan atau sudah dibayar.',
        );
      }
      final accounts = await txn.query(
        'accounts',
        columns: ['id'],
        where: 'id = ? AND is_active = 1',
        whereArgs: [accountId],
        limit: 1,
      );
      if (accounts.isEmpty) {
        throw const ValidationException('Wallet tidak ditemukan.');
      }
      final bill = BillRow.fromRow(bills.first);
      final when = DateTimeUtils.toIso(paidAt);
      await txn.update(
        'bills',
        {
          'status': BillStatus.paid.value,
          'paid_at': when,
          'account_id': accountId,
          'updated_at': DateTimeUtils.nowIso(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      final entry = MoneyTransaction(
        id: _uuid.v4(),
        accountId: accountId,
        amount: bill.amount,
        direction: TransactionDirection.expense,
        category: 'Tagihan',
        note: bill.title,
        occurredAt: paidAt,
        createdAt: DateTime.now(),
        billId: id,
        affectsBalance: true,
      );
      await txn.insert(
        'transactions',
        TransactionRow.toRow(entry)..['affects_balance'] = 1,
      );
      return deleteRemindersFor(txn, ReminderTargetType.bill, id);
    }),
  );

  @override
  Future<NotificationIds> undoBillPayment(
    String id, {
    String? nextBillId,
  }) => dbGuard(
    () => _db.raw.transaction((txn) async {
      final bills = await txn.query(
        'bills',
        columns: ['id'],
        where: 'id = ? AND status = ?',
        whereArgs: [id, BillStatus.paid.value],
        limit: 1,
      );
      if (bills.isEmpty) {
        throw const ValidationException(
          'Pembayaran tidak dapat diurungkan karena tagihan bukan berstatus paid.',
        );
      }

      await txn.delete('transactions', where: 'bill_id = ?', whereArgs: [id]);
      await txn.update(
        'bills',
        {
          'status': BillStatus.unpaid.value,
          'paid_at': null,
          'account_id': null,
          'updated_at': DateTimeUtils.nowIso(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      final reminderIds = <int>[
        ...await deleteRemindersFor(txn, ReminderTargetType.bill, id),
      ];
      if (nextBillId != null) {
        reminderIds.addAll(
          await deleteRemindersFor(txn, ReminderTargetType.bill, nextBillId),
        );
        await txn.delete(
          'bills',
          where: 'id = ? AND status = ?',
          whereArgs: [nextBillId, BillStatus.unpaid.value],
        );
      }
      return reminderIds;
    }),
  );

  @override
  Future<NotificationIds> deleteBill(String id) => dbGuard(
    () => _db.raw.transaction((txn) async {
      final ids = await deleteRemindersFor(txn, ReminderTargetType.bill, id);
      await txn.delete('bills', where: 'id = ?', whereArgs: [id]);
      return ids;
    }),
  );

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
  Future<Bill?> createNextBillIfAbsent(Bill paid, DateTime nextDue) => dbGuard(
    () => _db.raw.transaction((txn) async {
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
    }),
  );
}
