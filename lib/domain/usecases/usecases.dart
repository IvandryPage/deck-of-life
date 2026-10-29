import '../../core/errors/app_exception.dart';
import '../entities/entities.dart';
import '../entities/enums.dart';
import '../entities/logic.dart';
import '../repositories/repositories.dart';
import '../../core/utils/date_time_utils.dart';
import '../entities/recurrence.dart';
import 'reminder_coordinator.dart';

/// Use case: logika yang menyentuh lebih dari satu repository, atau yang punya
/// efek samping pengingat. Pembacaan/penulisan sederhana dipanggil controller
/// langsung ke repository (TDD bagian 3: use case boleh tetap sederhana).

class SaveResult<T> {
  const SaveResult(this.value, [this.reminder]);

  final T value;

  /// Hasil penjadwalan pengingat bila ada (UI menampilkan [ReminderOutcome.message]).
  final ReminderOutcome? reminder;
}

void _requireText(String value, String fieldName) {
  if (value.trim().isEmpty) {
    throw ValidationException('$fieldName tidak boleh kosong.');
  }
}

// ---------------------------------------------------------------------------
// Saved items
// ---------------------------------------------------------------------------

class SearchSavedItems {
  SearchSavedItems(this._repo);
  final SavedItemRepository _repo;

  Future<List<SavedItem>> call(
    String query, {
    SavedItemType? type,
    String? courseName,
    ReviewStatus? reviewStatus,
    bool includeArchived = false,
    int limit = 50,
    int offset = 0,
  }) => _repo.search(
    query,
    type: type,
    courseName: courseName,
    reviewStatus: reviewStatus,
    includeArchived: includeArchived,
    limit: limit,
    offset: offset,
  );
}

class SaveSavedItem {
  SaveSavedItem(this._repo, this._coordinator);
  final SavedItemRepository _repo;
  final ReminderCoordinator _coordinator;

  /// Menyimpan secepat mungkin: hanya judul yang divalidasi. Kegagalan
  /// pengingat tidak membatalkan penyimpanan.
  Future<SaveResult<SavedItem>> call(
    SavedItem item, {
    required bool isNew,
    DateTime? reminderAt,
  }) async {
    _requireText(item.title, 'Judul');
    if (isNew) {
      await _repo.create(item);
    } else {
      await _repo.update(item);
    }
    ReminderOutcome? outcome;
    if (reminderAt != null) {
      outcome = await _coordinator.setReminder(
        ReminderTargetType.savedItem,
        item.id,
        reminderAt,
      );
    } else if (!isNew) {
      await _coordinator.clearForTarget(ReminderTargetType.savedItem, item.id);
    }
    return SaveResult(item, outcome);
  }
}

class ArchiveSavedItem {
  ArchiveSavedItem(this._repo, this._coordinator);
  final SavedItemRepository _repo;
  final ReminderCoordinator _coordinator;

  Future<void> call(String id) async {
    final ids = await _repo.archive(id, DateTime.now());
    await _coordinator.cancelIds(ids);
  }
}

class DeleteSavedItem {
  DeleteSavedItem(this._repo, this._coordinator);
  final SavedItemRepository _repo;
  final ReminderCoordinator _coordinator;

  Future<void> call(String id) async {
    final ids = await _repo.deletePermanently(id);
    await _coordinator.cancelIds(ids);
  }
}

// ---------------------------------------------------------------------------
// Tugas
// ---------------------------------------------------------------------------

class SaveTask {
  SaveTask(this._tasks, this._coordinator);
  final TaskRepository _tasks;
  final ReminderCoordinator _coordinator;

  Future<SaveResult<Task>> call(
    Task task, {
    required bool isNew,
    DateTime? reminderAt,
    List<String> savedItemIds = const [],
  }) async {
    _requireText(task.title, 'Judul tugas');
    if (task.estimatedMinutes != null && task.estimatedMinutes! < 0) {
      throw const ValidationException('Estimasi durasi tidak boleh negatif.');
    }
    if (isNew) {
      await _tasks.create(task, savedItemIds: savedItemIds);
    } else {
      await _coordinator.cancelIds(await _tasks.update(task));
    }
    ReminderOutcome? outcome;
    if (task.isActive && reminderAt != null) {
      outcome = await _coordinator.setReminder(
        ReminderTargetType.task,
        task.id,
        reminderAt,
      );
    } else if (!isNew) {
      await _coordinator.clearForTarget(ReminderTargetType.task, task.id);
    }
    return SaveResult(task, outcome);
  }
}

