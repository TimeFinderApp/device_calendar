import '../../../common/error_messages.dart';
import 'attendance_status.dart';

class AndroidAttendeeDetails {
  AndroidAttendanceStatus? attendanceStatus;

  AndroidAttendeeDetails({this.attendanceStatus});

  AndroidAttendeeDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw ArgumentError(ErrorMessages.fromJsonMapIsNull);
    }

    final status = json['attendanceStatus'];
    if (status is int &&
        status >= 0 &&
        status < AndroidAttendanceStatus.values.length) {
      attendanceStatus = AndroidAttendanceStatus.values[status];
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'attendanceStatus': attendanceStatus?.index};
  }
}
