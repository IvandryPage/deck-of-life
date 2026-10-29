import '../entities/entities.dart';
import '../entities/enums.dart';

/// Kontrak repository per fitur (TDD bagian 10). Tidak ada interface generik.
///
/// Metode yang bisa menghapus pengingat mengembalikan `List<int>` = ID notifikasi
/// OS yang harus dibatalkan pemanggil. Baris `reminders` sudah dihapus di
/// transaksi database yang sama dengan perubahan targetnya.
typedef NotificationIds = List<int>;

abstract interface class SavedItemRepository {
  Future<SavedItem> create(SavedItem item);
  Future<SavedItem?> getById(String id);

  /// Query kosong = daftar terbaru. Item `archived` disembunyikan kecuali diminta.
  Future<List<SavedItem>> search(
    String query, {
    SavedItemType? type,
    String? courseName,
    ReviewStatus? reviewStatus,
    bool includeArchived = false,
    int limit = 50,
    int offset = 0,
  });

  Future<void> update(SavedItem item);

  /// Selain `needs_review`, pengingat "periksa" milik item ikut dihapus.
  Future<NotificationIds> setReviewStatus(String id, ReviewStatus status);

  /// Item (termasuk yang diarsipkan) dengan URL sumber yang sama atau isi teks
  /// identik. Dipakai agar Share Sheet berulang tidak menumpuk duplikat.
  Future<SavedItem?> findDuplicate({String? url, String? content});
  Future<NotificationIds> archive(String id, DateTime archivedAt);
  Future<NotificationIds> deletePermanently(String id);
  Future<int> countNeedsReview();
  Future<List<String>> distinctCourseNames();
}

abstract interface class TaskRepository {
  Future<Task> create(Task task, {List<String> savedItemIds = const []});
  Future<Task?> getById(String id);

  /// Mengelola `completed_at` dan membersihkan pengingat bila status jadi
  /// selesai/dibatalkan.
  Future<NotificationIds> update(Task task);
  Future<NotificationIds> setStatus(String id, TaskStatus status);
  Future<NotificationIds> delete(String id);

  /// Tugas tidak diarsipkan, difilter status (null = semua). Urutan: lihat TaskOrdering.
  Future<List<Task>> list({Set<TaskStatus>? statuses});
  Future<List<Task>> search(String query, {int limit = 50});
  Future<int> countNeedsReview();

  /// Dipanggil saat tugas berulang selesai. Menyalin tugas (termasuk hubungan ke
  /// item tersimpan) dengan tenggat baru. Mengembalikan null bila kemunculan
  /// itu sudah ada (idempoten).
  Future<Task?> createNextOccurrence(Task completed, DateTime nextDue);

  Future<void> linkSavedItem(String taskId, String savedItemId, {String? note});
  Future<void> unlinkSavedItem(String taskId, String savedItemId);
  Future<List<SavedItem>> savedItemsFor(String taskId);
  Future<List<Task>> tasksForSavedItem(String savedItemId);
}

abstract interface class EventRepository {
  Future<Event> create(Event event);
  Future<Event?> getById(String id);
  Future<void> update(Event event);
  Future<NotificationIds> delete(String id);

  /// Event yang mulai pada [from] <= start < [to] (waktu lokal), urut waktu mulai.
  Future<List<Event>> listBetween(DateTime from, DateTime to);

  /// Event mulai hari ini dan seterusnya.
  Future<List<Event>> listUpcoming({int limit = 50});
  Future<List<Event>> search(String query, {int limit = 50});
}

abstract interface class ReminderRepository {
  /// Satu pengingat per target. Menyimpan ke DB lebih dulu; penjadwalan OS
  /// dilakukan pemanggil.
  Future<Reminder> upsertForTarget({
    required ReminderTargetType type,
    required String targetId,
    required DateTime remindAt,
  });
  Future<Reminder?> getForTarget(ReminderTargetType type, String targetId);
  Future<List<Reminder>> listEnabled();