class ChangeTaskStatus {
  ChangeTaskStatus(this._tasks, this._reminders, this._coordinator);
  final TaskRepository _tasks;
  final ReminderRepository _reminders;
  final ReminderCoordinator _coordinator;

  /// Mengembalikan tugas berikutnya bila tugas berulang baru saja selesai.
  Future<Task?> call(String taskId, TaskStatus status, {DateTime? now}) async {
    final before = await _tasks.getById(taskId);
    final oldReminder = before == null
        ? null
        : await _reminders.getForTarget(ReminderTargetType.task, taskId);
    final ids = await _tasks.setStatus(taskId, status);
    await _coordinator.cancelIds(ids);

    if (status != TaskStatus.done || before == null || !before.isRecurring) {
      return null;
    }
    final rule = RecurrenceRule.tryParse(before.recurrenceRule);
    if (rule == null) return null;
    final n = now ?? DateTime.now();
    final base = before.dueAt ?? n;
    // Tidak boleh menghasilkan tugas baru yang sudah terlambat.
    final nextDue = rule.nextAfter(base, n);
    final next = await _tasks.createNextOccurrence(before, nextDue);
    if (next != null && oldReminder != null && before.dueAt != null) {
      // Selisih pengingat terhadap tenggat dipertahankan.
      final offset = before.dueAt!.difference(oldReminder.remindAt);
      await _coordinator.setReminder(
        ReminderTargetType.task,
        next.id,
        nextDue.subtract(offset),
      );
    }
    return next;
  }

  /// Urungkan penyelesaian: buka kembali tugas dan hapus kemunculan berikutnya
  /// yang baru dibuat (tugas berulang) agar tidak tersisa duplikat.
  Future<void> undoDone(String taskId, {String? spawnedId}) async {
    await call(taskId, TaskStatus.todo);
    if (spawnedId != null) {
      await _coordinator.cancelIds(await _tasks.delete(spawnedId));
    }
  }
}

/// "Geser ke besok / akhir pekan": satu aksi untuk tugas yang terlewat,
/// pengingat ikut digeser dengan selisih yang sama.
class RescheduleTask {
  RescheduleTask(this._tasks, this._reminders, this._coordinator);
  final TaskRepository _tasks;
  final ReminderRepository _reminders;
  final ReminderCoordinator _coordinator;

  Future<void> call(String taskId, int days, {DateTime? now}) async {
    if (days < 1) {
      throw const ValidationException('Pilih tanggal di masa depan.');
    }
    final task = await _tasks.getById(taskId);
    if (task == null) {
      throw const ValidationException('Tugas tidak ditemukan.');
    }
    final n = now ?? DateTime.now();
    final oldReminder = await _reminders.getForTarget(
      ReminderTargetType.task,
      taskId,
    );
    final newDue = Reschedule.shift(task.dueAt, n, days);
    await _coordinator.cancelIds(
      await _tasks.update(task.copyWith(dueAt: newDue, updatedAt: n)),
    );
    if (oldReminder != null && task.isActive) {
      final offset = task.dueAt == null
          ? Duration.zero
          : task.dueAt!.difference(oldReminder.remindAt);
      final at = newDue.subtract(offset.isNegative ? Duration.zero : offset);
      await _coordinator.setReminder(ReminderTargetType.task, taskId, at);
    }
  }
}

class DeleteTask {
  DeleteTask(this._tasks, this._coordinator);
  final TaskRepository _tasks;
  final ReminderCoordinator _coordinator;

  Future<void> call(String taskId) async {
    final ids = await _tasks.delete(taskId);
    await _coordinator.cancelIds(ids);
  }
}

// ---------------------------------------------------------------------------
// Agenda
// ---------------------------------------------------------------------------

class SaveEvent {
  SaveEvent(this._events, this._coordinator);
  final EventRepository _events;
  final ReminderCoordinator _coordinator;

  Future<SaveResult<Event>> call(
    Event event, {
    required bool isNew,
    DateTime? reminderAt,
  }) async {
    _requireText(event.title, 'Judul agenda');
    if (event.endsAt != null && event.endsAt!.isBefore(event.startsAt)) {
      throw const ValidationException(
        'Waktu selesai tidak boleh sebelum waktu mulai.',
      );
    }
    if (isNew) {
      await _events.create(event);
    } else {
      await _events.update(event);
    }
    ReminderOutcome? outcome;
    if (reminderAt != null) {
      outcome = await _coordinator.setReminder(
        ReminderTargetType.event,
        event.id,
        reminderAt,
      );
    } else if (!isNew) {
      await _coordinator.clearForTarget(ReminderTargetType.event, event.id);
    }
    return SaveResult(event, outcome);
  }
}

