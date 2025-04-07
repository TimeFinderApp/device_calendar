import 'reminders_list.dart';

class Reminder {
  RemList list;
  String? id;
  String title;
  DateTime? dueDate;
  int priority;
  bool isCompleted;
  String? notes;
  DateTime? lastModifiedDate;

  Reminder(
      {required this.list,
      this.id,
      required this.title,
      this.dueDate,
      this.priority = 0,
      this.isCompleted = false,
      this.notes,
      this.lastModifiedDate});

  Reminder.fromJson(Map<String, dynamic> json)
      : list = RemList.fromJson(json['list']),
        id = json['id'],
        title = json['title'],
        priority = json['priority'],
        isCompleted = json['isCompleted'],
        notes = json['notes'] {
    if (json['dueDate'] != null) {
      final date = json['dueDate'];
      dueDate = DateTime(date['year']!, date['month']!, date['day']!,
          date['hour'] ?? 00, date['minute'] ?? 00, date['second'] ?? 00);
    }

    if (json['lastModifiedDate'] != null) {
      if (json['lastModifiedDate'] is DateTime) {
        lastModifiedDate = json['lastModifiedDate'] as DateTime;
      } else if (json['lastModifiedDate'] is String) {
        lastModifiedDate = DateTime.parse(json['lastModifiedDate'] as String);
      } else if (json['lastModifiedDate'] is Map) {
        final date = json['lastModifiedDate'];
        lastModifiedDate = DateTime(
          date['year'] ?? 1970,
          date['month'] ?? 1,
          date['day'] ?? 1,
          date['hour'] ?? 0,
          date['minute'] ?? 0,
          date['second'] ?? 0,
        );
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'list': list.id,
        'id': id,
        'title': title,
        'dueDate': dueDate == null
            ? null
            : {
                'year': dueDate?.year,
                'month': dueDate?.month,
                'day': dueDate?.day,
                'hour': dueDate?.hour,
                'minute': dueDate?.minute,
                'second': dueDate?.second,
              },
        'priority': priority,
        'isCompleted': isCompleted,
        'notes': notes,
        'lastModifiedDate': lastModifiedDate?.toIso8601String(),
      };

  @override
  String toString() =>
      '''List: ${list.title}\tTitle: $title\tdueDate: $dueDate\tPriority: 
      $priority\tisComplete: $isCompleted\tNotes: $notes\tID: $id\tLastModified: $lastModifiedDate''';
}
