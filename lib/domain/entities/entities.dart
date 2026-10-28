import 'enums.dart';

/// Entity domain: tidak bergantung pada Flutter, GetX, atau SQLite.

class SavedItem {
  const SavedItem({
    required this.id,
    required this.title,
    required this.contentText,
    required this.itemType,
    required this.createdAt,
    required this.updatedAt,
    this.sourceApp,
    this.sourceLabel,
    this.sourceUrl,
    this.sourceLocation,
    this.courseName,
    this.groupName,
    this.contextNote,
    this.reviewStatus = ReviewStatus.needsReview,
    this.isFavorite = false,
    this.archivedAt,
  });

  final String id;
  final String title;
  final String contentText;
  final SavedItemType itemType;
  final String? sourceApp;
  final String? sourceLabel;
  final String? sourceUrl;

  /// Petunjuk (mis. nama grup). Bukan tautan langsung ke pesan WhatsApp.
  final String? sourceLocation;
  final String? courseName;
  final String? groupName;
  final String? contextNote;
  final ReviewStatus reviewStatus;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  bool get needsReview => reviewStatus == ReviewStatus.needsReview;
}

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.normal,
    this.dueAt,
    this.estimatedMinutes,
    this.courseName,
    this.groupName,
    this.taskKind = TaskKind.individual,
    this.instructionSource,
    this.instructionLocation,
    this.initiatedBy,
    this.nextAction,
    this.completedAt,
    this.archivedAt,
    this.recurrenceRule,
  });

  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueAt;
  final int? estimatedMinutes;
  final String? courseName;
  final String? groupName;
  final TaskKind taskKind;
  final String? instructionSource;
  final String? instructionLocation;
  final String? initiatedBy;
  final String? nextAction;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final DateTime? archivedAt;

  /// Format: lihat `RecurrenceRule`. Null = tidak berulang.
  final String? recurrenceRule;

  bool get isActive => status.isActive;
  bool get isRecurring => recurrenceRule != null;

  Task copyWith({
    String? id,
    TaskStatus? status,
    DateTime? dueAt,
    bool clearDueAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) =>
      Task(
        id: id ?? this.id,
        title: title,
        description: description,
        status: status ?? this.status,
        priority: priority,
        dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
        estimatedMinutes: estimatedMinutes,
        courseName: courseName,
        groupName: groupName,
        taskKind: taskKind,
        instructionSource: instructionSource,
        instructionLocation: instructionLocation,
        initiatedBy: initiatedBy,
        nextAction: nextAction,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
        archivedAt: archivedAt,
        recurrenceRule: recurrenceRule,
      );

  bool isOverdue(DateTime now) =>
      isActive && dueAt != null && dueAt!.isBefore(now);
}

class Event {
  const Event({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.endsAt,
    this.location,
    this.eventType = EventType.other,
    this.linkedTaskId,
    this.linkedSavedItemId,
  });

  final String id;
  final String title;
  final String description;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? location;
  final EventType eventType;
  final String? linkedTaskId;
  final String? linkedSavedItemId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class Reminder {
  const Reminder({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.remindAt,
    required this.notificationId,
    required this.createdAt,
    required this.updatedAt,
    this.repeatRule,
    this.isEnabled = true,
    this.lastScheduledAt,
  });

  final String id;
  final ReminderTargetType targetType;
  final String targetId;
  final DateTime remindAt;
  final String? repeatRule;
  final int notificationId;
  final bool isEnabled;

  /// Null = belum berhasil dijadwalkan ke OS (UI harus menampilkan ini).
  final DateTime? lastScheduledAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.accountType,
    required this.confirmedBalance,
    required this.balanceConfirmedAt,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  final String id;
  final String name;
  final AccountType accountType;

  /// Saldo terakhir yang dikonfirmasi manual. BUKAN hasil penjumlahan transaksi.
  final int confirmedBalance;
  final DateTime balanceConfirmedAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Dinamai `MoneyTransaction` agar tidak bentrok dengan `Transaction` milik sqflite.
/// Hanya histori opsional; tidak mengubah saldo terkonfirmasi (TDD 5 dan 6.5).
class MoneyTransaction {
  const MoneyTransaction({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.direction,
    required this.category,
    required this.occurredAt,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String accountId;
  final int amount;
  final TransactionDirection direction;
  final String category;
  final String? note;
  final DateTime occurredAt;
  final DateTime createdAt;
}

class BalanceAdjustment {
  const BalanceAdjustment({
    required this.id,
    required this.accountId,
    required this.previousBalance,
    required this.correctedBalance,
    required this.adjustedAt,
    this.reason,
  });

  final String id;
  final String accountId;
  final int previousBalance;
  final int correctedBalance;
  final String? reason;
  final DateTime adjustedAt;

  int get difference => correctedBalance - previousBalance;
}

class Bill {
  const Bill({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueAt,
    required this.createdAt,
    required this.updatedAt,
    this.status = BillStatus.unpaid,
    this.paidAt,
    this.accountId,
    this.note,
    this.recurrenceRule,
  });

  final String id;
  final String title;
  final int amount;
  final DateTime dueAt;
  final BillStatus status;
  final DateTime? paidAt;
  final String? accountId;
  final String? note;

  /// Format: lihat `RecurrenceRule`. Null = sekali bayar.
  final String? recurrenceRule;
  final DateTime createdAt;
  final DateTime updatedAt;

  Bill copyWith({
    String? id,
    DateTime? dueAt,
    BillStatus? status,
    DateTime? paidAt,
    bool clearPaidAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Bill(
        id: id ?? this.id,
        title: title,
        amount: amount,
        dueAt: dueAt ?? this.dueAt,
        status: status ?? this.status,
        paidAt: clearPaidAt ? null : (paidAt ?? this.paidAt),
        accountId: accountId,
        note: note,
        recurrenceRule: recurrenceRule,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  bool get isRecurring => recurrenceRule != null;
  bool get isUnpaid => status == BillStatus.unpaid;
  bool isOverdue(DateTime now) => isUnpaid && dueAt.isBefore(now);
}

class Routine {
  const Routine({
    required this.id,
    required this.title,
    required this.recurrenceType,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.intervalDays,
    this.weekdays = const [],
    this.preferredTime,
    this.nextDueAt,
    this.lastCompletedAt,
    this.isActive = true,
  });

  final String id;
  final String title;
  final String description;
  final RecurrenceType recurrenceType;
  final int? intervalDays;

  /// 1 = Senin ... 7 = Minggu (mengikuti `DateTime.weekday`).
  final List<int> weekdays;

  /// Format "HH:mm".
  final String? preferredTime;
  final DateTime? nextDueAt;
  final DateTime? lastCompletedAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isDue(DateTime now) =>
      isActive && nextDueAt != null && !nextDueAt!.isAfter(now);

  Routine copyWith({DateTime? nextDueAt, DateTime? updatedAt}) => Routine(
        id: id,
        title: title,
        description: description,
        recurrenceType: recurrenceType,
        intervalDays: intervalDays,
        weekdays: weekdays,
        preferredTime: preferredTime,
        nextDueAt: nextDueAt ?? this.nextDueAt,
        lastCompletedAt: lastCompletedAt,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class RoutineLog {
  const RoutineLog({
    required this.id,
    required this.routineId,
    required this.completedAt,
    this.note,
  });

  final String id;
  final String routineId;
  final DateTime completedAt;
  final String? note;
}
