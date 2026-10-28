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

class FinanceController extends GetxController with DataMutations {
  FinanceController({
    required FinanceRepository finance,
    required SettingsRepository settings,
    required SaveBill saveBill,
    required MarkBillPaid markBillPaid,
    required DeleteBill deleteBill,
    required DataRevision revision,
  })  : _finance = finance,
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
  final Rxn<IncomeTarget> target = Rxn<IncomeTarget>();
  final Rxn<RealityCheck> reality = Rxn<RealityCheck>();
  final RxInt horizonDays = 30.obs;
  final RxnInt workdays = RxnInt();
  final RxInt confirmedIncome = 0.obs;
  final RxBool isLoading = true.obs;

  /// Riwayat transaksi: filter jenis + pencarian (dalam memori, maks 200 terbaru).
  final Rxn<TransactionDirection> txnFilter = Rxn<TransactionDirection>();
  final RxString txnQuery = ''.obs;
  final RxBool txnExpanded = false.obs;
  final RxnString errorMessage = RxnString();

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
      final days =
          int.tryParse(await _settings.get(SettingKeys.availableWorkdays) ?? '');
      final income =
          int.tryParse(await _settings.get(SettingKeys.confirmedIncome) ?? '') ?? 0;

      final s = FinanceCalculator.summarize(acc, unpaid);
      accounts.assignAll(acc);
      unpaidBills.assignAll(unpaid);
      paidBills.assignAll(paid.take(5));
      transactions.assignAll(await _finance.recentTransactions(limit: 200));
      workdays.value = days;
      confirmedIncome.value = income;
      summary.value = s;
      horizonDays.value = int.tryParse(
              await _settings.get(SettingKeys.financeHorizonDays) ?? '') ??
          30;
      // Target memakai kewajiban dalam horizon saja (terlambat + jatuh tempo
      // dalam N hari); tagihan jauh tidak membesarkan target hari ini.
      final rc = RealityCheck.compute(
        accounts: acc,
        bills: unpaid,
        now: DateTime.now(),
        horizonDays: horizonDays.value,
        confirmedIncome: income,
        workdays: days,
      );
      reality.value = rc;
      target.value = rc.target;
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
    return 'Akun dihapus';
  }

  // ---- Akun ---------------------------------------------------------------

  Future<bool> addAccount(String name, AccountType type, int balance) {
    final now = DateTime.now();
    return mutate(
      () => _finance.createAccount(Account(
        id: _uuid.v4(),
        name: name,
        accountType: type,
        confirmedBalance: balance,
        balanceConfirmedAt: now,
        createdAt: now,
        updatedAt: now,
      )),
      success: 'Akun ditambahkan',
    );
  }

  /// Koreksi saldo = saldo aktual yang pengguna lihat sekarang (TDD 6.5).
  Future<bool> confirmBalance(Account a, int balance, {String? reason}) => mutate(
        () => _finance.confirmBalance(a.id, balance, reason: reason),
        success: 'Saldo ${a.name} diperbarui',
      );

  Future<bool> renameAccount(Account a, String name) =>
      mutate(() => _finance.renameAccount(a.id, name));

  Future<bool> deactivateAccount(Account a) => mutate(
        () => _finance.deactivateAccount(a.id),
        success: '${a.name} disembunyikan',
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
    return mutate(
      () => _finance.addTransaction(MoneyTransaction(
        id: _uuid.v4(),
        accountId: account.id,
        amount: amount,
        direction: direction,
        category: category.isEmpty ? 'Lainnya' : category,
        note: note,
        occurredAt: occurredAt ?? now,
        createdAt: now,
      )),
      success: 'Transaksi dicatat (saldo tidak berubah)',
    );
  }

  Future<bool> deleteTransaction(MoneyTransaction t) =>
      mutate(() => _finance.deleteTransaction(t.id));

  // ---- Tagihan --------------------------------------------------------------

  Future<bool> saveBill(Bill bill, {required bool isNew, DateTime? reminderAt}) async {
    String? message;
    final ok = await mutate(() async {
      final r = await _saveBill(bill, isNew: isNew, reminderAt: reminderAt);
      message = r.reminder?.message;
    }, success: 'Tagihan tersimpan');
    if (ok && message != null) AppToast.show(message!, isError: true);
    return ok;
  }

  Future<bool> markPaid(Bill b) => mutate(
        () => _markBillPaid(b.id),
        success: '"${b.title}" ditandai dibayar. Perbarui saldo bila sudah berubah.',
      );

  Future<bool> deleteBill(Bill b) =>
      mutate(() => _deleteBill(b.id), success: 'Tagihan dihapus');

  Future<bool> setHorizon(int days) => mutate(
        () => _settings.set(SettingKeys.financeHorizonDays, days.toString()),
      );

  // ---- Asumsi target pendapatan -------------------------------------------

  Future<bool> setWorkdays(int? days) => mutate(() async {
        if (days == null) {
          await _settings.remove(SettingKeys.availableWorkdays);
        } else {
          await _settings.set(SettingKeys.availableWorkdays, days.toString());
        }
      });

  Future<bool> setConfirmedIncome(int amount) => mutate(
        () => _settings.set(SettingKeys.confirmedIncome, amount.toString()),
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

  /// Ringkasan bulan berjalan dari transaksi yang DICATAT (opsional), bukan
  /// seluruh arus kas; label di UI menyebutkan hal itu.
  ({int income, int expense, Map<String, int> byCategory}) monthSummary(
      DateTime now) {
    var inc = 0, exp = 0;
    final cats = <String, int>{};
    for (final t in transactions) {
      if (t.occurredAt.year != now.year || t.occurredAt.month != now.month) continue;
      if (t.direction == TransactionDirection.income) {
        inc += t.amount;
      } else {
        exp += t.amount;
        cats[t.category] = (cats[t.category] ?? 0) + t.amount;
      }
    }
    return (income: inc, expense: exp, byCategory: cats);
  }
}
