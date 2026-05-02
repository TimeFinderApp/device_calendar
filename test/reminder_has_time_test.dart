import 'package:device_calendar/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reminder.hasTime', () {
    test('defaults to false for date-only reminders', () {
      final reminder = Reminder(
        list: RemList('Tasks'),
        title: 'Date only',
        dueDate: DateTime(2026, 5, 1),
      );

      expect(reminder.hasTime, isFalse);
      expect(reminder.toJson()['hasTime'], isFalse);
    });

    test('can preserve timed midnight explicitly', () {
      final reminder = Reminder(
        list: RemList('Tasks'),
        title: 'Midnight',
        dueDate: DateTime(2026, 5, 1),
        hasTime: true,
      );

      expect(reminder.hasTime, isTrue);
      expect(reminder.toJson()['hasTime'], isTrue);
    });

    test('infers true for non-midnight due dates', () {
      final reminder = Reminder(
        list: RemList('Tasks'),
        title: 'Timed',
        dueDate: DateTime(2026, 5, 1, 9, 30),
      );

      expect(reminder.hasTime, isTrue);
      expect(reminder.toJson()['hasTime'], isTrue);
    });

    test('deserializes hasTime from JSON when provided', () {
      final reminder = Reminder.fromJson({
        'list': {'title': 'Tasks', 'id': 'list-id'},
        'id': 'reminder-id',
        'title': 'Midnight',
        'hasTime': true,
        'dueDate': {'year': 2026, 'month': 5, 'day': 1},
        'priority': 0,
        'isCompleted': false,
        'notes': null,
      });

      expect(reminder.hasTime, isTrue);
      expect(reminder.dueDate, DateTime(2026, 5, 1));
    });

    test('infers hasTime from legacy JSON with time fields', () {
      final reminder = Reminder.fromJson({
        'list': {'title': 'Tasks', 'id': 'list-id'},
        'id': 'reminder-id',
        'title': 'Timed',
        'dueDate': {
          'year': 2026,
          'month': 5,
          'day': 1,
          'hour': 0,
          'minute': 0,
          'second': 0,
        },
        'priority': 0,
        'isCompleted': false,
        'notes': null,
      });

      expect(reminder.hasTime, isTrue);
      expect(reminder.dueDate, DateTime(2026, 5, 1));
    });
  });
}
