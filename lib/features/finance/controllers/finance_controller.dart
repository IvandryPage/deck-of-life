import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/state/data_mutations.dart';
import '../../../core/state/data_revision.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/logic.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/usecases.dart';

enum FinanceInsightPeriod { month, last30Days, custom }

class FinanceController extends GetxController with DataMutations {
  FinanceController({
    required FinanceRepository finance,
    required SettingsRepository settings,
    required SaveBill saveBill,
    required MarkBillPaid markBillPaid,
    required DeleteBill deleteBill,
    required DataRevision revision,
  }) : _finance = finance,
       _settings = settings,
       _saveBill = saveBill,
       _markBillPaid = markBillPaid,
       _deleteBill = deleteBill,
       _revision = revision;

  final FinanceRepository _finance;
  final SettingsRepository _settings;
  final SaveBill _saveBill;
  final MarkBillPaid _markBillPaid;
  final DeleteBill _deleteBill;
  final DataRevision _revision;

  static const Uuid _uuid = Uuid();

  final RxList<Account> accounts = <Account>[].obs;
  final RxList<Bill> unpaidBills = <Bill>[].obs;
  final RxList<Bill> paidBills = <Bill>[].obs;
  final RxList<MoneyTransaction> transactions = <MoneyTransaction>[].obs;
  final Rxn<FinanceSummary> summary = Rxn<FinanceSummary>();
  final Rxn<RealityCheck> reality = Rxn<RealityCheck>();
  final RxInt horizonDays = 30.obs;
  final RxBool isLoading = true.obs;
  final RxnString lastUsedAccountId = RxnString();

  /// Riwayat transaksi: filter jenis + pencarian (dalam memori, maks 200 terbaru).
  final Rxn<TransactionDirection> txnFilter = Rxn<TransactionDirection>();
  final RxString txnQuery = ''.obs;
  final RxBool txnExpanded = false.obs;
  final RxnString errorMessage = RxnString();
  final Rx<FinanceInsightPeriod> insightPeriod = FinanceInsightPeriod.month.obs;
  final Rxn<({int income, int expense, int count, Map<String, int> byCategory})>
  currentInsight = Rxn();
  final Rxn<({int income, int expense, int count, Map<String, int> byCategory})>
  previousInsight = Rxn();
  final RxBool insightsLoading = false.obs;
  DateTime? _customInsightStart;
  DateTime? _customInsightEnd;
  int _insightRequest = 0;

  ({DateTime start, DateTime end})? get customInsightRange {
    final start = _customInsightStart;
    final end = _customInsightEnd;
    return start == null || end == null ? null : (start: start, end: end);
  }

  @override
  void onInit() {
    super.onInit();
    load();
    ever<int>(_revision.revision, (_) => load());
  }

  Future<void> load() async {
    errorMessage.value = null;
    try {
      final acc = await _finance.accounts();
      final unpaid = await _finance.bills(statuses: {BillStatus.unpaid});
      final paid = await _finance.bills(statuses: {BillStatus.paid});
      paid.sort((a, b) => (b.paidAt ?? b.dueAt).compareTo(a.paidAt ?? a.dueAt));

      final s = FinanceCalculator.summarize(acc, unpaid);
      accounts.assignAll(acc);
      unpaidBills.assignAll(unpaid);
      paidBills.assignAll(paid.take(5));
      final recent = await _finance.recentTransactions(limit: 200);
      transactions.assignAll(recent);
      lastUsedAccountId.value =
          await _settings.get(SettingKeys.lastUsedFinanceAccountId) ??
          (recent.isEmpty ? null : recent.first.accountId);
      summary.value = s;
      horizonDays.value =
          int.tryParse(
            await _settings.get(SettingKeys.financeHorizonDays) ?? '',
          ) ??
          30;
      final rc = RealityCheck.compute(
        accounts: acc,
        bills: unpaid,
        now: DateTime.now(),
        horizonDays: horizonDays.value,
      );
      reality.value = rc;
      await refreshInsights();
    } catch (e, st) {
      AppLog.error('finance.load', e, st);
      errorMessage.value = messageOf(e);
    } finally {
      isLoading.value = false;
    }
  }

  String accountName(String id) {
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return 'Deleted wallet';
  }

  // ---- Akun ---------------------------------------------------------------

