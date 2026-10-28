import 'dart:developer' as developer;

/// Basis semua error aplikasi. [message] aman ditampilkan ke pengguna;
/// [cause] hanya untuk debug dan tidak pernah ditampilkan.
class AppException implements Exception {
  const AppException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Dinamai `LocalDatabaseException` (bukan `DatabaseException` seperti di TDD)
/// agar tidak bentrok dengan `DatabaseException` milik sqflite.
class LocalDatabaseException extends AppException {
  const LocalDatabaseException(super.message, [super.cause]);
}

class ValidationException extends AppException {
  const ValidationException(super.message, [super.cause]);
}

class NotificationSchedulingException extends AppException {
  const NotificationSchedulingException(super.message, [super.cause]);
}

class BackupFormatException extends AppException {
  const BackupFormatException(super.message, [super.cause]);
}

class ImportValidationException extends AppException {
  const ImportValidationException(super.message, [super.cause]);
}

class SharePayloadException extends AppException {
  const SharePayloadException(super.message, [super.cause]);
}

/// Log debug tanpa isi pribadi: hanya tag dan tipe error, tidak pernah
/// pesan/catatan/nominal pengguna (TDD bagian 14-15). Senyap di build rilis.
/// Tidak memakai `package:flutter` agar lapisan domain tetap murni Dart.
class AppLog {
  const AppLog._();

  static const bool _isRelease = bool.fromEnvironment('dart.vm.product');

  static void error(String tag, Object error, [StackTrace? stackTrace]) {
    if (_isRelease) return;
    developer.log(
      error.runtimeType.toString(),
      name: tag,
      stackTrace: stackTrace,
    );
  }
}
