import '../../../common/error_messages.dart';
import 'attendance_status.dart';

class IosAttendeeDetails {
  IosAttendanceStatus? attendanceStatus;
  IosAttendeeDetails({this.attendanceStatus});

  IosAttendeeDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw ArgumentError(ErrorMessages.fromJsonMapIsNull);
    }

    final status = json['attendanceStatus'];
    if (status is int &&
        status >= 0 &&
        status < IosAttendanceStatus.values.length) {
      attendanceStatus = IosAttendanceStatus.values[status];
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'attendanceStatus': attendanceStatus?.index};
  }
}
