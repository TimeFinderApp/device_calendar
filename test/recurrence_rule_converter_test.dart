import 'package:flutter_test/flutter_test.dart';
import 'package:device_calendar/src/common/recurrence_rule_converter.dart';

void main() {
  group('RecurrenceRuleConverter - Basic Frequencies', () {
    test('daily recurrence', () {
      final androidRule = {
        'recurrenceFrequency': 0, // DAILY
        'interval': 1,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=DAILY');
    });

    test('daily recurrence with interval', () {
      final androidRule = {
        'recurrenceFrequency': 0, // DAILY
        'interval': 3,
      };
      expect(
          RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=DAILY;INTERVAL=3');
    });

    test('weekly recurrence', () {
      final androidRule = {
        'recurrenceFrequency': 1, // WEEKLY
        'interval': 2,
        'daysOfWeek': [2, 4, 6], // MO, WE, FR
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR');
    });

    test('weekly recurrence without interval', () {
      final androidRule = {
        'recurrenceFrequency': 1, // WEEKLY
        'daysOfWeek': [3], // TU
      };
      expect(
          RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=WEEKLY;BYDAY=TU');
    });

    test('weekly recurrence without days', () {
      final androidRule = {
        'recurrenceFrequency': 1, // WEEKLY
        'interval': 1,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=WEEKLY');
    });
  });

  group('RecurrenceRuleConverter - Monthly Patterns', () {
    test('monthly by day recurrence', () {
      final androidRule = {
        'recurrenceFrequency': 2, // MONTHLY
        'interval': 1,
        'daysOfWeek': [5], // TH
        'weekOfMonth': 1,
      };
      expect(
          RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=MONTHLY;BYDAY=1TH');
    });

    test('monthly recurrence with specific day', () {
      final androidRule = {
        'recurrenceFrequency': 2, // MONTHLY
        'interval': 1,
        'dayOfMonth': 15,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=MONTHLY;BYMONTHDAY=15');
    });

    test('monthly recurrence with nth weekday', () {
      final androidRule = {
        'recurrenceFrequency': 2, // MONTHLY
        'interval': 1,
        'daysOfWeek': [6], // FR
        'weekOfMonth': -1, // Last Friday
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=MONTHLY;BYDAY=-1FR');
    });

    test('monthly recurrence with multiple weekdays', () {
      final androidRule = {
        'recurrenceFrequency': 2, // MONTHLY
        'daysOfWeek': [2, 4, 6], // MO, WE, FR
        'weekOfMonth': 2, // Second week
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=MONTHLY;BYDAY=2MO,2WE,2FR');
    });

    test('monthly recurrence with last weekday of month', () {
      final androidRule = {
        'recurrenceFrequency': 2, // MONTHLY
        'daysOfWeek': [2], // MO
        'weekOfMonth': -1, // Last week
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=MONTHLY;BYDAY=-1MO');
    });
  });

  group('RecurrenceRuleConverter - Yearly Patterns', () {
    test('yearly recurrence', () {
      final androidRule = {
        'recurrenceFrequency': 3, // YEARLY
        'interval': 1,
        'monthOfYear': 12,
        'dayOfMonth': 25,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=YEARLY;BYMONTHDAY=25;BYMONTH=12');
    });

    test('yearly recurrence with interval', () {
      final androidRule = {
        'recurrenceFrequency': 3, // YEARLY
        'interval': 2,
        'monthOfYear': 1,
        'dayOfMonth': 1,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=YEARLY;INTERVAL=2;BYMONTHDAY=1;BYMONTH=1');
    });

    test('yearly recurrence on specific weekday', () {
      final androidRule = {
        'recurrenceFrequency': 3, // YEARLY
        'monthOfYear': 11,
        'daysOfWeek': [5], // TH
        'weekOfMonth': 4, // Fourth Thursday (Thanksgiving)
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=YEARLY;BYDAY=4TH;BYMONTH=11');
    });
  });

  group('RecurrenceRuleConverter - Count and Until', () {
    test('daily recurrence with count', () {
      final androidRule = {
        'recurrenceFrequency': 0, // DAILY
        'totalOccurrences': 10,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=DAILY;COUNT=10');
    });

    test('weekly recurrence with count', () {
      final androidRule = {
        'recurrenceFrequency': 1, // WEEKLY
        'daysOfWeek': [2], // MO
        'totalOccurrences': 5,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=WEEKLY;BYDAY=MO;COUNT=5');
    });

    test('monthly recurrence with until date', () {
      final androidRule = {
        'recurrenceFrequency': 2, // MONTHLY
        'dayOfMonth': 15,
        'endDate': 1735689600000, // 2025-01-01
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=MONTHLY;BYMONTHDAY=15;UNTIL=20250101T000000Z');
    });

    test('yearly recurrence with until date', () {
      final androidRule = {
        'recurrenceFrequency': 3, // YEARLY
        'monthOfYear': 12,
        'dayOfMonth': 31,
        'endDate': 1735689600000, // 2025-01-01
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=YEARLY;BYMONTHDAY=31;BYMONTH=12;UNTIL=20250101T000000Z');
    });

    test('count takes precedence over until date', () {
      final androidRule = {
        'recurrenceFrequency': 0, // DAILY
        'totalOccurrences': 10,
        'endDate': 1735689600000, // 2025-01-01
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=DAILY;COUNT=10');
    });
  });

  group('RecurrenceRuleConverter - All Day Events', () {
    test('daily all-day event', () {
      final androidRule = {
        'recurrenceFrequency': 0, // DAILY
        'interval': 1,
        'allDay': true,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=DAILY');
    });

    test('weekly all-day event', () {
      final androidRule = {
        'recurrenceFrequency': 1, // WEEKLY
        'daysOfWeek': [1], // SU
        'allDay': true,
      };
      expect(
          RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=WEEKLY;BYDAY=SU');
    });

    test('monthly all-day event with until date', () {
      final androidRule = {
        'recurrenceFrequency': 2, // MONTHLY
        'dayOfMonth': 1,
        'allDay': true,
        'endDate': 1735689600000, // 2025-01-01
      };
      // For all-day events, UNTIL should be set to midnight UTC
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=MONTHLY;BYMONTHDAY=1;UNTIL=20250101T000000Z');
    });
  });

  group('RecurrenceRuleConverter - Special Cases', () {
    test('first weekday of month', () {
      final androidRule = {
        'recurrenceFrequency': 2, // MONTHLY
        'daysOfWeek': [2], // MO
        'weekOfMonth': 1,
      };
      expect(
          RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=MONTHLY;BYDAY=1MO');
    });

    test('last weekday of month', () {
      final androidRule = {
        'recurrenceFrequency': 2, // MONTHLY
        'daysOfWeek': [6], // FR
        'weekOfMonth': -1,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=MONTHLY;BYDAY=-1FR');
    });

    test('second-to-last weekday of month', () {
      final androidRule = {
        'recurrenceFrequency': 2, // MONTHLY
        'daysOfWeek': [4], // WE
        'weekOfMonth': -2,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=MONTHLY;BYDAY=-2WE');
    });

    test('multiple weekdays in last week of month', () {
      final androidRule = {
        'recurrenceFrequency': 2, // MONTHLY
        'daysOfWeek': [2, 4, 6], // MO, WE, FR
        'weekOfMonth': -1,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=MONTHLY;BYDAY=-1MO,-1WE,-1FR');
    });
  });

  group('RecurrenceRuleConverter - Holiday Patterns', () {
    test('thanksgiving (fourth Thursday of November)', () {
      final androidRule = {
        'recurrenceFrequency': 3, // YEARLY
        'monthOfYear': 11,
        'daysOfWeek': [5], // TH
        'weekOfMonth': 4,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=YEARLY;BYDAY=4TH;BYMONTH=11');
    });

    test('memorial day (last Monday of May)', () {
      final androidRule = {
        'recurrenceFrequency': 3, // YEARLY
        'monthOfYear': 5,
        'daysOfWeek': [2], // MO
        'weekOfMonth': -1,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=YEARLY;BYDAY=-1MO;BYMONTH=5');
    });

    test('mothers day (second Sunday of May)', () {
      final androidRule = {
        'recurrenceFrequency': 3, // YEARLY
        'monthOfYear': 5,
        'daysOfWeek': [1], // SU
        'weekOfMonth': 2,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=YEARLY;BYDAY=2SU;BYMONTH=5');
    });

    test('labor day (first Monday of September)', () {
      final androidRule = {
        'recurrenceFrequency': 3, // YEARLY
        'monthOfYear': 9,
        'daysOfWeek': [2], // MO
        'weekOfMonth': 1,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=YEARLY;BYDAY=1MO;BYMONTH=9');
    });
  });

  group('RecurrenceRuleConverter - Validation Cases', () {
    test('invalid day of month (0)', () {
      final androidRule = {
        'recurrenceFrequency': 2, // MONTHLY
        'dayOfMonth': 0,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=MONTHLY');
    });

    test('invalid day of month (32)', () {
      final androidRule = {
        'recurrenceFrequency': 2, // MONTHLY
        'dayOfMonth': 32,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=MONTHLY');
    });

    test('invalid month (0)', () {
      final androidRule = {
        'recurrenceFrequency': 3, // YEARLY
        'monthOfYear': 0,
        'dayOfMonth': 1,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=YEARLY');
    });

    test('invalid week number (0)', () {
      final androidRule = {
        'recurrenceFrequency': 2, // MONTHLY
        'daysOfWeek': [2], // MO
        'weekOfMonth': 0,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=MONTHLY');
    });

    test('non-integer values', () {
      final androidRule = {
        'recurrenceFrequency': 0, // DAILY
        'interval': '2', // String instead of int
        'totalOccurrences': 3.5, // Double instead of int
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=DAILY');
    });
  });

  group('RecurrenceRuleConverter - Edge Cases', () {
    test('invalid frequency', () {
      final androidRule = {
        'recurrenceFrequency': 999,
        'interval': 1,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule), null);
    });

    test('missing frequency', () {
      final androidRule = {
        'interval': 1,
        'daysOfWeek': [1],
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule), null);
    });

    test('empty days of week list', () {
      final androidRule = {
        'recurrenceFrequency': 1, // WEEKLY
        'daysOfWeek': [],
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=WEEKLY');
    });

    test('invalid day of week', () {
      final androidRule = {
        'recurrenceFrequency': 1, // WEEKLY
        'daysOfWeek': [8], // Invalid day
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=WEEKLY');
    });

    test('null days of week', () {
      final androidRule = {
        'recurrenceFrequency': 1, // WEEKLY
        'daysOfWeek': null,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=WEEKLY');
    });

    test('zero interval', () {
      final androidRule = {
        'recurrenceFrequency': 0, // DAILY
        'interval': 0,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=DAILY');
    });

    test('negative interval', () {
      final androidRule = {
        'recurrenceFrequency': 0, // DAILY
        'interval': -1,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=DAILY');
    });
  });

  group('RecurrenceRuleConverter - Complex Cases', () {
    test('monthly on multiple days with interval', () {
      final androidRule = {
        'recurrenceFrequency': 2, // MONTHLY
        'interval': 2,
        'dayOfMonth': 15,
        'daysOfWeek': [2, 4], // MO, WE
        'weekOfMonth': 3,
      };
      // When both dayOfMonth and daysOfWeek are specified, prefer daysOfWeek
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=MONTHLY;INTERVAL=2;BYDAY=3MO,3WE');
    });

    test('yearly on specific weekday with interval', () {
      final androidRule = {
        'recurrenceFrequency': 3, // YEARLY
        'interval': 2,
        'monthOfYear': 5,
        'daysOfWeek': [1], // SU
        'weekOfMonth': 2, // Second Sunday in May (Mother's Day)
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule),
          'FREQ=YEARLY;INTERVAL=2;BYDAY=2SU;BYMONTH=5');
    });

    test('monthly with invalid week number', () {
      final androidRule = {
        'recurrenceFrequency': 2, // MONTHLY
        'daysOfWeek': [2], // MO
        'weekOfMonth': 6, // Invalid week number
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=MONTHLY');
    });

    test('yearly with invalid month', () {
      final androidRule = {
        'recurrenceFrequency': 3, // YEARLY
        'monthOfYear': 13, // Invalid month
        'dayOfMonth': 1,
      };
      expect(RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=YEARLY');
    });
  });

  group('RecurrenceRuleConverter - Real World Cases', () {
    test('first Wednesday of month - Android format', () {
      final androidRule = {
        'daysOfWeek': [4], // WE (Android Calendar.WEDNESDAY = 4)
        'interval': 1,
        'recurrenceFrequency': 2, // MONTHLY
        'weekOfMonth': 1,
      };
      expect(
          RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=MONTHLY;BYDAY=1WE');
    });

    test('first Wednesday of month - with extra fields', () {
      final androidRule = {
        'daysOfWeek': [4], // WE (Android Calendar.WEDNESDAY = 4)
        'interval': 1,
        'recurrenceFrequency': 2, // MONTHLY
        'weekOfMonth': 1,
        'allDay': true,
        'extraField': 'should be ignored',
      };
      expect(
          RecurrenceRuleConverter.toRfc(androidRule), 'FREQ=MONTHLY;BYDAY=1WE');
    });
  });
}
