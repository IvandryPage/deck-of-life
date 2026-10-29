import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/date_time_utils.dart';
import '../../domain/entities/entities.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/logic.dart';
import '../../domain/entities/recurrence.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/local/reminder_cleanup.dart';
import '../models/row_mappers.dart';

class RoutineRepositoryImpl implements RoutineRepository {
  RoutineRepositoryImpl(this._db);

  final AppDatabase _db;
  static const Uuid _uuid = Uuid();

  @override
  Future<Routine> create(Routine routine) => dbGuard(() async {
    await _db.raw.insert('routines', RoutineRow.toRow(routine));
    return routine;
  });

  @override
  Future<Routine?> getById(String id) => dbGuard(() async {
    final rows = await _db.raw.query(
      'routines',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : RoutineRow.fromRow(rows.first);
  });

  @override
  Future<void> update(Routine routine) => dbGuard(() async {
    final row = RoutineRow.toRow(routine)
      ..remove('created_at')
      ..['updated_at'] = DateTimeUtils.nowIso();
    await _db.raw.update(
      'routines',
      row,
      where: 'id = ?',
      whereArgs: [routine.id],
    );
  });

  @override
  Future<NotificationIds> delete(String id) => dbGuard(
    () => _db.raw.transaction((txn) async {
      final ids = await deleteRemindersFor(txn, ReminderTargetType.routine, id);
      // routine_logs ikut terhapus (ON DELETE CASCADE).
      await txn.delete('routines', where: 'id = ?', whereArgs: [id]);
      return ids;
    }),
  );

  @override
  Future<List<Routine>> list({bool activeOnly = false}) => dbGuard(() async {
    final rows = await _db.raw.query(
      'routines',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'created_at ASC',
    );
    return rows.map(RoutineRow.fromRow).toList();
  });

  @override
  Future<void> migrateToRecurringTasks() => dbGuard(() async {
    await _db.raw.transaction((txn) async {
      final rows = await txn.query(
        'routines',
        where: 'migrated_task_id IS NULL',
        orderBy: 'created_at ASC',
      );
      for (final row in rows) {
        final routine = RoutineRow.fromRow(row);
        final rule = switch (routine.recurrenceType) {
          RecurrenceType.daily => const RecurrenceRule(RecurrenceKind.daily),
          RecurrenceType.interval
              when routine.intervalDays != null && routine.intervalDays! > 0 =>
            RecurrenceRule(
              RecurrenceKind.interval,
              intervalDays: routine.intervalDays,
            ),
          RecurrenceType.weekly => RecurrenceRule(
            RecurrenceKind.weekdays,
            weekdays:
                routine.weekdays
                    .where((day) => day >= 1 && day <= 7)
                    .toSet()
                    .toList()
                  ..sort(),
          ),
          _ => null,
        };
        if (rule == null ||
            (rule.kind == RecurrenceKind.weekdays && rule.weekdays.isEmpty)) {
          throw const ValidationException(
            'Aturan pengulangan rutinitas lama tidak valid.',
          );
        }

        final now = DateTime.now();
        final due =
            routine.nextDueAt ??
            (routine.isActive ? RoutineScheduler.firstDue(routine, now) : null);
        if (routine.isActive && due == null) {
          throw const ValidationException(
            'Jadwal rutinitas lama tidak dapat dipindahkan ke Tasks.',
          );
        }
        final task = Task(
          id: _uuid.v4(),
          title: routine.title,
          description: routine.description,
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          dueAt: due,
          createdAt: routine.createdAt,
          updatedAt: routine.updatedAt,
          archivedAt: routine.isActive ? null : routine.updatedAt,
          recurrenceRule: rule.encoded,
        );
        await txn.insert('tasks', TaskRow.toRow(task));
        await txn.update(
          'reminders',
          {'target_type': ReminderTargetType.task.value, 'target_id': task.id},
          where: 'target_type = ? AND target_id = ?',
          whereArgs: [ReminderTargetType.routine.value, routine.id],
        );
        await txn.update(
          'routines',
          {'migrated_task_id': task.id},
          where: 'id = ?',
          whereArgs: [routine.id],
        );
      }
    });
  });

  @override
  Future<List<RoutineLog>> logsForTask(String taskId, {int limit = 20}) =>
      dbGuard(() async {
        final rows = await _db.raw.rawQuery(
          '''
          SELECT logs.*
          FROM routine_logs logs
          JOIN routines r ON r.id = logs.routine_id
          WHERE r.migrated_task_id = ?
          ORDER BY logs.completed_at DESC
          LIMIT ?
          ''',
          [taskId, limit],
        );
        return rows.map(RoutineLogRow.fromRow).toList();
      });

  @override
  Future<Routine> complete(String id, DateTime completedAt, {String? note}) =>
      dbGuard(
        () => _db.raw.transaction((txn) async {
          final rows = await txn.query(
            'routines',
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );
          if (rows.isEmpty) {
            throw const ValidationException('Rutinitas tidak ditemukan.');
          }
          final routine = RoutineRow.fromRow(rows.first);
          final next = RoutineScheduler.nextDue(routine, completedAt);
          final doneIso = DateTimeUtils.toIso(completedAt);

          await txn.insert('routine_logs', {
            'id': _uuid.v4(),
            'routine_id': id,
            'completed_at': doneIso,
            'note': blankToNull(note),
          });
          await txn.update(
            'routines',
            {
              'last_completed_at': doneIso,
              'next_due_at': next == null ? null : DateTimeUtils.toIso(next),
              'updated_at': DateTimeUtils.nowIso(),
            },
            where: 'id = ?',
            whereArgs: [id],
          );
          final fresh = await txn.query(
            'routines',
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );
          return RoutineRow.fromRow(fresh.first);
        }),
      );

  @override
  Future<List<RoutineLog>> logs(String routineId, {int limit = 20}) =>
      dbGuard(() async {
        final rows = await _db.raw.query(
          'routine_logs',
          where: 'routine_id = ?',
          whereArgs: [routineId],
          orderBy: 'completed_at DESC',
          limit: limit,
        );
        return rows.map(RoutineLogRow.fromRow).toList();
      });
}
