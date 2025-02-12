/// Converts between Android's native recurrence format and RFC format.
class RecurrenceRuleConverter {
  static String? toRfc(Map<String, dynamic> androidRule) {
    if (!androidRule.containsKey('recurrenceFrequency')) {
      return null;
    }

    final frequency = _getFrequency(androidRule['recurrenceFrequency'] as int);
    if (frequency == null) {
      return null;
    }

    final parts = <String>[];
    parts.add('FREQ=$frequency');

    // Add interval if present and greater than 1
    final interval = androidRule['interval'];
    if (interval != null && interval is int && interval > 1) {
      parts.add('INTERVAL=$interval');
    }

    // Add BYDAY for weekly recurrence or when weekOfMonth is specified
    if (frequency == 'WEEKLY' || androidRule['weekOfMonth'] != null) {
      final daysOfWeek = androidRule['daysOfWeek'];
      if (daysOfWeek is List && daysOfWeek.isNotEmpty) {
        final byDay = daysOfWeek
            .map((day) => _getDayAbbreviation(day as int))
            .whereType<String>();
        if (byDay.isNotEmpty) {
          // For monthly/yearly with weekOfMonth, prefix the day with the week number
          if (androidRule['weekOfMonth'] != null) {
            final weekOfMonth = androidRule['weekOfMonth'] as int;
            // Only use weekOfMonth if it's within valid range (-5 to 5, excluding 0)
            if (weekOfMonth != 0 && weekOfMonth >= -5 && weekOfMonth <= 5) {
              parts.add(
                  'BYDAY=${byDay.map((day) => '$weekOfMonth$day').join(',')}');
            }
          } else {
            parts.add('BYDAY=${byDay.join(',')}');
          }
        }
      }
    }

    // Add BYMONTHDAY and BYMONTH for monthly/yearly recurrence
    if (frequency == 'MONTHLY' || frequency == 'YEARLY') {
      // Only add BYMONTHDAY if we're not using BYDAY (they're mutually exclusive)
      if (!parts.any((part) => part.startsWith('BYDAY='))) {
        final dayOfMonth = androidRule['dayOfMonth'];
        if (dayOfMonth is int && dayOfMonth > 0 && dayOfMonth <= 31) {
          // For yearly recurrence, only add BYMONTHDAY if we have a valid month
          if (frequency != 'YEARLY' ||
              (androidRule['monthOfYear'] is int &&
                  androidRule['monthOfYear'] > 0 &&
                  androidRule['monthOfYear'] <= 12)) {
            parts.add('BYMONTHDAY=$dayOfMonth');
          }
        }
      }

      if (frequency == 'YEARLY') {
        final monthOfYear = androidRule['monthOfYear'];
        if (monthOfYear is int && monthOfYear > 0 && monthOfYear <= 12) {
          parts.add('BYMONTH=$monthOfYear');
        }
      }
    }

    // Add COUNT if present
    final totalOccurrences = androidRule['totalOccurrences'];
    if (totalOccurrences != null &&
        totalOccurrences is int &&
        totalOccurrences > 0) {
      parts.add('COUNT=$totalOccurrences');
    } else {
      // Add UNTIL if COUNT is not present
      final endDate = androidRule['endDate'];
      if (endDate != null && endDate is int) {
        final date = DateTime.fromMillisecondsSinceEpoch(endDate);
        final utcDate = date.toUtc();
        final formattedDate =
            '${utcDate.year}${utcDate.month.toString().padLeft(2, '0')}${utcDate.day.toString().padLeft(2, '0')}T000000Z';
        parts.add('UNTIL=$formattedDate');
      }
    }

    return parts.join(';');
  }

  static String? _getFrequency(int androidFrequency) {
    switch (androidFrequency) {
      case 0:
        return 'DAILY';
      case 1:
        return 'WEEKLY';
      case 2:
        return 'MONTHLY';
      case 3:
        return 'YEARLY';
      default:
        return null;
    }
  }

  static String? _getDayAbbreviation(int androidDay) {
    switch (androidDay) {
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
        return null;
    }
  }
}
