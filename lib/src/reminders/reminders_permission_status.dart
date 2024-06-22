enum PermissionStatus {
  authorized,
  denied,
  notDetermined,
  restricted,
  unknown,
  fullAccess,
  writeOnly,
}

// Optionally, you can add an extension to provide string values or other functionality.
extension PermissionStatusExtension on PermissionStatus {
  String get rawValue {
    switch (this) {
      case PermissionStatus.authorized:
        return "authorized";
      case PermissionStatus.denied:
        return "denied";
      case PermissionStatus.notDetermined:
        return "notDetermined";
      case PermissionStatus.restricted:
        return "restricted";
      case PermissionStatus.unknown:
        return "unknown";
      case PermissionStatus.fullAccess:
        return "fullAccess";
      case PermissionStatus.writeOnly:
        return "writeOnly";
      default:
        return "unknown";
    }
  }

  // If you need to create a PermissionStatus from a string (e.g., when receiving data from the platform channel), you can add this factory constructor.
  static PermissionStatus fromRawValue(String rawValue) {
    switch (rawValue) {
      case "authorized":
        return PermissionStatus.authorized;
      case "denied":
        return PermissionStatus.denied;
      case "notDetermined":
        return PermissionStatus.notDetermined;
      case "restricted":
        return PermissionStatus.restricted;
      case "fullAccess":
        return PermissionStatus.fullAccess;
      case "writeOnly":
        return PermissionStatus.writeOnly;
      default:
        return PermissionStatus.unknown;
    }
  }
}
