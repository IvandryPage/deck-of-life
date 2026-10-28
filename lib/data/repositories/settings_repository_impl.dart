import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/date_time_utils.dart';
import '../../domain/repositories/repositories.dart';

/// Pengaturan kecil berbentuk key-value di tabel `app_settings`
/// (ikut ter-backup, tidak perlu SharedPreferences).
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<String?> get(String key) => dbGuard(() async {
        final rows = await _db.raw.query(
          'app_settings',
          columns: ['value'],
          where: 'key = ?',
          whereArgs: [key],
          limit: 1,
        );
        return rows.isEmpty ? null : rows.first['value'] as String;
      });

  @override
  Future<void> set(String key, String value) => dbGuard(() async {
        await _db.raw.insert(
          'app_settings',
          {'key': key, 'value': value, 'updated_at': DateTimeUtils.nowIso()},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });

  @override
  Future<void> remove(String key) => dbGuard(() async {
        await _db.raw
            .delete('app_settings', where: 'key = ?', whereArgs: [key]);
      });
}
