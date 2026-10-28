import 'package:sqflite/sqflite.dart';

import '../../../domain/entities/enums.dart';
import '../../../domain/repositories/repositories.dart';

/// Menghapus baris `reminders` milik sebuah target di dalam transaksi pemanggil
/// dan mengembalikan ID notifikasi OS yang harus dibatalkan. `reminders.target_id`
/// tidak memakai foreign key polimorfik, jadi pembersihan wajib dilakukan di sini
/// (TDD bagian 5).
Future<NotificationIds> deleteRemindersFor(
  DatabaseExecutor db,
  ReminderTargetType type,
  String targetId,
) async {
  final rows = await db.query(
    'reminders',
    columns: ['notification_id'],
    where: 'target_type = ? AND target_id = ?',
    whereArgs: [type.value, targetId],
  );
  final ids = rows.map((r) => r['notification_id'] as int).toList();
  if (ids.isNotEmpty) {
    await db.delete(
      'reminders',
      where: 'target_type = ? AND target_id = ?',
      whereArgs: [type.value, targetId],
    );
  }
  return ids;
}
