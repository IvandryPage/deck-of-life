import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';

import '../../../core/calendar/android_calendar_bridge.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/state/data_revision.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';

class AndroidCalendarController extends GetxController {
  AndroidCalendarController({
    required this._settings,
    required this._revision,
    this._bridge = const AndroidCalendarBridge(),
  });

  final SettingsRepository _settings;
  final DataRevision _revision;
  final AndroidCalendarBridge _bridge;

  final RxList<AndroidCalendarInfo> calendars = <AndroidCalendarInfo>[].obs;
  final RxList<String> selectedCalendarIds = <String>[].obs;
  final RxBool hasReadPermission = false.obs;
  final RxBool hasWritePermission = false.obs;
  final RxnString writeCalendarId = RxnString();
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();

  Future<void>? _initializing;

  bool get isConnected =>
      hasReadPermission.value && selectedCalendarIds.isNotEmpty;

  List<AndroidCalendarInfo> get selectedCalendars => calendars
      .where((calendar) => selectedCalendarIds.contains(calendar.id))
      .toList();

  @override
  void onInit() {
    super.onInit();
    unawaited(initialize());
  }

  Future<void> initialize() => _initializing ??= _loadSavedState();

  Future<void> _loadSavedState() async {
    try {
      final raw = await _settings.get(SettingKeys.androidCalendarIds);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          selectedCalendarIds.assignAll(decoded.whereType<String>());
        }
      }
      writeCalendarId.value = await _settings.get(
        SettingKeys.androidCalendarWriteId,
      );
      hasReadPermission.value = await _bridge.hasReadPermission();
      hasWritePermission.value = await _bridge.hasWritePermission();
      if (hasReadPermission.value) {
        calendars.assignAll(await _bridge.calendars());
      }
    } catch (error, stackTrace) {
      AppLog.error('android_calendar.initialize', error, stackTrace);
      errorMessage.value = 'Could not read Android calendars.';
    }
  }

  Future<bool> connect() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      hasReadPermission.value = await _bridge.requestReadPermission();
      if (!hasReadPermission.value) {
        errorMessage.value = 'Calendar read permission was not granted.';
        return false;
      }
      calendars.assignAll(await _bridge.calendars());
      if (selectedCalendarIds.isEmpty) {
        final googleCalendars = calendars
            .where((calendar) => calendar.isGoogleAccount)
            .map((calendar) => calendar.id)
            .toList();
        if (googleCalendars.isNotEmpty) {
          await _saveSelection(googleCalendars);
        }
      }
      _revision.bump();
      return true;
    } catch (error, stackTrace) {
      AppLog.error('android_calendar.connect', error, stackTrace);
      errorMessage.value = 'Could not connect to Android calendars.';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshCalendars() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      hasReadPermission.value = await _bridge.hasReadPermission();
      if (!hasReadPermission.value) {
        errorMessage.value = 'Calendar read permission is not available.';
        return;
      }
      calendars.assignAll(await _bridge.calendars());
    } catch (error, stackTrace) {
      AppLog.error('android_calendar.refresh', error, stackTrace);
      errorMessage.value = 'Could not refresh Android calendars.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> setSelectedCalendars(Iterable<String> ids) async {
    final availableIds = calendars.map((calendar) => calendar.id).toSet();
    final selection = ids.where(availableIds.contains).toSet().toList();
    await _saveSelection(selection);
    _revision.bump();
  }

  Future<bool> setWriteCalendar(String? id) async {
    errorMessage.value = null;
    if (id == null || id.isEmpty) {
      await _settings.remove(SettingKeys.androidCalendarWriteId);
      writeCalendarId.value = null;
      _revision.bump();
      return true;
    }
    AndroidCalendarInfo? calendar;
    for (final item in calendars) {
      if (item.id == id) {
        calendar = item;
        break;
      }
    }
    if (calendar == null || !calendar.isGoogleAccount) {
      errorMessage.value = 'Choose a calendar from a Google account.';
      return false;
    }
    if (!hasWritePermission.value) {
      hasWritePermission.value = await _bridge.requestWritePermission();
    }
    if (!hasWritePermission.value) {
      errorMessage.value = 'Calendar write permission was not granted.';
      return false;
    }
    await _settings.set(SettingKeys.androidCalendarWriteId, id);
    writeCalendarId.value = id;
    _revision.bump();
    return true;
  }

  Future<void> _saveSelection(List<String> ids) async {
    selectedCalendarIds.assignAll(ids);
    await _settings.set(SettingKeys.androidCalendarIds, jsonEncode(ids));
  }

  Future<List<Event>> eventsBetween(DateTime start, DateTime end) async {
    await initialize();
    try {
      hasReadPermission.value = await _bridge.hasReadPermission();
      if (!hasReadPermission.value || selectedCalendarIds.isEmpty) {
        return const [];
      }
      final entries = await _bridge.eventsBetween(
        calendarIds: selectedCalendarIds.toList(),
        start: start,
        end: end,
      );
      final calendarsById = {
        for (final calendar in calendars) calendar.id: calendar,
      };
      return entries.map((entry) {
        final calendar =
            calendarsById[entry.calendarId] ??
            AndroidCalendarInfo(id: entry.calendarId, name: 'Android calendar');
        return entry.toEvent(calendar);
      }).toList();
    } catch (error, stackTrace) {
      AppLog.error('android_calendar.events', error, stackTrace);
      errorMessage.value = 'Could not load Android calendar events.';
      return const [];
    }
  }
}
