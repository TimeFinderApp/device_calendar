import 'dart:convert';

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.builttoroam.com/device_calendar');
  final plugin = DeviceCalendarPlugin();
  final params = RetrieveEventsParams(
    startDate: DateTime.utc(2026, 11, 1),
    endDate: DateTime.utc(2026, 12, 1),
  );
  final event = <String, dynamic>{
    'eventId': 'event-1',
    'calendarId': 'calendar-1',
    'eventTitle': 'Planning',
    'eventStartDate': DateTime.utc(2026, 11, 14, 9).millisecondsSinceEpoch,
    'eventEndDate': DateTime.utc(2026, 11, 14, 10).millisecondsSinceEpoch,
    'eventAllDay': false,
  };

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> expectRejected(Object? payload) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => jsonEncode(payload));
    final result = await plugin.retrieveEvents('calendar-1', params);
    expect(result.hasErrors, isTrue,
        reason: 'An incomplete snapshot must never authorize removal.');
    expect(result.data, isNull);
  }

  test('null event rejects whole native snapshot', () async {
    await expectRejected([event, null]);
  });

  test('non-list reply rejects whole native snapshot', () async {
    await expectRejected(event);
  });

  test('missing identity rejects whole native snapshot', () async {
    await expectRejected([
      event,
      {...event, 'eventId': null}
    ]);
  });

  test('foreign calendar rejects whole native snapshot', () async {
    await expectRejected([
      event,
      {...event, 'calendarId': 'calendar-2'}
    ]);
  });

  test('missing bounds reject whole native snapshot', () async {
    await expectRejected([
      event,
      {...event, 'eventEndDate': null}
    ]);
  });

  test('invalid bounds reject whole native snapshot', () async {
    await expectRejected([
      event,
      {...event, 'eventStartDate': event['eventEndDate'], 'eventEndDate': 1}
    ]);
  });

  test('invalid recurrence cannot become a single occurrence', () async {
    await expectRejected([
      {
        ...event,
        'recurrenceRule': {'freq': 'INVALID', 'interval': 1}
      }
    ]);
  });

  test('complete empty native snapshot remains successful', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => '[]');
    final result = await plugin.retrieveEvents('calendar-1', params);
    expect(result.isSuccess, isTrue);
    expect(result.data, isEmpty);
  });

  test('valid repeated instances retain identity and original dates', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            channel,
            (_) async => jsonEncode([
                  event,
                  {
                    ...event,
                    'eventStartDate':
                        DateTime.utc(2026, 11, 15, 9).millisecondsSinceEpoch,
                    'eventEndDate':
                        DateTime.utc(2026, 11, 15, 10).millisecondsSinceEpoch,
                    'eventOccurrenceDate':
                        DateTime.utc(2026, 11, 15, 9).millisecondsSinceEpoch,
                  }
                ]));
    final result = await plugin.retrieveEvents('calendar-1', params);
    expect(result.isSuccess, isTrue);
    expect(result.data, hasLength(2));
    expect(result.data!.map((item) => item.eventId).toList(),
        ['event-1', 'event-1']);
    expect(result.data!.last.eventOriginalOccurrenceDate?.toUtc(),
        DateTime.utc(2026, 11, 15, 9));
  });

  test('provider recurrence preserves every month day and exact until instant',
      () async {
    const rule = 'FREQ=MONTHLY;BYMONTHDAY=1,15;UNTIL=20261231T235959Z';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            channel,
            (_) async => jsonEncode([
                  {
                    ...event,
                    'recurrenceRule': {
                      'recurrenceFrequency': 2,
                      'dayOfMonth': 1,
                      'sourceRruleString': rule,
                    },
                  }
                ]));
    final result = await plugin.retrieveEvents('calendar-1', params);
    expect(result.isSuccess, isTrue);
    final recurrence = result.data!.single.recurrenceRule!;
    expect(recurrence.byMonthDays, [1, 15]);
    expect(recurrence.until, DateTime.utc(2026, 12, 31, 23, 59, 59));
    expect(result.data!.single.start?.toUtc(), DateTime.utc(2026, 11, 14, 9));
  });

  test('provider recurrence preserves independent ordinal weekdays', () async {
    const rule = 'FREQ=MONTHLY;BYDAY=1MO,-1FR;COUNT=4';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            channel,
            (_) async => jsonEncode([
                  {
                    ...event,
                    'recurrenceRule': {
                      'recurrenceFrequency': 2,
                      'daysOfWeek': [2, 6],
                      'weekOfMonth': 1,
                      'sourceRruleString': rule,
                    },
                  }
                ]));
    final result = await plugin.retrieveEvents('calendar-1', params);
    expect(result.isSuccess, isTrue);
    expect(
        result.data!.single.recurrenceRule!.toString(), contains('1MO,-1FR'));
    expect(result.data!.single.recurrenceRule!.count, 4);
  });
}
