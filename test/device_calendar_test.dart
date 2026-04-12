import 'package:device_calendar/device_calendar.dart';
import 'package:device_calendar/src/common/error_codes.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rrule/rrule.dart' as rrule;
import 'package:timezone/timezone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.builttoroam.com/device_calendar');
  var deviceCalendarPlugin = DeviceCalendarPlugin();

  final log = <MethodCall>[];

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      print('Calling channel method ${methodCall.method}');
      log.add(methodCall);

      return null;
    });

    log.clear();
  });

  test('HasPermissions_Returns_Successfully', () async {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return true;
    });

    final result = await deviceCalendarPlugin.hasPermissions();
    expect(result.isSuccess, true);
    expect(result.errors, isEmpty);
    expect(result.data, true);
  });

  test('RequestPermissions_Returns_Successfully', () async {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return true;
    });

    final result = await deviceCalendarPlugin.requestPermissions();
    expect(result.isSuccess, true);
    expect(result.errors, isEmpty);
    expect(result.data, true);
  });

  test('RetrieveCalendars_Returns_Successfully', () async {
    const fakeCalendarName = 'fakeCalendarName';
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '[{"id":"1","isReadOnly":false,"name":"$fakeCalendarName"}]';
    });

    final result = await deviceCalendarPlugin.retrieveCalendars();
    expect(result.isSuccess, true);
    expect(result.errors, isEmpty);
    expect(result.data, isNotNull);
    expect(result.data, isNotEmpty);
    expect(result.data?[0].name, fakeCalendarName);
  });

  test('RetrieveEvents_CalendarId_IsRequired', () async {
    const String? calendarId = null;
    const params = RetrieveEventsParams();

    final result =
        await deviceCalendarPlugin.retrieveEvents(calendarId, params);
    expect(result.isSuccess, false);
    expect(result.errors.length, greaterThan(0));
    expect(result.errors[0].errorCode, equals(ErrorCodes.invalidArguments));
  });

  test('DeleteEvent_CalendarId_IsRequired', () async {
    const String? calendarId = null;
    const eventId = 'fakeEventId';

    final result = await deviceCalendarPlugin.deleteEvent(calendarId, eventId);
    expect(result.isSuccess, false);
    expect(result.errors.length, greaterThan(0));
    expect(result.errors[0].errorCode, equals(ErrorCodes.invalidArguments));
  });

  test('DeleteEvent_EventId_IsRequired', () async {
    const calendarId = 'fakeCalendarId';
    const String? eventId = null;

    final result = await deviceCalendarPlugin.deleteEvent(calendarId, eventId);
    expect(result.isSuccess, false);
    expect(result.errors.length, greaterThan(0));
    expect(result.errors[0].errorCode, equals(ErrorCodes.invalidArguments));
  });

  test('DeleteEvent_PassesArguments_Correctly', () async {
    const calendarId = 'fakeCalendarId';
    const eventId = 'fakeEventId';

    await deviceCalendarPlugin.deleteEvent(calendarId, eventId);
    expect(log, <Matcher>[
      isMethodCall('deleteEvent', arguments: <String, dynamic>{
        'calendarId': calendarId,
        'eventId': eventId
      })
    ]);
  });

  test('CreateEvent_Arguments_Invalid', () async {
    const String? fakeCalendarId = null;
    final event = Event(fakeCalendarId);

    final result = await deviceCalendarPlugin.createOrUpdateEvent(event);
    expect(result!.isSuccess, false);
    expect(result.errors, isNotEmpty);
    expect(result.errors[0].errorCode, equals(ErrorCodes.invalidArguments));
  });

  test('CreateEvent_Returns_Successfully', () async {
    const fakeNewEventId = 'fakeNewEventId';
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return fakeNewEventId;
    });

    const fakeCalendarId = 'fakeCalendarId';
    final event = Event(fakeCalendarId);
    event.title = 'fakeEventTitle';
    event.start = TZDateTime.now(local);
    event.end = event.start!.add(const Duration(hours: 1));

    final result = await deviceCalendarPlugin.createOrUpdateEvent(event);
    expect(result?.isSuccess, true);
    expect(result?.errors, isEmpty);
    expect(result?.data, isNotEmpty);
    expect(result?.data, fakeNewEventId);
  });

  test('UpdateEvent_Returns_Successfully', () async {
    const fakeNewEventId = 'fakeNewEventId';
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      final arguments = methodCall.arguments as Map<dynamic, dynamic>;
      if (!arguments.containsKey('eventId') || arguments['eventId'] == null) {
        return null;
      }

      return fakeNewEventId;
    });

    const fakeCalendarId = 'fakeCalendarId';
    final event = Event(fakeCalendarId);
    event.eventId = 'fakeEventId';
    event.title = 'fakeEventTitle';
    event.start = TZDateTime.now(local);
    event.end = event.start!.add(const Duration(hours: 1));

    final result = await deviceCalendarPlugin.createOrUpdateEvent(event);
    expect(result?.isSuccess, true);
    expect(result?.errors, isEmpty);
    expect(result?.data, isNotEmpty);
    expect(result?.data, fakeNewEventId);
  });

  test('Attendee_Serialises_Correctly', () async {
    final attendee = Attendee(
        name: 'Test Attendee',
        emailAddress: 'test@t.com',
        role: AttendeeRole.Required,
        isOrganiser: true);
    final stringAttendee = attendee.toJson();
    expect(stringAttendee, isNotNull);
    final newAttendee = Attendee.fromJson(stringAttendee);
    expect(newAttendee, isNotNull);
    expect(newAttendee.name, equals(attendee.name));
    expect(newAttendee.emailAddress, equals(attendee.emailAddress));
    expect(newAttendee.role, equals(attendee.role));
    expect(newAttendee.isOrganiser, equals(attendee.isOrganiser));
    expect(newAttendee.iosAttendeeDetails, isNull);
    expect(newAttendee.androidAttendeeDetails, isNull);
  });

  test('Event_Serializes_Correctly', () async {
    final startTime = TZDateTime(
        timeZoneDatabase.locations.entries.skip(20).first.value,
        1980,
        10,
        1,
        0,
        0,
        0);
    final endTime = TZDateTime(
        timeZoneDatabase.locations.entries.skip(21).first.value,
        1980,
        10,
        2,
        0,
        0,
        0);
    final attendee = Attendee(
        name: 'Test Attendee',
        emailAddress: 'test@t.com',
        role: AttendeeRole.Required,
        isOrganiser: true);
    final recurrence = rrule.RecurrenceRule(
      frequency: rrule.Frequency.daily,
      interval: 1,
    );
    final reminder = Reminder(minutes: 10);
    var event = Event('calendarId',
        eventId: 'eventId',
        title: 'Test Event',
        start: startTime,
        location: 'Seattle, Washington',
        url: Uri.dataFromString('http://www.example.com'),
        end: endTime,
        attendees: [attendee],
        description: 'Test description',
        recurrenceRule: recurrence,
        reminders: [reminder],
        availability: Availability.Busy,
        status: EventStatus.Confirmed);

    final stringEvent = event.toJson();
    expect(stringEvent, isNotNull);
    final newEvent = Event.fromJson(stringEvent);
    expect(newEvent, isNotNull);
    expect(newEvent.calendarId, equals(event.calendarId));
    expect(newEvent.eventId, equals(event.eventId));
    expect(newEvent.title, equals(event.title));
    expect(newEvent.start!.millisecondsSinceEpoch,
        equals(event.start!.millisecondsSinceEpoch));
    expect(newEvent.end!.millisecondsSinceEpoch,
        equals(event.end!.millisecondsSinceEpoch));
    expect(newEvent.description, equals(event.description));
    expect(newEvent.url, equals(event.url));
    expect(newEvent.location, equals(event.location));
    expect(newEvent.attendees, isNotNull);
    expect(newEvent.attendees?.length, equals(1));
    expect(newEvent.recurrenceRule, isNotNull);
    expect(newEvent.recurrenceRule?.frequency,
        equals(event.recurrenceRule?.frequency));
    expect(newEvent.reminders, isNotNull);
    expect(newEvent.reminders?.length, equals(1));
    expect(newEvent.availability, equals(event.availability));
    expect(newEvent.status, equals(event.status));
  });

  test('Event preserves Android recurring identity metadata', () {
    final event = Event(
      'calendarId',
      eventId: 'eventId',
      title: 'Recurring Event',
      start: TZDateTime(local, 2026, 4, 21, 9),
      end: TZDateTime(local, 2026, 4, 21, 10),
      recurringSegmentId: 'segment-1',
      recurringLineageId: 'lineage-1',
      androidOriginalId: '42',
      androidOriginalSyncId: 'orig-sync',
      androidSyncId: 'segment-sync',
      androidUid2445: 'uid-2445',
      androidOriginalInstanceTime: 1710000000000,
      androidIsException: true,
    );

    final decoded = Event.fromJson(event.toJson());
    expect(decoded.recurringSegmentId, equals('segment-1'));
    expect(decoded.recurringLineageId, equals('lineage-1'));
    expect(decoded.androidOriginalId, equals('42'));
    expect(decoded.androidOriginalSyncId, equals('orig-sync'));
    expect(decoded.androidSyncId, equals('segment-sync'));
    expect(decoded.androidUid2445, equals('uid-2445'));
    expect(decoded.androidOriginalInstanceTime, equals(1710000000000));
    expect(decoded.androidIsException, isTrue);
  });
}
