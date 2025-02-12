import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart';
import 'package:rrule/rrule.dart' as rrule;

import '../../device_calendar.dart';
import '../common/error_messages.dart';
import 'package:device_calendar/src/models/attendee.dart';
import 'package:device_calendar/src/models/reminder.dart';

/// An event associated with a calendar
class Event {
  /// Read-only. The unique identifier for this event. This is auto-generated when a new event is created
  String? eventId;

  /// Read-only. The identifier of the calendar that this event is associated with
  String? calendarId;

  /// The title of this event
  String? title;

  /// The description for this event
  String? description;

  /// Indicates when the event starts
  TZDateTime? start;

  /// Indicates when the event ends
  TZDateTime? end;

  /// Indicates if this is an all-day event
  bool? allDay;

  /// The location of this event
  String? location;

  /// An URL for this event
  Uri? url;

  /// A list of attendees for this event
  List<Attendee?>? attendees;

  /// The recurrence rule for this event
  rrule.RecurrenceRule? recurrenceRule;

  /// A list of reminders (by minutes) for this event
  List<Reminder>? reminders;

  /// Indicates if this event counts as busy time, tentative, unavaiable or is still free time
  late Availability availability;

  /// Indicates if this event is of confirmed, canceled, tentative or none status
  EventStatus? status;

  /// Indicates if this event is detached from the recurring event series (For iOS only)
  bool? eventIsDetached;

  /// Indicates when the original occurrence of the event starts
  /// This is only used when the event is a detached event from a recurring event series (For iOS only)
  TZDateTime? eventOriginalOccurrenceDate;

  /// The timezone for the start time
  String? startTimeZone;

  /// The timezone for the end time
  String? endTimeZone;

  ///Note for development:
  ///
  ///JSON field names are coded in dart, swift and kotlin to facilitate data exchange.
  ///Make sure all locations are updated if changes needed to be made.
  ///Swift:
  ///`ios/Classes/SwiftDeviceCalendarPlugin.swift`
  ///Kotlin:
  ///`android/src/main/kotlin/com/builttoroam/devicecalendar/models/Event.kt`
  ///`android/src/main/kotlin/com/builttoroam/devicecalendar/CalendarDelegate.kt`
  ///`android/src/main/kotlin/com/builttoroam/devicecalendar/DeviceCalendarPlugin.kt`
  Event(this.calendarId,
      {this.eventId,
      this.title,
      this.start,
      this.end,
      this.description,
      this.attendees,
      this.recurrenceRule,
      this.reminders,
      this.availability = Availability.Busy,
      this.location,
      this.url,
      this.allDay = false,
      this.status,
      this.eventIsDetached = false,
      this.eventOriginalOccurrenceDate,
      this.startTimeZone,
      this.endTimeZone});

