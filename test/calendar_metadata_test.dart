import 'package:device_calendar/device_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android calendar visibility and sync metadata round-trip', () {
    final calendar = Calendar.fromJson(<String, dynamic>{
      'id': '36',
      'name': 'PBP Webinars & Course Tasks',
      'accountType': 'com.google',
      'isVisible': true,
      'syncEvents': false,
    });

    expect(calendar.isVisible, isTrue);
    expect(calendar.syncEvents, isFalse);
    expect(calendar.toJson(), containsPair('isVisible', true));
    expect(calendar.toJson(), containsPair('syncEvents', false));
  });
}