  /// Menghapus pengingat yang targetnya sudah tidak ada atau tidak lagi relevan
  /// (tugas selesai, tagihan lunas, rutinitas nonaktif, item sudah ditinjau).
  /// Mengembalikan ID notifikasi OS yang harus dibatalkan.
  Future<NotificationIds> pruneOrphans();
  Future<void> markScheduled(String id, DateTime at);
  Future<void> setEnabled(String id, bool enabled);
  Future<NotificationIds> deleteForTarget(
    ReminderTargetType type,
    String targetId,
  );
}

abstract interface class FinanceRepository {
  Future<List<Account>> accounts({bool activeOnly = true});
  Future<Account> createAccount(Account account);
  Future<void> renameAccount(String id, String name);
  Future<void> deactivateAccount(String id);

  /// Satu transaksi DB: update `confirmed_balance` + insert `balance_adjustments`.
  Future<void> confirmBalance(
    String accountId,
    int correctedBalance, {
    String? reason,
    DateTime? at,
  });
  Future<List<BalanceAdjustment>> adjustments(
    String accountId, {
    int limit = 20,
  });

  /// Adds a new ledger entry that changes the wallet's computed balance.
  Future<MoneyTransaction> addTransaction(MoneyTransaction transaction);
  Future<void> updateTransaction(MoneyTransaction transaction);
  Future<void> deleteTransaction(String id);
  Future<void> restoreTransactions(List<MoneyTransaction> transactions);
  Future<List<MoneyTransaction>> transfer({
    required String fromAccountId,
    required String toAccountId,
    required int amount,
    required DateTime occurredAt,
    String? note,
  });
  Future<void> updateTransfer({
    required String transferId,
    required String fromAccountId,
    required String toAccountId,
    required int amount,
    required DateTime occurredAt,
    String? note,
  });
  Future<List<MoneyTransaction>> recentTransactions({int limit = 30});

  Future<Bill> createBill(Bill bill);
  Future<Bill?> getBill(String id);
  Future<NotificationIds> updateBill(Bill bill);
  Future<NotificationIds> markBillPaid(
    String id,
    String accountId,
    DateTime paidAt,
  );
  Future<NotificationIds> undoBillPayment(String id, {String? nextBillId});
  Future<NotificationIds> deleteBill(String id);
  Future<List<Bill>> bills({Set<BillStatus>? statuses});
  Future<List<Bill>> searchBills(String query, {int limit = 50});

  /// Membuat tagihan berikutnya dari tagihan berulang yang baru dibayar.
  /// Idempoten: null bila tagihan dengan judul dan jatuh tempo itu sudah ada.
  Future<Bill?> createNextBillIfAbsent(Bill paid, DateTime nextDue);
}

abstract interface class RoutineRepository {
  Future<Routine> create(Routine routine);
  Future<Routine?> getById(String id);
  Future<void> update(Routine routine);
  Future<NotificationIds> delete(String id);
  Future<List<Routine>> list({bool activeOnly = false});
  Future<void> migrateToRecurringTasks();
  Future<List<RoutineLog>> logsForTask(String taskId, {int limit = 20});

  /// Satu transaksi DB: insert `routine_logs`, set `last_completed_at`, hitung `next_due_at`.
  Future<Routine> complete(String id, DateTime completedAt, {String? note});
  Future<List<RoutineLog>> logs(String routineId, {int limit = 20});
}

abstract interface class SettingsRepository {
  Future<String?> get(String key);
  Future<void> set(String key, String value);
  Future<void> remove(String key);
}

/// Kunci `app_settings` yang dipakai aplikasi.
class SettingKeys {
  const SettingKeys._();

  static const availableWorkdays = 'available_workdays';
  static const confirmedIncome = 'confirmed_income';
  static const postWorkReviewEnabled = 'post_work_review_enabled';
  static const postWorkReviewTime = 'post_work_review_time'; // "HH:mm"
  static const financeHorizonDays = 'finance_horizon_days';
  static const lastUsedFinanceAccountId = 'last_used_finance_account_id';
  static const lastBackupAt = 'last_backup_at';
  static const firstUseAt = 'first_use_at';
  static const closeAfterShare = 'close_after_share'; // '1' (default) / '0'
}
