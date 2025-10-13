import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../device_calendar.dart';
import '../common/error_messages.dart';
import '../common/recurrence_rule_converter.dart';

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
  RecurrenceRule? recurrenceRule;

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
      this.eventOriginalOccurrenceDate});

  ///Get Event from JSON.
  ///
  ///Sample JSON:
  ///{calendarId: 00, eventId: 0000, eventTitle: Sample Event, eventDescription: This is a sample event, eventStartDate: 1563719400000, eventStartTimeZone: Asia/Hong_Kong, eventEndDate: 1640532600000, eventEndTimeZone: Asia/Hong_Kong, eventAllDay: false, eventLocation: Yuenlong Station, eventURL: null, availability: BUSY, attendees: [{name: commonfolk, emailAddress: total.loss@hong.com, role: 1, isOrganizer: false, attendanceStatus: 3}], eventOccurrenceDate: 1563719400000, eventIsDetached: false, reminders: [{minutes: 39}]}
  Event.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw ArgumentError(ErrorMessages.fromJsonMapIsNull);
    }
    String? foundUrl;
    String? startLocationName;
    String? endLocationName;
    int? startTimestamp;
    int? endTimestamp;
    bool legacyJSON = false;
    var legacyName = {
      title: 'title',
      description: 'description',
      startTimestamp: 'start',
      endTimestamp: 'end',
      startLocationName: 'startTimeZone',
      endLocationName: 'endTimeZone',
      allDay: 'allDay',
      location: 'location',
      foundUrl: 'url',
    };
    legacyName.forEach((key, value) {
      if (json[value] != null) {
        key = json[value];
        legacyJSON = true;
      }
    });

    eventId = json['eventId'];
    calendarId = json['calendarId'];
    title = json['eventTitle'];
    description = json['eventDescription'];

    startTimestamp = json['eventStartDate'];
    startLocationName = json['eventStartTimeZone'];
    var startTimeZone = timeZoneDatabase.locations[startLocationName];
    startTimeZone ??= local;
    start = startTimestamp != null
        ? TZDateTime.fromMillisecondsSinceEpoch(startTimeZone, startTimestamp)
        : TZDateTime.now(local);

    endTimestamp = json['eventEndDate'];
    endLocationName = json['eventEndTimeZone'];
    var endLocation = timeZoneDatabase.locations[endLocationName];
    endLocation ??= startTimeZone;
    end = endTimestamp != null
        ? TZDateTime.fromMillisecondsSinceEpoch(endLocation, endTimestamp)
        : TZDateTime.now(local);
    allDay = json['eventAllDay'] ?? false;
    if (Platform.isAndroid && (allDay ?? false)) {
      // On Android, the datetime in an allDay event is adjusted to local
      // timezone, which can result in the wrong day, so we need to bring the
      // date back to midnight UTC to get the correct date
      var startOffset = start?.timeZoneOffset.inMilliseconds ?? 0;
      var endOffset = end?.timeZoneOffset.inMilliseconds ?? 0;
      // subtract the offset to get back to midnight on the correct date
      start = start?.subtract(Duration(milliseconds: startOffset));
      end = end?.subtract(Duration(milliseconds: endOffset));
      // The Event End Date for allDay events is midnight of the next day, so
      // subtract one day
      end = end?.subtract(const Duration(days: 1));
    }
    location = json['eventLocation'];
    availability = parseStringToAvailability(json['availability']);
    status = parseStringToEventStatus(json['eventStatus']);

    foundUrl = json['eventURL']?.toString();
    if (foundUrl?.isEmpty ?? true) {
      url = null;
    } else {
      url = Uri.dataFromString(foundUrl as String);
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

    var occurrenceDateTimestamp = json['eventOccurrenceDate'];
    eventOriginalOccurrenceDate = occurrenceDateTimestamp != null
        ? TZDateTime.fromMillisecondsSinceEpoch(
            startTimeZone, occurrenceDateTimestamp)
        : null;

    if (json['recurrenceRule'] != null) {
      try {
        if (Platform.isAndroid) {
          // Convert Android format to RFC format
          final rfc = RecurrenceRuleConverter.toRfc(json['recurrenceRule']);
          if (rfc != null) {
            // Parse the RFC format string back to a map that rrule package can understand
            final rfcMap = {
              'freq': rfc
                  .split(';')
                  .firstWhere((part) => part.startsWith('FREQ='))
                  .substring(5),
              'interval': json['recurrenceRule']['interval'],
            };

            // Add BYDAY if present
            final bydayPart = rfc
                .split(';')
                .firstWhereOrNull((part) => part.startsWith('BYDAY='));
            if (bydayPart != null) {
              rfcMap['byday'] = bydayPart.substring(6).split(',');
            }

            // Add other parts if present
            for (final part in ['BYMONTHDAY', 'BYMONTH']) {
              final value = rfc
                  .split(';')
                  .firstWhereOrNull((p) => p.startsWith('$part='));
              if (value != null) {
                rfcMap[part.toLowerCase()] = [int.parse(value.split('=')[1])];
              }
            }

            // Add UNTIL if present
            final untilPart = rfc
                .split(';')
                .firstWhereOrNull((p) => p.startsWith('UNTIL='));
            if (untilPart != null) {
              // Parse UNTIL date from RFC format (e.g., UNTIL=20251211T045959Z)
              final untilStr = untilPart.substring(6); // Remove "UNTIL="

              // Parse the RFC date string and convert to ISO 8601 format
              // RFC format: YYYYMMDDTHHmmssZ -> ISO: YYYY-MM-DDTHH:mm:ssZ
              try {
                final year = untilStr.substring(0, 4);
                final month = untilStr.substring(4, 6);
                final day = untilStr.substring(6, 8);
                final hasTime = untilStr.length > 8 && untilStr[8] == 'T';

                if (hasTime) {
                  final hour = untilStr.substring(9, 11);
                  final minute = untilStr.substring(11, 13);
                  final second = untilStr.substring(13, 15);
                  rfcMap['until'] = '$year-$month-${day}T$hour:$minute:${second}Z';
                } else {
                  rfcMap['until'] = '$year-$month-${day}T00:00:00Z';
                }
              } catch (e) {
                // If parsing fails, don't include UNTIL
                print('Failed to parse UNTIL date: $untilStr');
              }
            }

            // Add COUNT if present
            final countPart = rfc
                .split(';')
                .firstWhereOrNull((p) => p.startsWith('COUNT='));
            if (countPart != null) {
              rfcMap['count'] = int.parse(countPart.substring(6));
            }

            json['recurrenceRule'] = rfcMap;
          }
        }

        if (json['recurrenceRule'] != null) {
          // Sanitize the recurrence rule to handle malformed rules from third-party apps
          final sanitizedRule = _sanitizeRecurrenceRule(json['recurrenceRule']);
          recurrenceRule = RecurrenceRule.fromJson(sanitizedRule);
        }
      } catch (e, stackTrace) {
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
    if (legacyJSON) {
      throw const FormatException(
          'legacy JSON detected. Please update your current JSONs as they may not be supported later on.');
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};

    data['calendarId'] = calendarId;
    data['eventId'] = eventId;
    data['eventTitle'] = title;
    data['eventDescription'] = description;
    data['eventStartDate'] = start?.millisecondsSinceEpoch ??
        TZDateTime.now(local).millisecondsSinceEpoch;
    data['eventStartTimeZone'] = start?.location.name;
    data['eventEndDate'] = end?.millisecondsSinceEpoch ??
        TZDateTime.now(local).millisecondsSinceEpoch;
    data['eventEndTimeZone'] = end?.location.name;
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
      data['recurrenceRule'] = recurrenceRule?.toJson();
      // print("EVENT_TO_JSON_RRULE: ${recurrenceRule?.toJson()}");
    }

    if (reminders != null) {
      data['reminders'] = reminders?.map((r) => r.toJson()).toList();
    }
    // debugPrint("EVENT_TO_JSON: $data");
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
    if (newStartLocation == null) return false;
    try {
      var location = timeZoneDatabase.get(newStartLocation);
      start = TZDateTime.from(start as TZDateTime, location);
      return true;
    } on LocationNotFoundException {
      return false;
    }
  }

  bool updateEndLocation(String? newEndLocation) {
    if (newEndLocation == null) return false;
    try {
      var location = timeZoneDatabase.get(newEndLocation);
      end = TZDateTime.from(end as TZDateTime, location);
      return true;
    } on LocationNotFoundException {
      return false;
    }
  }

  /// Sanitizes recurrence rule to handle malformed rules from third-party calendar apps
  /// Following the "graceful degradation" approach similar to libical
  static Map<String, dynamic> _sanitizeRecurrenceRule(Map<String, dynamic> rule) {
    final sanitized = Map<String, dynamic>.from(rule);
    final freq = sanitized['freq'] as String?;
    
    // Handle RFC 5545 violation: BYYEARDAY MUST NOT be specified for DAILY, WEEKLY, or MONTHLY
    if (freq != null && ['DAILY', 'WEEKLY', 'MONTHLY'].contains(freq.toUpperCase())) {
      if (sanitized.containsKey('byyearday')) {
        print('WARNING: Removing BYYEARDAY from $freq recurrence rule (RFC 5545 violation)');
        print('Event may have been created by third-party calendar app with relaxed validation');
        sanitized.remove('byyearday');
      }
    }
    
    return sanitized;
  }
}
