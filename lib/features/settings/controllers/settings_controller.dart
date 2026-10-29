import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/backup/backup_service.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/state/data_revision.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/repositories/ports.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/reminder_coordinator.dart';

class SettingsController extends GetxController {
  SettingsController(
    this._settings,
    this._scheduler,
    this._coordinator,
    this._backup,
    this._revision,
  );

  final SettingsRepository _settings;
  final NotificationScheduler _scheduler;
  final ReminderCoordinator _coordinator;
  final BackupService _backup;
  final DataRevision _revision;

  final RxBool notificationsEnabled = false.obs;
  final RxBool postWorkEnabled = false.obs;
  final RxString postWorkTime = ReminderCoordinator.defaultPostWorkTime.obs;
  final RxBool busy = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      notificationsEnabled.value = await _scheduler.areNotificationsEnabled();
      postWorkEnabled.value =
          await _settings.get(SettingKeys.postWorkReviewEnabled) == '1';
      postWorkTime.value = await _settings.get(SettingKeys.postWorkReviewTime) ??
          ReminderCoordinator.defaultPostWorkTime;
    } catch (e, st) {
      AppLog.error('settings.load', e, st);
    }
  }

  /// Izin diminta hanya setelah pengguna menekan tombol ini, bukan saat start.
  Future<void> requestNotificationPermission() async {
    try {
      final ok = await _scheduler.requestPermission();
      notificationsEnabled.value = ok;
      if (ok) {
        await _coordinator.reconcileAll();
        AppToast.show('Notifications are on');
      } else {
        AppToast.show(
          'Permission denied. Enable notifications in System settings > Apps > Deck of Life.',
          isError: true,
        );
      }
    } catch (e, st) {
      AppLog.error('settings.permission', e, st);
      AppToast.show('Could not request notification permission.', isError: true);
    }
  }

  Future<void> setPostWork(bool enabled) async {
    try {
      if (enabled && !notificationsEnabled.value) {
        await requestNotificationPermission();
        if (!notificationsEnabled.value) return;
      }
      await _settings.set(SettingKeys.postWorkReviewEnabled, enabled ? '1' : '0');
      postWorkEnabled.value = enabled;
      await _coordinator.applyPostWorkReview();
    } catch (e, st) {
      AppLog.error('settings.postwork', e, st);
      AppToast.show(messageOf(e), isError: true);
    }
  }

  Future<void> setPostWorkTime(String hhmm) async {
    try {
      await _settings.set(SettingKeys.postWorkReviewTime, hhmm);
      postWorkTime.value = hhmm;
      if (postWorkEnabled.value) await _coordinator.applyPostWorkReview();
    } catch (e, st) {
      AppLog.error('settings.postwork.time', e, st);
      AppToast.show(messageOf(e), isError: true);
    }
  }

  // ---- Backup -----------------------------------------------------------------

  Future<void> exportBackup() async {
    if (busy.value) return;
    busy.value = true;
    try {
      final file = await _backup.exportToTempFile();
      // Berkas sengaja tidak dihapus sesudah berbagi: Android tidak memberi tahu
      // kapan aplikasi tujuan selesai membaca. Berada di cache aplikasi (privat).
      final shared = await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Backup Deck of Life',
        text: 'Backup Deck of Life',
      ));
      // Hanya dicatat bila pengguna benar-benar memilih tujuan (bukan batal).
      if (shared.status != ShareResultStatus.dismissed) {
        await _settings.set(
            SettingKeys.lastBackupAt, DateTime.now().toIso8601String());
        _revision.bump();
      }
    } catch (e, st) {
      AppLog.error('settings.export', e, st);
      AppToast.show(messageOf(e), isError: true);
    } finally {
      busy.value = false;
    }
  }

  /// Alur: pilih berkas -> validasi (belum mengubah apa pun) -> konfirmasi
  /// eksplisit -> backup pengaman otomatis -> replace-all atomik.
  Future<void> restoreBackup(BuildContext context) async {
    if (busy.value) return;
    busy.value = true;
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.any);
      final path = picked?.files.single.path;
      if (path == null) return;

      final text = await File(path).readAsString();
      final parsed = _backup.inspect(text); // melempar bila tidak valid

      if (!context.mounted) return;
      final exported = parsed.exportedAt == null
          ? 'unknown'
          : DateTimeUtils.tryParse(parsed.exportedAt) != null
              ? parsed.exportedAt!.split('T').first
              : parsed.exportedAt!;
      final ok = await confirmDialog(
        context,
        title: 'Replace all data with this backup?',
        message: 'Backup dated $exported contains '
            '${parsed.countOf('saved_items')} notes, '
            '${parsed.countOf('tasks')} tasks, ${parsed.countOf('events')} events, '
            '${parsed.countOf('bills')} bills, and ${parsed.countOf('routines')} routines.\n\n'
            'All current app data will be replaced. A safety backup of your current data will be created first.',
        confirmLabel: 'Replace data',
        destructive: true,
      );
      if (!ok) return;

      final result = await _backup.restore(text);
      _revision.bump();
      AppToast.show(
        'Restored ${result.restoredRows} records. The safety backup of your previous data is stored in the app.',
      );
    } catch (e, st) {
      AppLog.error('settings.restore', e, st);
      AppToast.show(messageOf(e), isError: true);
    } finally {
      busy.value = false;
    }
  }
}