class DeleteEvent {
  DeleteEvent(this._events, this._coordinator);
  final EventRepository _events;
  final ReminderCoordinator _coordinator;

  Future<void> call(String id) async {
    await _coordinator.cancelIds(await _events.delete(id));
  }
}

// ---------------------------------------------------------------------------
// Keuangan
// ---------------------------------------------------------------------------

class SaveBill {
  SaveBill(this._finance, this._coordinator);
  final FinanceRepository _finance;
  final ReminderCoordinator _coordinator;

  Future<SaveResult<Bill>> call(
    Bill bill, {
    required bool isNew,
    DateTime? reminderAt,
  }) async {
    _requireText(bill.title, 'Nama tagihan');
    if (bill.amount <= 0) {
      throw const ValidationException('Nominal tagihan harus lebih dari 0.');
    }
    if (isNew) {
      await _finance.createBill(bill);
    } else {
      await _coordinator.cancelIds(await _finance.updateBill(bill));
    }
    ReminderOutcome? outcome;
    if (bill.isUnpaid && reminderAt != null) {
      outcome = await _coordinator.setReminder(
        ReminderTargetType.bill,
        bill.id,
        reminderAt,
      );
    } else if (!isNew) {
      await _coordinator.clearForTarget(ReminderTargetType.bill, bill.id);
    }
    return SaveResult(bill, outcome);
  }
}

/// Marks a bill paid and records its expense before creating the next occurrence.
class MarkBillPaid {
  MarkBillPaid(this._finance, this._reminders, this._coordinator);
  final FinanceRepository _finance;
  final ReminderRepository _reminders;
  final ReminderCoordinator _coordinator;
  _BillPaymentUndo? _undo;

  Future<Bill?> call(
    String billId, {
    required String accountId,
    DateTime? now,
  }) async {
    final bill = await _finance.getBill(billId);
    final oldReminder = await _reminders.getForTarget(
      ReminderTargetType.bill,
      billId,
    );
    final n = now ?? DateTime.now();
    final ids = await _finance.markBillPaid(billId, accountId, n);
    await _coordinator.cancelIds(ids);

    if (bill == null || !bill.isUnpaid) return null;
    final rule = RecurrenceRule.tryParse(bill.recurrenceRule);
    if (rule == null) {
      _undo = _BillPaymentUndo(
        billId: bill.id,
        nextBillId: null,
        reminderAt: oldReminder?.remindAt,
      );
      return null;
    }
    // Dibayar terlambat: tagihan berikutnya tetap di jadwal kalender aslinya,
    // tetapi tidak boleh langsung jatuh di masa lalu.
    final nextDue = rule.nextAfter(
      bill.dueAt,
      n.subtract(const Duration(days: 1)),
    );
    final next = await _finance.createNextBillIfAbsent(bill, nextDue);
    if (next != null && oldReminder != null) {
      final offset = bill.dueAt.difference(oldReminder.remindAt);
      await _coordinator.setReminder(
        ReminderTargetType.bill,
        next.id,
        nextDue.subtract(offset),
      );
    }
    _undo = _BillPaymentUndo(
      billId: bill.id,
      nextBillId: next?.id,
      reminderAt: oldReminder?.remindAt,
    );
    return next;
  }

  Future<void> undo() async {
    final undo = _undo;
    if (undo == null) {
      throw const ValidationException('Tidak ada pembayaran yang bisa diurungkan.');
    }
    final reminderIds = await _finance.undoBillPayment(
      undo.billId,
      nextBillId: undo.nextBillId,
    );
    await _coordinator.cancelIds(reminderIds);
    final reminderAt = undo.reminderAt;
    if (reminderAt != null) {
      await _coordinator.setReminder(
        ReminderTargetType.bill,
        undo.billId,
        reminderAt,
      );
    }
    _undo = null;
  }
}

class _BillPaymentUndo {
  const _BillPaymentUndo({
    required this.billId,
    required this.nextBillId,
    required this.reminderAt,
  });

  final String billId;
  final String? nextBillId;
  final DateTime? reminderAt;
}

class DeleteBill {
  DeleteBill(this._finance, this._coordinator);
  final FinanceRepository _finance;
  final ReminderCoordinator _coordinator;

  Future<void> call(String billId) async {
    await _coordinator.cancelIds(await _finance.deleteBill(billId));
  }
}

// ---------------------------------------------------------------------------
// Rutinitas
// ---------------------------------------------------------------------------

class SaveRoutine {
  SaveRoutine(this._routines, this._coordinator);
  final RoutineRepository _routines;
  final ReminderCoordinator _coordinator;

