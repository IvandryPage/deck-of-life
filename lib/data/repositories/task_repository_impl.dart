import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/errors/app_exception.dart';
import '../../core/search/search_service.dart';
import '../../core/utils/date_time_utils.dart';
import '../../domain/entities/entities.dart';
import '../../domain/entities/enums.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/local/reminder_cleanup.dart';
import '../models/row_mappers.dart';

class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl(this._db);

  final AppDatabase _db;

  static const List<String> _searchColumns = [
    'title',
    'description',
    'course_name',
    'group_name',
    'instruction_source',
    'instruction_location',
    'next_action',
  ];

  @override
  Future<Task> create(Task task, {List<String> savedItemIds = const []}) =>
      dbGuard(() => _db.raw.transaction((txn) async {
            await txn.insert('tasks', TaskRow.toRow(task));
            for (final itemId in savedItemIds) {
              await txn.insert(
                'task_saved_items',
                {'task_id': task.id, 'saved_item_id': itemId},
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
            }
            return task;
          }));

  @override
  Future<Task?> getById(String id) => dbGuard(() async {
        final rows = await _db.raw
            .query('tasks', where: 'id = ?', whereArgs: [id], limit: 1);
        return rows.isEmpty ? null : TaskRow.fromRow(rows.first);
      });

  @override
  Future<NotificationIds> update(Task task) =>
      dbGuard(() => _db.raw.transaction((txn) async {
            final existing = await txn.query(
              'tasks',
              where: 'id = ?',
              whereArgs: [task.id],
              limit: 1,
            );
            if (existing.isEmpty) {
              throw const ValidationException('Task not found.');
            }
            final previous = TaskRow.fromRow(existing.first);
            final now = DateTime.now();

            // completed_at: diisi saat menjadi done, dikosongkan bila dibuka lagi.
            DateTime? completedAt;
            if (task.status == TaskStatus.done) {
              completedAt = previous.status == TaskStatus.done
                  ? (previous.completedAt ?? now)
                  : now;
            }
            final row = TaskRow.toRow(task)
              ..remove('created_at')
              ..['completed_at'] =
                  completedAt == null ? null : DateTimeUtils.toIso(completedAt)
              ..['updated_at'] = DateTimeUtils.toIso(now);
            await txn.update('tasks', row, where: 'id = ?', whereArgs: [task.id]);

            if (!task.status.isActive) {
              return deleteRemindersFor(txn, ReminderTargetType.task, task.id);
            }
            return <int>[];
          }));

  @override
  Future<NotificationIds> setStatus(String id, TaskStatus status) =>
      dbGuard(() => _db.raw.transaction((txn) async {
            final existing = await txn
                .query('tasks', where: 'id = ?', whereArgs: [id], limit: 1);
            if (existing.isEmpty) {
              throw const ValidationException('Task not found.');
            }
            final previous = TaskRow.fromRow(existing.first);
            final now = DateTime.now();
            String? completedAt;
            if (status == TaskStatus.done) {
              completedAt = DateTimeUtils.toIso(
                previous.status == TaskStatus.done
                    ? (previous.completedAt ?? now)
                    : now,
              );
            }
            await txn.update(
              'tasks',
              {
                'status': status.value,
                'completed_at': completedAt,
                'updated_at': DateTimeUtils.toIso(now),
              },
              where: 'id = ?',
              whereArgs: [id],
            );
            if (!status.isActive) {
              return deleteRemindersFor(txn, ReminderTargetType.task, id);
            }
            return <int>[];
          }));

  @override
  Future<NotificationIds> delete(String id) =>
      dbGuard(() => _db.raw.transaction((txn) async {
            final ids =
                await deleteRemindersFor(txn, ReminderTargetType.task, id);
            // task_saved_items ikut terhapus; events.linked_task_id jadi NULL.
            await txn.delete('tasks', where: 'id = ?', whereArgs: [id]);
            return ids;
          }));

  @override
  Future<List<Task>> list({Set<TaskStatus>? statuses}) => dbGuard(() async {
        final where = <String>['archived_at IS NULL'];
        final args = <Object?>[];
        if (statuses != null) {
          if (statuses.isEmpty) return <Task>[];
          where.add('status IN (${List.filled(statuses.length, '?').join(',')})');
          args.addAll(statuses.map((s) => s.value));
        }
        final rows = await _db.raw.query(
          'tasks',
          where: where.join(' AND '),
          whereArgs: args,
          orderBy: 'created_at ASC',
        );
        return rows.map(TaskRow.fromRow).toList();
      });

  @override
  Future<List<Task>> search(String query, {int limit = 50}) =>
      dbGuard(() async {
        final like = SearchService.build(query, _searchColumns);
        final rows = await _db.raw.query(
          'tasks',
          where: '${like.where} AND archived_at IS NULL',
          whereArgs: like.args,
          orderBy: 'updated_at DESC',
          limit: limit,
        );
        return rows.map(TaskRow.fromRow).toList();
      });

  @override
  Future<int> countNeedsReview() => dbGuard(() async {
        final n = Sqflite.firstIntValue(await _db.raw.rawQuery(
          "SELECT COUNT(*) FROM tasks WHERE status = 'needs_review' "
          'AND archived_at IS NULL',
        ));
        return n ?? 0;
      });

  @override
  Future<Task?> createNextOccurrence(Task completed, DateTime nextDue) =>
      dbGuard(() => _db.raw.transaction((txn) async {
            final dueIso = DateTimeUtils.toIso(nextDue);
            final exists = await txn.query(
              'tasks',
              columns: ['id'],
              where: 'title = ? AND due_at = ? AND recurrence_rule IS NOT NULL '
                  "AND status IN ('needs_review','todo','in_progress') "
                  'AND archived_at IS NULL',
              whereArgs: [completed.title, dueIso],
              limit: 1,
            );
            if (exists.isNotEmpty) return null;

            final now = DateTime.now();
            final next = completed.copyWith(
              id: const Uuid().v4(),
              status: TaskStatus.todo,
              dueAt: nextDue,
              createdAt: now,
              updatedAt: now,
              clearCompletedAt: true,
            );
            await txn.insert('tasks', TaskRow.toRow(next));
            // Konteks (instruksi sumber yang terhubung) ikut terbawa.
            await txn.rawInsert(
              'INSERT INTO task_saved_items(task_id, saved_item_id, relation_note) '
              'SELECT ?, saved_item_id, relation_note FROM task_saved_items '
              'WHERE task_id = ?',
              [next.id, completed.id],
            );
            return next;
          }));

  @override
  Future<void> linkSavedItem(
    String taskId,
    String savedItemId, {
    String? note,
  }) =>
      dbGuard(() async {
        await _db.raw.insert(
          'task_saved_items',
          {
            'task_id': taskId,
            'saved_item_id': savedItemId,
            'relation_note': blankToNull(note),
          },
          // Menghubungkan dua kali tidak membuat duplikat.
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      });

  @override
  Future<void> unlinkSavedItem(String taskId, String savedItemId) =>
      dbGuard(() async {
        await _db.raw.delete(
          'task_saved_items',
          where: 'task_id = ? AND saved_item_id = ?',
          whereArgs: [taskId, savedItemId],
        );
      });

  @override
  Future<List<SavedItem>> savedItemsFor(String taskId) => dbGuard(() async {
        final rows = await _db.raw.rawQuery(
          'SELECT s.* FROM saved_items s '
          'JOIN task_saved_items t ON t.saved_item_id = s.id '
          'WHERE t.task_id = ? ORDER BY s.updated_at DESC',
          [taskId],
        );
        return rows.map(SavedItemRow.fromRow).toList();
      });

  @override
  Future<List<Task>> tasksForSavedItem(String savedItemId) =>
      dbGuard(() async {
        final rows = await _db.raw.rawQuery(
          'SELECT k.* FROM tasks k '
          'JOIN task_saved_items t ON t.task_id = k.id '
          'WHERE t.saved_item_id = ? ORDER BY k.updated_at DESC',
          [savedItemId],
        );
        return rows.map(TaskRow.fromRow).toList();
      });
}
