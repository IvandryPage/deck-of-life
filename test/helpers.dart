import 'package:deck_of_life/domain/entities/entities.dart';
import 'package:deck_of_life/domain/entities/enums.dart';

final DateTime t0 = DateTime(2026, 10, 1, 8);

Account makeAccount(
  String id,
  int balance, {
  bool active = true,
  DateTime? confirmedAt,
}) =>
    Account(
      id: id,
      name: 'Akun $id',
      accountType: AccountType.bank,
      confirmedBalance: balance,
      balanceConfirmedAt: confirmedAt ?? t0,
      isActive: active,
      createdAt: t0,
      updatedAt: t0,
    );

Bill makeBill(
  String id,
  int amount, {
  BillStatus status = BillStatus.unpaid,
  DateTime? due,
}) =>
    Bill(
      id: id,
      title: 'Tagihan $id',
      amount: amount,
      dueAt: due ?? DateTime(2026, 11, 5),
      status: status,
      createdAt: t0,
      updatedAt: t0,
    );

Task makeTask(
  String id, {
  String? title,
  DateTime? due,
  TaskStatus status = TaskStatus.todo,
  TaskPriority priority = TaskPriority.normal,
  DateTime? createdAt,
}) =>
    Task(
      id: id,
      title: title ?? 'Tugas $id',
      status: status,
      priority: priority,
      dueAt: due,
      createdAt: createdAt ?? t0,
      updatedAt: t0,
    );

SavedItem makeItem(
  String id, {
  String? title,
  String content = '',
  SavedItemType type = SavedItemType.note,
  String? course,
  String? group,
  String? url,
  ReviewStatus review = ReviewStatus.needsReview,
  DateTime? at,
}) =>
    SavedItem(
      id: id,
      title: title ?? 'Item $id',
      contentText: content,
      itemType: type,
      courseName: course,
      groupName: group,
      sourceUrl: url,
      reviewStatus: review,
      createdAt: at ?? t0,
      updatedAt: at ?? t0,
    );

Routine makeRoutine(
  RecurrenceType type, {
  int? interval,
  List<int> weekdays = const [],
  String? time,
}) =>
    Routine(
      id: 'r1',
      title: 'Rutinitas',
      recurrenceType: type,
      intervalDays: interval,
      weekdays: weekdays,
      preferredTime: time,
      createdAt: t0,
      updatedAt: t0,
    );
