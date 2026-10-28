import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/repositories/ports.dart';
import '../errors/app_exception.dart';

/// Adapter `flutter_local_notifications` untuk [NotificationScheduler].
///
/// Sengaja memakai penjadwalan TIDAK exact (`inexactAllowWhileIdle`): tidak
/// butuh izin alarm exact, dan Android memang tidak menjamin notifikasi tepat
/// detik (TDD 6.4). UI tidak boleh menjanjikan ketepatan waktu.
class LocalNotificationService implements NotificationScheduler {
  LocalNotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'reminders',
    'Pengingat',
    channelDescription: 'Deadline, agenda, tagihan, rutinitas, dan tinjauan',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    icon: 'ic_stat_notify',
  );
  static const NotificationDetails _details =
      NotificationDetails(android: _androidDetails);

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(_resolveLocalLocation());
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_notify'),
    );
    await _plugin.initialize(settings);
    _ready = true;
  }

  /// Mencari zona waktu yang offset-nya sama dengan perangkat. Tanpa paket
  /// tambahan untuk nama zona; cukup untuk jadwal sekali jalan (instan absolut),
  /// dan wilayah tanpa DST seperti Indonesia untuk jadwal harian.
  static tz.Location _resolveLocalLocation() {
    final offset = DateTime.now().timeZoneOffset;
    bool matches(tz.Location l) => tz.TZDateTime.now(l).timeZoneOffset == offset;

    for (final name in const [
      'Asia/Jakarta',
      'Asia/Makassar',
      'Asia/Jayapura',
    ]) {
      final l = tz.getLocation(name);
      if (matches(l)) return l;
    }
    for (final l in tz.timeZoneDatabase.locations.values) {
      if (matches(l)) return l;
    }
    return tz.UTC;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> areNotificationsEnabled() async {
    await init();
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    await init();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    try {
      await init();
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(at, tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      throw NotificationSchedulingException(
        'Notifikasi tidak bisa dijadwalkan.',
        e,
      );
    }
  }

  @override
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    try {
      await init();
      final now = DateTime.now();
      var next = DateTime(now.year, now.month, now.day, hour, minute);
      if (!next.isAfter(now)) {
        next = DateTime(now.year, now.month, now.day + 1, hour, minute);
      }
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(next, tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      throw NotificationSchedulingException(
        'Pengingat harian tidak bisa dijadwalkan.',
        e,
      );
    }
  }

  @override
  Future<void> cancel(int id) async {
    await init();
    await _plugin.cancel(id);
  }

  @override
  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}
