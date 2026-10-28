import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../errors/app_exception.dart';
import 'migrations/migrations.dart';

/// Pembungkus koneksi SQLite. Dibuat sekali dan hidup selama aplikasi.
class AppDatabase {
  AppDatabase._(this.raw);

  final Database raw;

  static const String fileName = 'deck_of_life.db';

  /// Versi skema = jumlah migration.
  static int get schemaVersion => migrations.length;

  /// Membuka (dan bila perlu membuat / memigrasi) database.
  /// [path] null = lokasi database privat aplikasi. Gunakan [inMemoryDatabasePath]
  /// untuk test.
  static Future<AppDatabase> open({String? path}) async {
    try {
      final dbPath = path ?? p.join(await getDatabasesPath(), fileName);
      final db = await openDatabase(
        dbPath,
        version: schemaVersion,
        onConfigure: (db) async {
          // Wajib per koneksi; tanpa ini FOREIGN KEY tidak ditegakkan.
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) => _migrate(db, 0, version),
        onUpgrade: (db, oldVersion, newVersion) =>
            _migrate(db, oldVersion, newVersion),
      );
      return AppDatabase._(db);
    } catch (e, st) {
      AppLog.error('db.open', e, st);
      throw LocalDatabaseException(
        'Database tidak bisa dibuka. Tutup aplikasi lalu coba lagi.',
        e,
      );
    }
  }

  /// Dijalankan di dalam transaksi bawaan sqflite (onCreate/onUpgrade).
  static Future<void> _migrate(Database db, int from, int to) async {
    for (var version = from + 1; version <= to; version++) {
      for (final statement in migrations[version - 1]) {
        await db.execute(statement);
      }
    }
  }

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) =>
      raw.transaction(action);

  Future<void> close() => raw.close();
}

/// Menerjemahkan error sqflite menjadi [LocalDatabaseException] yang aman
/// ditampilkan; error aplikasi (validasi dll.) diteruskan apa adanya.
Future<T> dbGuard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on AppException {
    rethrow;
  } catch (e, st) {
    AppLog.error('db', e, st);
    throw LocalDatabaseException(
      'Data belum tersimpan. Coba lagi; jika berulang, buat backup lalu mulai ulang aplikasi.',
      e,
    );
  }
}
