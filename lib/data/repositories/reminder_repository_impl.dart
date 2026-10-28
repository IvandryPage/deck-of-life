import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/date_time_utils.dart';
import '../../domain/entities/entities.dart';
import '../../domain/entities/enums.dart';
import '../../domain/repositories/ports.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/local/reminder_cleanup.dart';
import '../models/row_mappers.dart';

class ReminderRepositoryImpl implements ReminderRepository {
  ReminderRepositoryImpl(this._db);

  final AppDatabase _db;
  static const Uuid _uuid = Uuid();

  /// ID notifikasi per-target dimulai dari sini; 1 dicadangkan untuk pengingat
  /// harian "tinjau setelah kerja". ID bersifat stabil (disimpan di DB) dan unik.
  static const int firstNotificationId = 1001;

  @override
  Future<Reminder> upsertForTarget({
    required ReminderTargetType type,
    required String targetId,
    required DateTime remindAt,
  }) =>
      dbGuard(() => _db.raw.transaction((txn) async {
            final nowIso = DateTimeUtils.nowIso();
            final existing = await txn.query(
              'reminders',
              where: 'target_type = ? AND target_id = ?',
              whereArgs: [type.value, targetId],
              limit: 1,
            );
            if (existing.isNotEmpty) {
              final id = existing.first['id'] as String;
              await txn.update(
                'reminders',
                {
                  'remind_at': DateTimeUtils.toIso(remindAt),
                  'is_enabled': 1,
                  'last_scheduled_at': null,
                  'updated_at': nowIso,
                },
                where: 'id = ?',
                whereArgs: [id],
              );
              final fresh = await txn
                  .query('reminders', where: 'id = ?', whereArgs: [id]);
              return ReminderRow.fromRow(fresh.first);
            }
            final maxRow = await txn.rawQuery(
              'SELECT COALESCE(MAX(notification_id), ${firstNotificationId - 1}) AS m '
              'FROM reminders',
            );
            final notificationId = (maxRow.first['m'] as int) + 1;
            final reminder = Reminder(
              id: _uuid.v4(),
              targetType: type,
              targetId: targetId,
              remindAt: remindAt,
              notificationId: notificationId,
              createdAt: DateTimeUtils.parse(nowIso),
              updatedAt: DateTimeUtils.parse(nowIso),
            );
            await txn.insert('reminders', ReminderRow.toRow(reminder));
            return reminder;
          }));

  @override
  Future<Reminder?> getForTarget(ReminderTargetType type, String targetId) =>
      dbGuard(() async {
        final rows = await _db.raw.query(
          'reminders',
          where: 'target_type = ? AND target_id = ?',
          whereArgs: [type.value, targetId],
          limit: 1,
        );
        return rows.isEmpty ? null : ReminderRow.fromRow(rows.first);
      });

  @override
  Future<List<Reminder>> listEnabled() => dbGuard(() async {
        final rows = await _db.raw.query(
          'reminders',
          where: 'is_enabled = 1',
          orderBy: 'remind_at ASC',
        );
        return rows.map(ReminderRow.fromRow).toList();
      });

  @override
  Future<NotificationIds> pruneOrphans() =>
      dbGuard(() => _db.raw.transaction((txn) async {
            // Satu kondisi dipakai untuk memilih ID notifikasi DAN menghapus,
            // sehingga keduanya selalu konsisten.
            const orphan = '''
(target_type = 'task' AND target_id NOT IN (
   SELECT id FROM tasks
   WHERE status IN ('needs_review','todo','in_progress') AND archived_at IS NULL))
OR (target_type = 'event' AND target_id NOT IN (SELECT id FROM events))
OR (target_type = 'bill' AND target_id NOT IN (
   SELECT id FROM bills WHERE status = 'unpaid'))
OR (target_type = 'routine' AND target_id NOT IN (
   SELECT id FROM routines WHERE is_active = 1))
OR (target_type = 'saved_item' AND target_id NOT IN (
   SELECT id FROM saved_items WHERE review_status = 'needs_review'))''';
            final rows = await txn
                .rawQuery('SELECT notification_id FROM reminders WHERE $orphan');
            if (rows.isEmpty) return <int>[];
            await txn.delete('reminders', where: orphan);
            return rows.map((r) => r['notification_id'] as int).toList();
          }));

  @override
  Future<void> markScheduled(String id, DateTime at) => dbGuard(() async {
        await _db.raw.update(
          'reminders',
          {'last_scheduled_at': DateTimeUtils.toIso(at)},
          where: 'id = ?',
          whereArgs: [id],
        );
      });

  @override
  Future<void> setEnabled(String id, bool enabled) => dbGuard(() async {
        await _db.raw.update(
          'reminders',
          {
            'is_enabled': enabled ? 1 : 0,
            if (!enabled) 'last_scheduled_at': null,
            'updated_at': DateTimeUtils.nowIso(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      });

  @override
  Future<NotificationIds> deleteForTarget(
    ReminderTargetType type,
    String targetId,
  ) =>
      dbGuard(() => _db.raw.transaction(
            (txn) => deleteRemindersFor(txn, type, targetId),
          ));
}

/// Mencari judul target untuk isi notifikasi.
class ReminderTargetLookupImpl implements ReminderTargetLookup {
  ReminderTargetLookupImpl(this._db);

  final AppDatabase _db;

  @override
  Future<String?> titleOf(ReminderTargetType type, String targetId) async {
    final table = switch (type) {
      ReminderTargetType.task => 'tasks',
      ReminderTargetType.event => 'events',
      ReminderTargetType.bill => 'bills',
      ReminderTargetType.routine => 'routines',
      ReminderTargetType.savedItem => 'saved_items',
    };
    final rows = await _db.raw.query(
      table,
      columns: ['title'],
      where: 'id = ?',
      whereArgs: [targetId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['title'] as String?;
  }
}