  ///Get Event from JSON.
  ///
  ///Sample JSON:
  ///{calendarId: 00, eventId: 0000, eventTitle: Sample Event, eventDescription: This is a sample event, eventStartDate: 1563719400000, eventStartTimeZone: Asia/Hong_Kong, eventEndDate: 1640532600000, eventEndTimeZone: Asia/Hong_Kong, eventAllDay: false, eventLocation: Yuenlong Station, eventURL: null, availability: BUSY, attendees: [{name: commonfolk, emailAddress: total.loss@hong.com, role: 1, isOrganizer: false, attendanceStatus: 3}], eventOccurrenceDate: 1563719400000, eventIsDetached: false, reminders: [{minutes: 39}]}
  Event.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw ArgumentError(ErrorMessages.fromJsonMapIsNull);
    }

    eventId = json['eventId'];
    calendarId = json['calendarId'];
    title = json['eventTitle'];
    description = json['eventDescription'];

    final startTimestamp = json['eventStartDate'] as int?;
    startTimeZone = json['eventStartTimeZone'] as String?;
    final startLocation = startTimeZone != null
        ? _getLocationOrUtc(startTimeZone!)
        : _getLocationOrUtc('local');
    start = startTimestamp != null
        ? TZDateTime.fromMillisecondsSinceEpoch(startLocation, startTimestamp)
        : TZDateTime.now(startLocation);

    final endTimestamp = json['eventEndDate'] as int?;
    endTimeZone = json['eventEndTimeZone'] as String?;
    final endLocation =
        endTimeZone != null ? _getLocationOrUtc(endTimeZone!) : startLocation;
    end = endTimestamp != null
        ? TZDateTime.fromMillisecondsSinceEpoch(endLocation, endTimestamp)
        : TZDateTime.now(endLocation);

    allDay = json['eventAllDay'] ?? false;
    if (Platform.isAndroid && (allDay ?? false)) {
      // On Android, the datetime in an allDay event is adjusted to local
      // timezone, which can result in the wrong day, so we need to bring the
      // date back to midnight UTC to get the correct date
      if (start != null) {
        final startUtc = start!.toUtc();
        start = TZDateTime.utc(
          startUtc.year,
          startUtc.month,
          startUtc.day,
        );
      }
      if (end != null) {
        final endUtc = end!.toUtc();
        end = TZDateTime.utc(
          endUtc.year,
          endUtc.month,
          endUtc.day,
        ).subtract(const Duration(days: 1));
      }
    }

    location = json['eventLocation'];
    availability = parseStringToAvailability(json['availability']);
    status = parseStringToEventStatus(json['eventStatus']);

    final foundUrl = json['eventURL']?.toString();
    if (foundUrl?.isEmpty ?? true) {
      url = null;
    } else {
      url = Uri.dataFromString(foundUrl!);
    }

    if (json['attendees'] != null) {
      attendees = json['attendees'].map<Attendee>((decodedAttendee) {
        return Attendee.fromJson(decodedAttendee);
      }).toList();
    }

    if (json['organizer'] != null) {
      // Getting and setting an organiser for iOS
      var organiser = Attendee.fromJson(json['organizer']);

      var attendee = attendees?.firstWhereOrNull((at) =>
          at?.name == organiser.name &&
          at?.emailAddress == organiser.emailAddress);
      if (attendee != null) {
        attendee.isOrganiser = true;
      }
    }

    eventIsDetached = json['eventIsDetached'];

    final occurrenceDateTimestamp = json['eventOccurrenceDate'] as int?;
    eventOriginalOccurrenceDate = occurrenceDateTimestamp != null
        ? TZDateTime.fromMillisecondsSinceEpoch(
            startLocation, occurrenceDateTimestamp)
        : null;

    if (json['recurrenceRule'] != null) {
      try {
        final rruleJson = json['recurrenceRule'] as Map<String, dynamic>;
        print('Parsing recurrence rule: $rruleJson');
        if (rruleJson['freq'] == null &&
            rruleJson['recurrenceFrequency'] != null) {
          // Android format
          final androidFreq = rruleJson['recurrenceFrequency'] as int;
          final freq = _androidFrequencyToRrule(androidFreq);
          final interval = rruleJson['interval'] as int? ?? 1;
          final daysOfWeek =
              (rruleJson['daysOfWeek'] as List<dynamic>?)?.cast<int>() ?? [];
          final weekOfMonth = rruleJson['weekOfMonth'] as int?;
          final dayOfMonth = rruleJson['dayOfMonth'] as int?;
          final monthOfYear = rruleJson['monthOfYear'] as int?;

          // Convert Android weekdays (1-7, starting with Sunday) to rrule weekdays
          final byWeekDay = daysOfWeek.map((day) {
            final weekday = _androidWeekdayToRrule(day);
            return rrule.ByWeekDayEntry(weekday, weekOfMonth);
          }).toList();

          final rule = rrule.RecurrenceRule(
            frequency: freq,
            interval: interval,
            byWeekDays: byWeekDay,
            byMonthDays: dayOfMonth != null ? [dayOfMonth] : [],
            byMonths: monthOfYear != null ? [monthOfYear] : [],
          );

          recurrenceRule = rule;
        } else {
          // RFC format string
          final rfcString =
              rruleJson['freq'] != null ? _jsonToRfcString(rruleJson) : null;
          print('Generated RFC string: $rfcString');
          if (rfcString != null) {
            recurrenceRule = rrule.RecurrenceRule.fromString(rfcString);
          }
        }
      } catch (e, stackTrace) {
        print('Error parsing recurrence rule: $e');
        FlutterError.reportError(FlutterErrorDetails(
          exception: e,
          stack: stackTrace,
          library: 'device_calendar plugin',
          context: ErrorDescription('while parsing RecurrenceRule from JSON'),
          informationCollector: () => [
            DiagnosticsNode.message('JSON: ${jsonEncode(json)}'),
          ],
        ));
      }
    }

    if (json['reminders'] != null) {
      reminders = json['reminders'].map<Reminder>((decodedReminder) {
        return Reminder.fromJson(decodedReminder);
      }).toList();
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};

    data['calendarId'] = calendarId;
    data['eventId'] = eventId;
    data['eventTitle'] = title;
    data['eventDescription'] = description;
    data['eventStartDate'] = start?.millisecondsSinceEpoch;
    data['eventStartTimeZone'] = startTimeZone;
    data['eventEndDate'] = end?.millisecondsSinceEpoch;
    data['eventEndTimeZone'] = endTimeZone;
    data['eventAllDay'] = allDay;
    data['eventLocation'] = location;
    data['eventURL'] = url?.data?.contentText;
    data['availability'] = availability.enumToString;
    data['eventStatus'] = status?.enumToString;
    data['eventIsDetached'] = eventIsDetached;
    data['eventOriginalOccurrenceDate'] =
        eventOriginalOccurrenceDate?.millisecondsSinceEpoch;

    if (attendees != null) {
      data['attendees'] = attendees?.map((a) => a?.toJson()).toList();
    }

    if (attendees != null) {
      data['organizer'] =
          attendees?.firstWhereOrNull((a) => a!.isOrganiser)?.toJson();
    }

    if (recurrenceRule != null) {
      data['recurrenceRule'] = {
        'freq':
            recurrenceRule!.frequency.toString().split('.').last.toUpperCase(),
        'interval': recurrenceRule!.interval,
        if (recurrenceRule!.byWeekDays.isNotEmpty)
          'byWeekDays': recurrenceRule!.byWeekDays
              .map((wd) => {
                    'day': _rruleWeekdayToAndroid(wd.day),
                    'weekNumber': wd.occurrence,
                  })
              .toList(),
        if (recurrenceRule!.byMonthDays.isNotEmpty)
          'byMonthDays': recurrenceRule!.byMonthDays,
        if (recurrenceRule!.byMonths.isNotEmpty)
          'byMonth': recurrenceRule!.byMonths,
      };
    }

    if (reminders != null) {
      data['reminders'] = reminders?.map((r) => r.toJson()).toList();
    }

    return data;
  }

  Availability parseStringToAvailability(String? value) {
    var testValue = value?.toUpperCase();
    switch (testValue) {
      case 'BUSY':
        return Availability.Busy;
      case 'FREE':
        return Availability.Free;
      case 'TENTATIVE':
        return Availability.Tentative;
      case 'UNAVAILABLE':
        return Availability.Unavailable;
    }
    return Availability.Busy;
  }

  EventStatus? parseStringToEventStatus(String? value) {
    var testValue = value?.toUpperCase();
    switch (testValue) {
      case 'CONFIRMED':
        return EventStatus.Confirmed;
      case 'TENTATIVE':
        return EventStatus.Tentative;
      case 'CANCELED':
        return EventStatus.Canceled;
      case 'NONE':
        return EventStatus.None;
    }
    return null;
  }

  bool updateStartLocation(String? newStartLocation) {
    if (newStartLocation == null || start == null) return false;
    try {
      final location = getLocation(newStartLocation);
      start = TZDateTime.from(start!, location);
      return true;
    } on LocationNotFoundException {
      return false;
    }
  }

  bool updateEndLocation(String? newEndLocation) {
    if (newEndLocation == null || end == null) return false;
    try {
      final location = getLocation(newEndLocation);
      end = TZDateTime.from(end!, location);
      return true;
    } on LocationNotFoundException {
      return false;
    }
  }

  TZDateTime? getStartWithTimezone() {
    if (start == null) return null;
    final location = startTimeZone != null
        ? getLocation(startTimeZone!)
        : getLocation('local');
    return TZDateTime.from(start!, location);
  }

  TZDateTime? getEndWithTimezone() {
    if (end == null) return null;
    final location =
        endTimeZone != null ? getLocation(endTimeZone!) : getLocation('local');
    return TZDateTime.from(end!, location);
  }

  rrule.Frequency _androidFrequencyToRrule(int androidFreq) {
    switch (androidFreq) {
      case 0: // FREQ_DAILY
        return rrule.Frequency.daily;
      case 1: // FREQ_WEEKLY
        return rrule.Frequency.weekly;
      case 2: // FREQ_MONTHLY
        return rrule.Frequency.monthly;
      case 3: // FREQ_YEARLY
        return rrule.Frequency.yearly;
      default:
        throw ArgumentError('Invalid Android frequency: $androidFreq');
    }
  }

  int _rruleWeekdayToAndroid(int rruleWeekday) {
    // Convert from DateTime weekday (1-7, starting with Monday) to Android weekday (1-7, starting with Sunday)
    // DateTime: MON=1, TUE=2, WED=3, THU=4, FRI=5, SAT=6, SUN=7
    // Android: SUN=1, MON=2, TUE=3, WED=4, THU=5, FRI=6, SAT=7
    return rruleWeekday == DateTime.sunday ? 1 : rruleWeekday + 1;
  }

  int _androidWeekdayToRrule(int androidWeekday) {
    // Convert from Android weekday (1-7, starting with Sunday) to DateTime weekday (1-7, starting with Monday)
    // Android: SUN=1, MON=2, TUE=3, WED=4, THU=5, FRI=6, SAT=7
    // DateTime: MON=1, TUE=2, WED=3, THU=4, FRI=5, SAT=6, SUN=7
    return androidWeekday == 1 ? DateTime.sunday : androidWeekday - 1;
  }

  String _jsonToRfcString(Map<String, dynamic> json) {
    final parts = <String>[];

    // Add frequency
    final freq = json['freq'] as String;
    parts.add('FREQ=$freq');

    // Add interval if present
    final interval = json['interval'] as int?;
    if (interval != null && interval > 1) {
      parts.add('INTERVAL=$interval');
    }

    // Add byWeekDays if present
    final byWeekDays = json['byWeekDays'] as List<dynamic>?;
    if (byWeekDays != null && byWeekDays.isNotEmpty) {
      final days = byWeekDays.map((wd) {
        final day = wd['day'] as int;
        final weekNumber = wd['weekNumber'] as int?;
        final weekday = _androidWeekdayToRruleString(day);
        return weekNumber != null ? '$weekNumber$weekday' : weekday;
      }).join(',');
      parts.add('BYDAY=$days');
    }

    // Add byMonthDays if present
    final byMonthDays = json['byMonthDays'] as List<dynamic>?;
    if (byMonthDays != null && byMonthDays.isNotEmpty) {
      parts.add('BYMONTHDAY=${byMonthDays.join(',')}');
    }

    // Add byMonth if present
    final byMonth = json['byMonth'] as List<dynamic>?;
    if (byMonth != null && byMonth.isNotEmpty) {
      parts.add('BYMONTH=${byMonth.join(',')}');
    }

    return 'RRULE:${parts.join(';')}';
  }

  String _androidWeekdayToRruleString(int androidWeekday) {
    switch (androidWeekday) {
      case 1:
        return 'SU';
      case 2:
        return 'MO';
      case 3:
        return 'TU';
      case 4:
        return 'WE';
      case 5:
        return 'TH';
      case 6:
        return 'FR';
      case 7:
        return 'SA';
      default:
        throw ArgumentError('Invalid Android weekday: $androidWeekday');
    }
  }

  Location _getLocationOrUtc(String name) {
    try {
      return getLocation(name);
    } on LocationNotFoundException {
      return getLocation('UTC');
    }
  }
}
