import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../errors/app_exception.dart';
import '../utils/app_info.dart';
import '../utils/date_time_utils.dart';
import 'backup_validator.dart';

class RestoreResult {
  const RestoreResult({required this.restoredRows, required this.safetyBackupPath});

  final int restoredRows;

  /// Backup otomatis dari data SEBELUM restore, untuk jaga-jaga salah pilih berkas.
  final String safetyBackupPath;
}

/// Backup & restore JSON (TDD bagian 12).
///  - Ekspor: satu berkas JSON UTF-8 berisi seluruh tabel + checksum.
///  - Restore: validasi penuh dulu, backup otomatis data aktif, lalu mode
///    "replace all" dalam SATU transaksi (gagal di tengah = rollback total).
/// Backup TIDAK mencakup berkas eksternal yang hanya direferensikan lewat URL/URI.
class BackupService {
  BackupService(
    this._db, {
    Future<void> Function()? onRestored,
    Future<Directory> Function()? backupDirectory,
  })  : _onRestored = onRestored,
        _backupDirectory = backupDirectory ?? getApplicationDocumentsDirectory;

  final AppDatabase _db;
  final Future<void> Function()? _onRestored;

  /// Lokasi folder `backups/` pengaman. Bisa diganti untuk pengujian.
  final Future<Directory> Function() _backupDirectory;

  static const int _keepSafetyBackups = 5;

  /// Isi backup (Map siap di-encode ke JSON).
  Future<Map<String, Object?>> buildBackup() async {
    final data = <String, Object?>{};
    for (final table in BackupSchema.tables) {
      final rows = await _db.raw.query(table);
      data[table] = rows.map((r) => Map<String, Object?>.from(r)).toList();
    }
    return {
      'format': BackupSchema.formatId,
      'schema_version': AppDatabase.schemaVersion,
      'app_version': AppInfo.version,
      'exported_at': DateTimeUtils.nowIso(),
      'checksum': BackupSchema.checksumOf(data),
      'data': data,
    };
  }

  String _encode(Map<String, Object?> backup) =>
      const JsonEncoder.withIndent('  ').convert(backup);

  /// Menulis backup ke direktori sementara untuk dibagikan. Pemanggil sebaiknya
  /// memanggil [deleteExport] setelah selesai karena berkas berisi data pribadi.
  Future<File> exportToTempFile() async {
    try {
      final backup = await buildBackup();
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, _fileName('deck-of-life')));
      await file.writeAsString(_encode(backup), flush: true);
      return file;
    } on AppException {
      rethrow;
    } catch (e, st) {
      AppLog.error('backup.export', e, st);
      throw LocalDatabaseException('Backup gagal dibuat. Coba lagi.', e);
    }
  }

  Future<void> deleteExport(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (e, st) {
      AppLog.error('backup.cleanup', e, st);
    }
  }

  /// Memeriksa teks backup tanpa mengubah apa pun (untuk pratinjau sebelum restore).
  ParsedBackup inspect(String jsonText) => BackupValidator.parse(
        jsonText,
        currentSchemaVersion: AppDatabase.schemaVersion,
      );

  /// Mengganti SELURUH data aktif dengan isi backup.
  /// Pemanggil wajib sudah meminta konfirmasi eksplisit pengguna.
  Future<RestoreResult> restore(String jsonText) async {
    // 1. Validasi penuh. Gagal di sini = tidak ada yang berubah.
    final parsed = inspect(jsonText);

    // 2. Backup otomatis data aktif, lalu pastikan bisa dibaca kembali.
    final safety = await _writeSafetyBackup();

    // 3. Replace-all atomik.
    try {
      await _db.raw.transaction((txn) async {
        for (final table in BackupSchema.tables.reversed) {
          await txn.delete(table);
        }
        for (final table in BackupSchema.tables) {
          for (final row in parsed.data[table]!) {
            await txn.insert(table, row);
          }
        }
      });
    } on DatabaseException catch (e, st) {
      AppLog.error('backup.restore', e, st);
      throw ImportValidationException(
        'Restore dibatalkan karena ada data yang tidak valid. '
        'Data Anda saat ini tidak berubah.',
        e,
      );
    }

    await _onRestored?.call();
    return RestoreResult(
      restoredRows: parsed.totalRows,
      safetyBackupPath: safety.path,
    );
  }

  Future<File> _writeSafetyBackup() async {
    try {
      final backup = await buildBackup();
      final text = _encode(backup);
      final docs = await _backupDirectory();
      final dir = Directory(p.join(docs.path, 'backups'));
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, _fileName('pre-restore')));
      await file.writeAsString(text, flush: true);

      // Verifikasi: berkas harus bisa divalidasi ulang sebelum data lama ditimpa.
      BackupValidator.parse(
        await file.readAsString(),
        currentSchemaVersion: AppDatabase.schemaVersion,
      );
      await _pruneSafetyBackups(dir);
      return file;
    } on AppException {
      rethrow;
    } catch (e, st) {
      AppLog.error('backup.safety', e, st);
      throw LocalDatabaseException(
        'Backup pengaman gagal dibuat, jadi restore dibatalkan. '
        'Periksa ruang penyimpanan lalu coba lagi.',
        e,
      );
    }
  }

  Future<void> _pruneSafetyBackups(Directory dir) async {
    final files = await dir
        .list()
        .where((e) => e is File && e.path.contains('pre-restore-'))
        .cast<File>()
        .toList();
    if (files.length <= _keepSafetyBackups) return;
    files.sort((a, b) => a.path.compareTo(b.path)); // nama memuat timestamp
    for (final f in files.take(files.length - _keepSafetyBackups)) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  static String _fileName(String prefix) {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '$prefix-${n.year}${two(n.month)}${two(n.day)}-'
        '${two(n.hour)}${two(n.minute)}${two(n.second)}.dol-backup.json';
  }
}