  Future<bool> addAccount(String name, AccountType type, int balance) {
    final now = DateTime.now();
    return mutate(
      () => _finance.createAccount(
        Account(
          id: _uuid.v4(),
          name: name,
          accountType: type,
          confirmedBalance: balance,
          balanceConfirmedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      success: 'Wallet added',
    );
  }

  /// Koreksi saldo = saldo aktual yang pengguna lihat sekarang (TDD 6.5).
  Future<bool> confirmBalance(Account a, int balance, {String? reason}) =>
      mutate(
        () => _finance.confirmBalance(a.id, balance, reason: reason),
        success: '${a.name} balance updated',
      );

  Future<bool> renameAccount(Account a, String name) =>
      mutate(() => _finance.renameAccount(a.id, name));

  Future<bool> deactivateAccount(Account a) => mutate(
    () => _finance.deactivateAccount(a.id),
    success: '${a.name} hidden',
  );

  Future<List<BalanceAdjustment>> adjustmentsOf(Account a) =>
      _finance.adjustments(a.id);

  // ---- Transaksi opsional ---------------------------------------------------

  Future<bool> addTransaction({
    required Account account,
    required int amount,
    required TransactionDirection direction,
    required String category,
    String? note,
    DateTime? occurredAt,
  }) {
    final now = DateTime.now();
    return mutate(() async {
      await _finance.addTransaction(
        MoneyTransaction(
          id: _uuid.v4(),
          accountId: account.id,
          amount: amount,
          direction: direction,
          category: category.isEmpty ? 'Other' : category,
          note: note,
          occurredAt: occurredAt ?? now,
          createdAt: now,
          affectsBalance: true,
        ),
      );
      await _rememberAccount(account.id);
    }, success: 'Transaction recorded');
  }

  Future<void> _rememberAccount(String id) async {
    lastUsedAccountId.value = id;
    await _settings.set(SettingKeys.lastUsedFinanceAccountId, id);
  }

  Future<bool> deleteTransaction(MoneyTransaction t) async {
    final deleted = t.transferId == null
        ? [t]
        : transactions
              .where((entry) => entry.transferId == t.transferId)
              .toList();
    final ok = await mutate(() => _finance.deleteTransaction(t.id));
    if (ok) {
      AppToast.undoable(
        'Transaction deleted',
        () => undoDeleteTransactions(deleted),
      );
    }
    return ok;
  }

  Future<void> undoDeleteTransactions(List<MoneyTransaction> deleted) async {
    try {
      await _finance.restoreTransactions(deleted);
      _revision.bump();
      AppToast.show('Transaction restored');
    } catch (e, st) {
      AppLog.error('finance.undo_delete_transaction', e, st);
      AppToast.show(messageOf(e), isError: true);
    }
  }

  Future<bool> updateTransaction({
    required MoneyTransaction existing,
    required Account account,
    required int amount,
    required TransactionDirection direction,
    required String category,
    String? note,
    required DateTime occurredAt,
  }) => mutate(() async {
    await _finance.updateTransaction(
      MoneyTransaction(
        id: existing.id,
        accountId: account.id,
        amount: amount,
        direction: direction,
        category: category.isEmpty ? 'Other' : category,
        note: note,
        occurredAt: occurredAt,
        createdAt: existing.createdAt,
      ),
    );
    await _rememberAccount(account.id);
  }, success: 'Transaction updated');

  Future<bool> transfer({
    required Account from,
    required Account to,
    required int amount,
    String? note,
    DateTime? occurredAt,
  }) => mutate(() async {
    await _finance.transfer(
      fromAccountId: from.id,
      toAccountId: to.id,
      amount: amount,
      occurredAt: occurredAt ?? DateTime.now(),
      note: note,
    );
    await _rememberAccount(from.id);
  }, success: 'Transfer recorded');

  Future<bool> updateTransfer({
    required String transferId,
    required Account from,
    required Account to,
    required int amount,
    String? note,
    required DateTime occurredAt,
  }) => mutate(() async {
    await _finance.updateTransfer(
      transferId: transferId,
      fromAccountId: from.id,
      toAccountId: to.id,
      amount: amount,
      occurredAt: occurredAt,
      note: note,
    );
    await _rememberAccount(from.id);
  }, success: 'Transfer updated');

  // ---- Tagihan --------------------------------------------------------------

  Future<bool> saveBill(
    Bill bill, {
    required bool isNew,
    DateTime? reminderAt,
  }) async {
    String? message;
    final ok = await mutate(() async {
      final r = await _saveBill(bill, isNew: isNew, reminderAt: reminderAt);
      message = r.reminder?.message;
    }, success: 'Bill saved');
    if (ok && message != null) AppToast.show(message!, isError: true);
    return ok;
  }

  Future<bool> markPaid(Bill b, Account account) async {
    final ok = await mutate(() async {
      await _markBillPaid(b.id, accountId: account.id);
      await _rememberAccount(account.id);
    });
    if (ok) {
      AppToast.show(
        '"${b.title}" marked as paid and expense recorded',
        actionLabel: 'Undo',
        onAction: () => _undoMarkPaid(b),
      );
    }
    return ok;
  }

  Future<void> _undoMarkPaid(Bill bill) async {
    try {
      await _markBillPaid.undo();
      _revision.bump();
      AppToast.show('Payment for "${bill.title}" undone');
    } catch (e, st) {
      AppLog.error('finance.undo_bill_payment', e, st);
      AppToast.show(messageOf(e), isError: true);
    }
  }

  Future<bool> deleteBill(Bill b) =>
      mutate(() => _deleteBill(b.id), success: 'Bill deleted');

  Future<bool> setHorizon(int days) => mutate(
    () => _settings.set(SettingKeys.financeHorizonDays, days.toString()),
  );

  /// Transaksi setelah filter jenis dan pencarian (kategori, catatan, akun).
  List<MoneyTransaction> get filteredTransactions {
    final dir = txnFilter.value;
    final q = txnQuery.value.trim().toLowerCase();
    return transactions.where((t) {
      if (dir != null && t.direction != dir) return false;
      if (q.isEmpty) return true;
      return t.category.toLowerCase().contains(q) ||
          (t.note ?? '').toLowerCase().contains(q) ||
          accountName(t.accountId).toLowerCase().contains(q);
    }).toList();
  }

  Future<void> selectInsightPeriod(FinanceInsightPeriod period) async {
    if (period == FinanceInsightPeriod.custom) return;
    insightPeriod.value = period;
    await refreshInsights();
  }

  Future<void> selectCustomInsightPeriod(DateTime start, DateTime end) async {
    _customInsightStart = DateTime(start.year, start.month, start.day);
    _customInsightEnd = DateTime(end.year, end.month, end.day);
    insightPeriod.value = FinanceInsightPeriod.custom;
    await refreshInsights();
  }

  Future<void> refreshInsights({DateTime? now}) async {
    final request = ++_insightRequest;
    final current = now ?? DateTime.now();
    final ranges = switch (insightPeriod.value) {
      FinanceInsightPeriod.month => _monthRanges(current),
      FinanceInsightPeriod.last30Days => _rollingRanges(current, 30),
      FinanceInsightPeriod.custom => _customRanges(),
    };
    if (ranges == null) return;

    insightsLoading.value = true;
    try {
      final transactions = await Future.wait([
        _finance.transactionsBetween(start: ranges.start, end: ranges.end),
        _finance.transactionsBetween(
          start: ranges.previousStart,
          end: ranges.previousEnd,
        ),
      ]);
      if (request != _insightRequest) return;
      currentInsight.value = FinanceCalculator.summarizeTransactions(
        transactions[0],
      );
      previousInsight.value = FinanceCalculator.summarizeTransactions(
        transactions[1],
      );
    } catch (e, st) {
      AppLog.error('finance.insights', e, st);
    } finally {
      if (request == _insightRequest) insightsLoading.value = false;
    }
  }

  ({DateTime start, DateTime end, DateTime previousStart, DateTime previousEnd})
  _monthRanges(DateTime now) {
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month, now.day + 1);
    final previousMonthEnd = DateTime(now.year, now.month, 0);
    final previousEndDay = now.day < previousMonthEnd.day
        ? now.day
        : previousMonthEnd.day;
    return (
      start: start,
      end: end,
      previousStart: DateTime(now.year, now.month - 1),
      previousEnd: DateTime(now.year, now.month - 1, previousEndDay + 1),
    );
  }

  ({DateTime start, DateTime end, DateTime previousStart, DateTime previousEnd})
  _rollingRanges(DateTime now, int days) {
    final end = DateTime(now.year, now.month, now.day + 1);
    final start = end.subtract(Duration(days: days));
    return (
      start: start,
      end: end,
      previousStart: start.subtract(Duration(days: days)),
      previousEnd: start,
    );
  }

  ({
    DateTime start,
    DateTime end,
    DateTime previousStart,
    DateTime previousEnd,
  })?
  _customRanges() {
    final start = _customInsightStart;
    final lastDay = _customInsightEnd;
    if (start == null || lastDay == null) return null;
    final end = DateTime(lastDay.year, lastDay.month, lastDay.day + 1);
    final days = end.difference(start).inDays;
    return (
      start: start,
      end: end,
      previousStart: start.subtract(Duration(days: days)),
      previousEnd: start,
    );
  }
}
