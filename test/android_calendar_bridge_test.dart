import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deck_of_life/core/calendar/android_calendar_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/android_calendar');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('parses Android calendars and detects Google accounts', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getDeviceCalendars');
      return [
        {
          'id': 'calendar-1',
          'name': 'Personal',
          'accountName': 'user@example.com',
          'accountType': 'com.google',
          'color': 0xFF336699,
        },
      ];
    });

    final calendars = await AndroidCalendarBridge(channel: channel).calendars();

    expect(calendars.single.id, 'calendar-1');
    expect(calendars.single.isGoogleAccount, isTrue);
    expect(calendars.single.label, 'Personal · user@example.com');
  });

  test(
    'requests events only for selected calendars and maps them read-only',
    () async {
      final start = DateTime(2026, 11, 6, 9);
      final end = DateTime(2026, 11, 6, 12);
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getDeviceCalendarEvents');
        expect(call.arguments, {
          'calendarIds': ['calendar-1'],
          'startMillis': start.millisecondsSinceEpoch,
          'endMillis': end.millisecondsSinceEpoch,
        });
        return [
          {
            'id': 'event-1',
            'calendarId': 'calendar-1',
            'title': 'Stand-up',
            'startMillis': DateTime(2026, 11, 6, 10).millisecondsSinceEpoch,
            'endMillis': DateTime(2026, 11, 6, 10, 30).millisecondsSinceEpoch,
            'location': 'Room 2',
            'allDay': false,
          },
        ];
      });

      final bridge = AndroidCalendarBridge(channel: channel);
      final entries = await bridge.eventsBetween(
        calendarIds: const ['calendar-1'],
        start: start,
        end: end,
      );
      final event = entries.single.toEvent(
        const AndroidCalendarInfo(id: 'calendar-1', name: 'Personal'),
      );

      expect(event.title, 'Stand-up');
      expect(event.startsAt, DateTime(2026, 11, 6, 10));
      expect(event.externalCalendarName, 'Personal');
      expect(event.isDeviceCalendarEvent, isTrue);
      expect(event.isAllDay, isFalse);
    },
  );

  test('does not query Android when no calendar is selected', () async {
    var called = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      called = true;
      return <Object?>[];
    });

    final events = await AndroidCalendarBridge(channel: channel).eventsBetween(
      calendarIds: const [],
      start: DateTime(2026, 11, 6),
      end: DateTime(2026, 11, 7),
    );

    expect(events, isEmpty);
    expect(called, isFalse);
  });
}
