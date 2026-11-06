import 'package:flutter/services.dart';

import '../../domain/entities/entities.dart';

class AndroidCalendarInfo {
  const AndroidCalendarInfo({
    required this.id,
    required this.name,
    this.accountName,
    this.accountType,
    this.color,
  });

  final String id;
  final String name;
  final String? accountName;
  final String? accountType;
  final int? color;

  bool get isGoogleAccount =>
      (accountType ?? '').toLowerCase().contains('google');

  String get label => accountName == null || accountName!.isEmpty
      ? name
      : '$name · $accountName';

  factory AndroidCalendarInfo.fromMap(Map<dynamic, dynamic> map) =>
      AndroidCalendarInfo(
        id: map['id'] as String,
        name: map['name'] as String? ?? 'Calendar',
        accountName: map['accountName'] as String?,
        accountType: map['accountType'] as String?,
        color: (map['color'] as num?)?.toInt(),
      );
}

class AndroidCalendarEntry {
  const AndroidCalendarEntry({
    required this.id,
    required this.calendarId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.isAllDay,
    this.location,
  });

  final String id;
  final String calendarId;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isAllDay;
  final String? location;

  Event toEvent(AndroidCalendarInfo calendar) => Event(
    id: 'android-calendar:$calendarId:$id:${startsAt.millisecondsSinceEpoch}',
    title: title,
    startsAt: startsAt,
    endsAt: endsAt,
    location: location,
    externalCalendarName: calendar.name,
    isAllDay: isAllDay,
    createdAt: startsAt,
    updatedAt: startsAt,
  );

  factory AndroidCalendarEntry.fromMap(Map<dynamic, dynamic> map) =>
      AndroidCalendarEntry(
        id: map['id'] as String,
        calendarId: map['calendarId'] as String,
        title: map['title'] as String? ?? 'Untitled event',
        startsAt: DateTime.fromMillisecondsSinceEpoch(
          (map['startMillis'] as num).toInt(),
        ),
        endsAt: DateTime.fromMillisecondsSinceEpoch(
          (map['endMillis'] as num).toInt(),
        ),
        isAllDay: map['allDay'] == true,
        location: map['location'] as String?,
      );
}

class AndroidCalendarBridge {
  const AndroidCalendarBridge({
    this.channel = const MethodChannel('deck_of_life/android_calendar'),
  });

  final MethodChannel channel;

  Future<bool> hasReadPermission() async =>
      await channel.invokeMethod<bool>('hasCalendarReadPermission') ?? false;

  Future<bool> requestReadPermission() async =>
      await channel.invokeMethod<bool>('requestCalendarReadPermission') ??
      false;

  Future<List<AndroidCalendarInfo>> calendars() async {
    final rows =
        await channel.invokeListMethod<dynamic>('getDeviceCalendars') ??
        const [];
    return rows.whereType<Map>().map(AndroidCalendarInfo.fromMap).toList();
  }

  Future<List<AndroidCalendarEntry>> eventsBetween({
    required List<String> calendarIds,
    required DateTime start,
    required DateTime end,
  }) async {
    if (calendarIds.isEmpty || !end.isAfter(start)) return const [];
    final rows =
        await channel.invokeListMethod<dynamic>('getDeviceCalendarEvents', {
          'calendarIds': calendarIds,
          'startMillis': start.toLocal().millisecondsSinceEpoch,
          'endMillis': end.toLocal().millisecondsSinceEpoch,
        }) ??
        const [];
    return rows.whereType<Map>().map(AndroidCalendarEntry.fromMap).toList();
  }
}
