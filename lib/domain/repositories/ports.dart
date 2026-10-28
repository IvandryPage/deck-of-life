import '../entities/enums.dart';

/// Port ke penjadwal notifikasi OS. Implementasi: `core/notifications`.
abstract interface class NotificationScheduler {
  Future<bool> areNotificationsEnabled();
  Future<bool> requestPermission();

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  });

  /// Pengingat harian berulang pada jam tertentu.
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  });

  Future<void> cancel(int id);
  Future<void> cancelAll();
}

/// Mencari judul target pengingat untuk isi notifikasi.
abstract interface class ReminderTargetLookup {
  Future<String?> titleOf(ReminderTargetType type, String targetId);
}