  /// Rutinitas baru: jadwal pertama dihitung dari sekarang. Bila [remind] true,
  /// pengingat dipasang pada jadwal berikutnya.
  Future<SaveResult<Routine>> call(
    Routine routine, {
    required bool isNew,
    required bool remind,
  }) async {
    _requireText(routine.title, 'Nama rutinitas');
    if (routine.recurrenceType == RecurrenceType.interval &&
        (routine.intervalDays == null || routine.intervalDays! < 1)) {
      throw const ValidationException('Interval hari minimal 1.');
    }
    if (routine.recurrenceType == RecurrenceType.weekly &&
        routine.weekdays.isEmpty) {
      throw const ValidationException('Pilih minimal satu hari.');
    }

    var saved = routine;
    if (isNew || routine.nextDueAt == null) {
      saved = Routine(
        id: routine.id,
        title: routine.title,
        description: routine.description,
        recurrenceType: routine.recurrenceType,
        intervalDays: routine.intervalDays,
        weekdays: routine.weekdays,
        preferredTime: routine.preferredTime,
        nextDueAt: RoutineScheduler.firstDue(routine, DateTime.now()),
        lastCompletedAt: routine.lastCompletedAt,
        isActive: routine.isActive,
        createdAt: routine.createdAt,
        updatedAt: routine.updatedAt,
      );
    }
    if (isNew) {
      await _routines.create(saved);
    } else {
      await _routines.update(saved);
    }

    ReminderOutcome? outcome;
    if (remind && saved.isActive && saved.nextDueAt != null) {
      outcome = await _coordinator.setReminder(
        ReminderTargetType.routine,
        saved.id,
        RoutineScheduler.reminderTime(saved)!,
      );
    } else if (!isNew) {
      await _coordinator.clearForTarget(ReminderTargetType.routine, saved.id);
    }
    return SaveResult(saved, outcome);
  }
}

/// Hanya aksi eksplisit "Selesai" yang mencatat pelaksanaan (TDD 6.6).
class CompleteRoutine {
  CompleteRoutine(this._routines, this._reminders, this._coordinator);
  final RoutineRepository _routines;
  final ReminderRepository _reminders;
  final ReminderCoordinator _coordinator;

  Future<SaveResult<Routine>> call(String id, {String? note}) async {
    final hadReminder =
        await _reminders.getForTarget(ReminderTargetType.routine, id) != null;
    final updated = await _routines.complete(id, DateTime.now(), note: note);
    ReminderOutcome? outcome;
    if (hadReminder && updated.nextDueAt != null && updated.isActive) {
      outcome = await _coordinator.setReminder(
        ReminderTargetType.routine,
        id,
        RoutineScheduler.reminderTime(updated)!,
      );
    }
    return SaveResult(updated, outcome);
  }
}

/// "Lewati hari ini": geser jadwal ke kemunculan berikutnya TANPA mencatat
/// pelaksanaan, jadi riwayat tetap jujur.
class SkipRoutine {
  SkipRoutine(this._routines, this._reminders, this._coordinator);
  final RoutineRepository _routines;
  final ReminderRepository _reminders;
  final ReminderCoordinator _coordinator;

  Future<void> call(String id, {DateTime? now}) async {
    final routine = await _routines.getById(id);
    if (routine == null || !routine.isActive) return;
    final n = now ?? DateTime.now();
    final next = RoutineScheduler.nextDue(routine, n);
    if (next == null) return;
    final hadReminder =
        await _reminders.getForTarget(ReminderTargetType.routine, id) != null;
    final updated = routine.copyWith(nextDueAt: next, updatedAt: n);
    await _routines.update(updated);
    if (hadReminder) {
      await _coordinator.setReminder(
        ReminderTargetType.routine,
        id,
        RoutineScheduler.reminderTime(updated)!,
      );
    }
  }
}

class DeleteRoutine {
  DeleteRoutine(this._routines, this._coordinator);
  final RoutineRepository _routines;
  final ReminderCoordinator _coordinator;

  Future<void> call(String id) async {
    await _coordinator.cancelIds(await _routines.delete(id));
  }
}

// ---------------------------------------------------------------------------
// Pencarian & dashboard
// ---------------------------------------------------------------------------

class SearchResults {
  const SearchResults({
    required this.items,
    required this.tasks,
    this.events = const [],
    this.bills = const [],
  });
  final List<SavedItem> items;
  final List<Task> tasks;
  final List<Event> events;
  final List<Bill> bills;

  int get total => items.length + tasks.length + events.length + bills.length;
  bool get isEmpty => total == 0;
}

