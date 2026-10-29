import '../../core/errors/app_exception.dart';
import '../../core/utils/date_time_utils.dart';
import '../entities/entities.dart';
import '../entities/enums.dart';
import '../repositories/ports.dart';
import '../repositories/repositories.dart';

class ReminderOutcome {
  const ReminderOutcome({required this.scheduled, this.reminder, this.message});

  /// Reminder tersimpan di DB (null bila tidak ada yang disimpan).
  final Reminder? reminder;

  /// True hanya bila notifikasi OS benar-benar terjadwal.
  final bool scheduled;

  /// Penjelasan untuk pengguna bila [scheduled] false.
  final String? message;
}

/// Menyatukan reminder di SQLite dengan penjadwal notifikasi OS (TDD 6.4):
///  1. simpan ke SQLite dulu,
///  2. baru jadwalkan ke OS,
///  3. kegagalan OS tidak menghapus data; hasilnya dilaporkan ke UI.
class ReminderCoordinator {
  ReminderCoordinator({
    required ReminderRepository reminders,
    required NotificationScheduler scheduler,
    required ReminderTargetLookup lookup,
    required SettingsRepository settings,
  }) : _reminders = reminders,
       _scheduler = scheduler,
       _lookup = lookup,
       _settings = settings;

  final ReminderRepository _reminders;
  final NotificationScheduler _scheduler;
  final ReminderTargetLookup _lookup;
  final SettingsRepository _settings;

  /// ID notifikasi 1 dicadangkan untuk pengingat harian "tinjau setelah kerja".
  /// ID reminder per-target dimulai dari 1001 (lihat ReminderRepository).
  static const int postWorkNotificationId = 1;
  static const String defaultPostWorkTime = '18:00';

  Future<ReminderOutcome> setReminder(
    ReminderTargetType type,
    String targetId,
    DateTime remindAt,
  ) async {
    final reminder = await _reminders.upsertForTarget(
      type: type,
      targetId: targetId,
      remindAt: remindAt,
    );
    return _schedule(reminder);
  }

  Future<ReminderOutcome> _schedule(Reminder reminder) async {
    if (!reminder.isEnabled) {
      return ReminderOutcome(reminder: reminder, scheduled: false);
    }
    if (!reminder.remindAt.isAfter(DateTime.now())) {
      return ReminderOutcome(
        reminder: reminder,
        scheduled: false,
        message:
            'This reminder time has passed, so no notification was scheduled.',
      );
    }
    try {
      final title = await _lookup.titleOf(
        reminder.targetType,
        reminder.targetId,
      );
      await _scheduler.schedule(
        id: reminder.notificationId,
        title: _headline(reminder.targetType),
        body: title ?? 'Open Deck of Life',
        at: reminder.remindAt,
      );
      await _reminders.markScheduled(reminder.id, DateTime.now());
      return ReminderOutcome(reminder: reminder, scheduled: true);
    } catch (e, st) {
      AppLog.error('reminder.schedule', e, st);
      return ReminderOutcome(
        reminder: reminder,
        scheduled: false,
        message:
            'Reminder saved, but the notification was not scheduled. '
            'Check notification permissions in Settings.',
      );
    }
  }

  /// Menghapus pengingat suatu target (DB lalu OS).
  Future<void> clearForTarget(ReminderTargetType type, String targetId) async {
    final ids = await _reminders.deleteForTarget(type, targetId);
    await cancelIds(ids);
  }

  /// Membatalkan notifikasi OS (best effort; rekonsiliasi saat start
  /// membersihkan sisa).
  Future<void> cancelIds(Iterable<int> ids) async {
    for (final id in ids) {
      try {
        await _scheduler.cancel(id);
      } catch (e, st) {
        AppLog.error('reminder.cancel', e, st);
      }
    }
  }

  Future<void> setEnabled(Reminder reminder, bool enabled) async {
    await _reminders.setEnabled(reminder.id, enabled);
    if (enabled) {
      await _schedule(
        Reminder(
          id: reminder.id,
          targetType: reminder.targetType,
          targetId: reminder.targetId,
          remindAt: reminder.remindAt,
          repeatRule: reminder.repeatRule,
          notificationId: reminder.notificationId,
          isEnabled: true,
          lastScheduledAt: reminder.lastScheduledAt,
          createdAt: reminder.createdAt,
          updatedAt: reminder.updatedAt,
        ),
      );
    } else {
      await cancelIds([reminder.notificationId]);
    }
  }

  /// Rekonsiliasi saat aplikasi mulai / setelah restore: batalkan semua jadwal OS,
  /// lalu jadwalkan ulang reminder aktif yang belum lewat.
  Future<void> reconcileAll() async {
    try {
      // Baris pengingat yang targetnya sudah selesai/hilang tidak boleh
      // dijadwalkan ulang (mis. setelah restore atau perubahan status).
      await _reminders.pruneOrphans();
    } catch (e, st) {
      AppLog.error('reminder.reconcile.prune', e, st);
    }
    try {
      await _scheduler.cancelAll();
    } catch (e, st) {
      AppLog.error('reminder.reconcile.cancelAll', e, st);
    }
    try {
      for (final reminder in await _reminders.listEnabled()) {
        await _schedule(reminder);
      }
    } catch (e, st) {
      AppLog.error('reminder.reconcile', e, st);
    }
    try {
      await applyPostWorkReview();
    } catch (e, st) {
      AppLog.error('reminder.reconcile.postwork', e, st);
    }
  }

  /// Pengingat harian untuk meninjau daftar tugas setelah bekerja (PRD 7.6).
  Future<void> applyPostWorkReview() async {
    final enabled =
        await _settings.get(SettingKeys.postWorkReviewEnabled) == '1';
    if (!enabled) {
      await _scheduler.cancel(postWorkNotificationId);
      return;
    }
    final time =
        await _settings.get(SettingKeys.postWorkReviewTime) ??
        defaultPostWorkTime;
    final parsed =
        DateTimeUtils.withTime(DateTime.now(), time) ??
        DateTimeUtils.withTime(DateTime.now(), defaultPostWorkTime)!;
    try {
      await _scheduler.scheduleDaily(
        id: postWorkNotificationId,
        title: 'Review tasks',
        body: 'Review your schedule, deadlines, and notes that need attention.',
        hour: parsed.hour,
        minute: parsed.minute,
      );
    } catch (e) {
      throw NotificationSchedulingException(
        'Could not schedule the daily reminder. Check notification permissions.',
        e,
      );
    }
  }

  static String _headline(ReminderTargetType type) => switch (type) {
    ReminderTargetType.task => 'Task deadline',
    ReminderTargetType.event => 'Event',
    ReminderTargetType.bill => 'Bill',
    ReminderTargetType.routine => 'Routine',
    ReminderTargetType.savedItem => 'Review note',
  };
}
