import 'dart:convert';

import '../../core/utils/date_time_utils.dart';
import '../../domain/entities/entities.dart';
import '../../domain/entities/enums.dart';

/// Pemetaan baris SQLite <-> entity domain (TDD bagian 10).
typedef DbRow = Map<String, Object?>;

String _s(DbRow r, String k) => r[k] as String;
String? _sn(DbRow r, String k) => r[k] as String?;
int _i(DbRow r, String k) => r[k] as int;
int? _in(DbRow r, String k) => r[k] as int?;
bool _b(DbRow r, String k) => (r[k] as int) == 1;
DateTime _d(DbRow r, String k) => DateTimeUtils.parse(r[k] as String);
DateTime? _dn(DbRow r, String k) => DateTimeUtils.tryParse(r[k] as String?);
String? _iso(DateTime? d) => d == null ? null : DateTimeUtils.toIso(d);

/// Mengubah string kosong menjadi null agar kolom opsional tidak berisi "".
String? blankToNull(String? v) {
  final t = v?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

class SavedItemRow {
  const SavedItemRow._();

  static SavedItem fromRow(DbRow r) => SavedItem(
    id: _s(r, 'id'),
    title: _s(r, 'title'),
    contentText: _s(r, 'content_text'),
    itemType: SavedItemType.fromValue(_s(r, 'item_type')),
    sourceApp: _sn(r, 'source_app'),
    sourceLabel: _sn(r, 'source_label'),
    sourceUrl: _sn(r, 'source_url'),
    sourceLocation: _sn(r, 'source_location'),
    courseName: _sn(r, 'course_name'),
    groupName: _sn(r, 'group_name'),
    contextNote: _sn(r, 'context_note'),
    reviewStatus: ReviewStatus.fromValue(_s(r, 'review_status')),
    isFavorite: _b(r, 'is_favorite'),
    createdAt: _d(r, 'created_at'),
    updatedAt: _d(r, 'updated_at'),
    archivedAt: _dn(r, 'archived_at'),
  );

  static DbRow toRow(SavedItem i) => {
    'id': i.id,
    'title': i.title,
    'content_text': i.contentText,
    'item_type': i.itemType.value,
    'source_app': blankToNull(i.sourceApp),
    'source_label': blankToNull(i.sourceLabel),
    'source_url': blankToNull(i.sourceUrl),
    'source_location': blankToNull(i.sourceLocation),
    'course_name': blankToNull(i.courseName),
    'group_name': blankToNull(i.groupName),
    'context_note': blankToNull(i.contextNote),
    'review_status': i.reviewStatus.value,
    'is_favorite': i.isFavorite ? 1 : 0,
    'created_at': DateTimeUtils.toIso(i.createdAt),
    'updated_at': DateTimeUtils.toIso(i.updatedAt),
    'archived_at': _iso(i.archivedAt),
  };
}

class TaskRow {
  const TaskRow._();

  static Task fromRow(DbRow r) => Task(
    id: _s(r, 'id'),
    title: _s(r, 'title'),
    description: _s(r, 'description'),
    status: TaskStatus.fromValue(_s(r, 'status')),
    priority: TaskPriority.fromValue(_s(r, 'priority')),
    dueAt: _dn(r, 'due_at'),
    estimatedMinutes: _in(r, 'estimated_minutes'),
    courseName: _sn(r, 'course_name'),
    groupName: _sn(r, 'group_name'),
    taskKind: TaskKind.fromValue(_s(r, 'task_kind')),
    instructionSource: _sn(r, 'instruction_source'),
    instructionLocation: _sn(r, 'instruction_location'),
    initiatedBy: _sn(r, 'initiated_by'),
    nextAction: _sn(r, 'next_action'),
    createdAt: _d(r, 'created_at'),
    updatedAt: _d(r, 'updated_at'),
    completedAt: _dn(r, 'completed_at'),
    archivedAt: _dn(r, 'archived_at'),
    recurrenceRule: _sn(r, 'recurrence_rule'),
  );

  static DbRow toRow(Task t) => {
    'id': t.id,
    'title': t.title,
    'description': t.description,
    'status': t.status.value,
    'priority': t.priority.value,
    'due_at': _iso(t.dueAt),
    'estimated_minutes': t.estimatedMinutes,
    'course_name': blankToNull(t.courseName),
    'group_name': blankToNull(t.groupName),
    'task_kind': t.taskKind.value,
    'instruction_source': blankToNull(t.instructionSource),
    'instruction_location': blankToNull(t.instructionLocation),
    'initiated_by': blankToNull(t.initiatedBy),
    'next_action': blankToNull(t.nextAction),
    'created_at': DateTimeUtils.toIso(t.createdAt),
    'updated_at': DateTimeUtils.toIso(t.updatedAt),
    'completed_at': _iso(t.completedAt),
    'archived_at': _iso(t.archivedAt),
    'recurrence_rule': blankToNull(t.recurrenceRule),
  };
}

class EventRow {
  const EventRow._();

  static Event fromRow(DbRow r) => Event(
    id: _s(r, 'id'),
    title: _s(r, 'title'),
    description: _s(r, 'description'),
    startsAt: _d(r, 'starts_at'),
    endsAt: _dn(r, 'ends_at'),
    location: _sn(r, 'location'),
    eventType: EventType.fromValue(_s(r, 'event_type')),
    linkedTaskId: _sn(r, 'linked_task_id'),
    linkedSavedItemId: _sn(r, 'linked_saved_item_id'),
    recurrenceRule: _sn(r, 'recurrence_rule'),
    createdAt: _d(r, 'created_at'),
    updatedAt: _d(r, 'updated_at'),
  );

  static DbRow toRow(Event e) => {
    'id': e.id,
    'title': e.title,
    'description': e.description,
    'starts_at': DateTimeUtils.toIso(e.startsAt),
    'ends_at': _iso(e.endsAt),
    'location': blankToNull(e.location),
    'event_type': e.eventType.value,
    'linked_task_id': e.linkedTaskId,
    'linked_saved_item_id': e.linkedSavedItemId,
    'recurrence_rule': blankToNull(e.recurrenceRule),
    'created_at': DateTimeUtils.toIso(e.createdAt),
    'updated_at': DateTimeUtils.toIso(e.updatedAt),
  };
}

class ReminderRow {
  const ReminderRow._();

  static Reminder fromRow(DbRow r) => Reminder(
    id: _s(r, 'id'),
    targetType: ReminderTargetType.fromValue(_s(r, 'target_type')),
    targetId: _s(r, 'target_id'),
    remindAt: _d(r, 'remind_at'),
    repeatRule: _sn(r, 'repeat_rule'),
    notificationId: _i(r, 'notification_id'),
    isEnabled: _b(r, 'is_enabled'),
    lastScheduledAt: _dn(r, 'last_scheduled_at'),
    createdAt: _d(r, 'created_at'),
    updatedAt: _d(r, 'updated_at'),
  );

  static DbRow toRow(Reminder m) => {
    'id': m.id,
    'target_type': m.targetType.value,
    'target_id': m.targetId,
    'remind_at': DateTimeUtils.toIso(m.remindAt),
    'repeat_rule': m.repeatRule,
    'notification_id': m.notificationId,
    'is_enabled': m.isEnabled ? 1 : 0,
    'last_scheduled_at': _iso(m.lastScheduledAt),
    'created_at': DateTimeUtils.toIso(m.createdAt),
    'updated_at': DateTimeUtils.toIso(m.updatedAt),
  };
}

class AccountRow {
  const AccountRow._();

  static Account fromRow(DbRow r) => Account(
    id: _s(r, 'id'),
    name: _s(r, 'name'),
    accountType: AccountType.fromValue(_s(r, 'account_type')),
    confirmedBalance: r.containsKey('current_balance')
        ? _i(r, 'current_balance')
        : _i(r, 'confirmed_balance'),
    balanceConfirmedAt: _d(r, 'balance_confirmed_at'),
    isActive: _b(r, 'is_active'),
    createdAt: _d(r, 'created_at'),
    updatedAt: _d(r, 'updated_at'),
  );

  static DbRow toRow(Account a) => {
    'id': a.id,
    'name': a.name,
    'account_type': a.accountType.value,
    'confirmed_balance': a.confirmedBalance,
    'balance_confirmed_at': DateTimeUtils.toIso(a.balanceConfirmedAt),
    'is_active': a.isActive ? 1 : 0,
    'created_at': DateTimeUtils.toIso(a.createdAt),
    'updated_at': DateTimeUtils.toIso(a.updatedAt),
  };
}

class TransactionRow {
  const TransactionRow._();

  static MoneyTransaction fromRow(DbRow r) => MoneyTransaction(
    id: _s(r, 'id'),
    accountId: _s(r, 'account_id'),
    amount: _i(r, 'amount'),
    direction: TransactionDirection.fromValue(_s(r, 'direction')),
    category: _s(r, 'category'),
    note: _sn(r, 'note'),
    transferId: _sn(r, 'transfer_id'),
    billId: _sn(r, 'bill_id'),
    affectsBalance:
        r.containsKey('affects_balance') && _b(r, 'affects_balance'),
    occurredAt: _d(r, 'occurred_at'),
    createdAt: _d(r, 'created_at'),
  );

  static DbRow toRow(MoneyTransaction t) => {
    'id': t.id,
    'account_id': t.accountId,
    'amount': t.amount,
    'direction': t.direction.value,
    'category': t.category,
    'note': blankToNull(t.note),
    'transfer_id': t.transferId,
    'bill_id': t.billId,
    'affects_balance': t.affectsBalance ? 1 : 0,
    'occurred_at': DateTimeUtils.toIso(t.occurredAt),
    'created_at': DateTimeUtils.toIso(t.createdAt),
  };
}

class AdjustmentRow {
  const AdjustmentRow._();

  static BalanceAdjustment fromRow(DbRow r) => BalanceAdjustment(
    id: _s(r, 'id'),
    accountId: _s(r, 'account_id'),
    previousBalance: _i(r, 'previous_balance'),
    correctedBalance: _i(r, 'corrected_balance'),
    reason: _sn(r, 'reason'),
    adjustedAt: _d(r, 'adjusted_at'),
  );
}

class BillRow {
  const BillRow._();

  static Bill fromRow(DbRow r) => Bill(
    id: _s(r, 'id'),
    title: _s(r, 'title'),
    amount: _i(r, 'amount'),
    dueAt: _d(r, 'due_at'),
    status: BillStatus.fromValue(_s(r, 'status')),
    paidAt: _dn(r, 'paid_at'),
    accountId: _sn(r, 'account_id'),
    note: _sn(r, 'note'),
    recurrenceRule: _sn(r, 'recurrence_rule'),
    createdAt: _d(r, 'created_at'),
    updatedAt: _d(r, 'updated_at'),
  );

  static DbRow toRow(Bill b) => {
    'id': b.id,
    'title': b.title,
    'amount': b.amount,
    'due_at': DateTimeUtils.toIso(b.dueAt),
    'status': b.status.value,
    'paid_at': _iso(b.paidAt),
    'account_id': b.accountId,
    'note': blankToNull(b.note),
    'recurrence_rule': blankToNull(b.recurrenceRule),
    'created_at': DateTimeUtils.toIso(b.createdAt),
    'updated_at': DateTimeUtils.toIso(b.updatedAt),
  };
}

class RoutineRow {
  const RoutineRow._();

  static Routine fromRow(DbRow r) {
    final json = _sn(r, 'weekdays_json');
    var weekdays = <int>[];
    if (json != null && json.isNotEmpty) {
      try {
        weekdays = (jsonDecode(json) as List).map((e) => e as int).toList();
      } catch (_) {
        weekdays = <int>[];
      }
    }
    return Routine(
      id: _s(r, 'id'),
      title: _s(r, 'title'),
      description: _s(r, 'description'),
      recurrenceType: RecurrenceType.fromValue(_s(r, 'recurrence_type')),
      intervalDays: _in(r, 'interval_days'),
      weekdays: weekdays,
      preferredTime: _sn(r, 'preferred_time'),
      nextDueAt: _dn(r, 'next_due_at'),
      lastCompletedAt: _dn(r, 'last_completed_at'),
      isActive: _b(r, 'is_active'),
      createdAt: _d(r, 'created_at'),
      updatedAt: _d(r, 'updated_at'),
    );
  }

  static DbRow toRow(Routine m) => {
    'id': m.id,
    'title': m.title,
    'description': m.description,
    'recurrence_type': m.recurrenceType.value,
    'interval_days': m.recurrenceType == RecurrenceType.interval
        ? m.intervalDays
        : null,
    'weekdays_json': m.recurrenceType == RecurrenceType.weekly
        ? jsonEncode(m.weekdays)
        : null,
    'preferred_time': blankToNull(m.preferredTime),
    'next_due_at': _iso(m.nextDueAt),
    'last_completed_at': _iso(m.lastCompletedAt),
    'is_active': m.isActive ? 1 : 0,
    'created_at': DateTimeUtils.toIso(m.createdAt),
    'updated_at': DateTimeUtils.toIso(m.updatedAt),
  };
}

class RoutineLogRow {
  const RoutineLogRow._();

  static RoutineLog fromRow(DbRow r) => RoutineLog(
    id: _s(r, 'id'),
    routineId: _s(r, 'routine_id'),
    completedAt: _d(r, 'completed_at'),
    note: _sn(r, 'note'),
  );
}