class SearchAll {
  SearchAll(this._items, this._tasks, this._events, this._finance);
  final SavedItemRepository _items;
  final TaskRepository _tasks;
  final EventRepository _events;
  final FinanceRepository _finance;

  Future<SearchResults> call(
    String query, {
    SavedItemType? type,
    String? courseName,
    ReviewStatus? reviewStatus,
    int limit = 50,
  }) async {
    final items = await _items.search(
      query,
      type: type,
      courseName: courseName,
      reviewStatus: reviewStatus,
      limit: limit,
    );
    // Tugas, agenda, dan tagihan ikut dicari hanya bila tidak ada filter khusus
    // item tersimpan.
    final filteredToItems =
        type != null || reviewStatus != null || courseName != null;
    if (query.trim().isEmpty || filteredToItems) {
      return SearchResults(items: items, tasks: const []);
    }
    return SearchResults(
      items: items,
      tasks: await _tasks.search(query, limit: limit),
      events: await _events.search(query, limit: limit),
      bills: await _finance.searchBills(query, limit: limit),
    );
  }
}

class GetDashboard {
  GetDashboard({
    required EventRepository events,
    required TaskRepository tasks,
    required SavedItemRepository savedItems,
    required FinanceRepository finance,
    required RoutineRepository routines,
    required SettingsRepository settings,
  }) : _events = events,
       _tasks = tasks,
       _savedItems = savedItems,
       _finance = finance,
       _routines = routines,
       _settings = settings;

  final EventRepository _events;
  final TaskRepository _tasks;
  final SavedItemRepository _savedItems;
  final FinanceRepository _finance;
  final RoutineRepository _routines;
  final SettingsRepository _settings;

  static const int backupReminderDays = 14;

  Future<DashboardData> call({DateTime? now}) async {
    final n = now ?? DateTime.now();

    final todayEvents = await _events.listBetween(
      DateTimeUtils.startOfDay(n),
      DateTimeUtils.startOfNextDay(n),
    );

    final activeTasks = await _tasks.list(
      statuses: {
        TaskStatus.needsReview,
        TaskStatus.todo,
        TaskStatus.inProgress,
      },
    );
    final overdue = activeTasks.where((t) => t.isOverdue(n)).toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    final nearest = TaskOrdering.nearestDeadlines(activeTasks);
    final reviewTasks = activeTasks
        .where((t) => t.status == TaskStatus.needsReview)
        .length;
    final reviewItems = await _savedItems.countNeedsReview();

    final accounts = await _finance.accounts();
    final unpaid = await _finance.bills(statuses: {BillStatus.unpaid});
    final horizon =
        int.tryParse(
          await _settings.get(SettingKeys.financeHorizonDays) ?? '',
        ) ??
        30;
    final workdays = int.tryParse(
      await _settings.get(SettingKeys.availableWorkdays) ?? '',
    );
    final income =
        int.tryParse(await _settings.get(SettingKeys.confirmedIncome) ?? '') ??
        0;
    final reality = RealityCheck.compute(
      accounts: accounts,
      bills: unpaid,
      now: n,
      horizonDays: horizon,
      confirmedIncome: income,
      workdays: workdays,
    );

    final routines =
        (await _routines.list(
            activeOnly: true,
          )).where((r) => r.nextDueAt != null).toList()
          ..sort((a, b) => a.nextDueAt!.compareTo(b.nextDueAt!));
    final dueRoutines = routines.where((r) => r.isDue(n)).length;

    // Pengingat backup hanya muncul bila sudah ada data yang layak diamankan.
    final lastBackup = DateTime.tryParse(
      await _settings.get(SettingKeys.lastBackupAt) ?? '',
    );
    final hasData =
        activeTasks.isNotEmpty ||
        reviewItems > 0 ||
        accounts.isNotEmpty ||
        unpaid.isNotEmpty;
    final backupReminder =
        hasData &&
        (lastBackup == null ||
            n.difference(lastBackup).inDays >= backupReminderDays);

    return DashboardData(
      todayEvents: todayEvents,
      nearestDeadlines: nearest,
      overdueTasks: overdue,
      reality: reality,
      needsReviewItemCount: reviewItems,
      needsReviewTaskCount: reviewTasks,
      nextRoutines: routines.take(3).toList(),
      dueRoutineCount: dueRoutines,
      nextAction: NextActionAdvisor.choose(
        now: n,
        activeTasks: activeTasks,
        unpaidBills: unpaid,
        dueRoutineCount: dueRoutines,
        needsReviewItemCount: reviewItems,
      ),
      backupReminder: backupReminder,
    );
  }
}
