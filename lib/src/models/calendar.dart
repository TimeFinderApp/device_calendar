/// A calendar on the user's device
class Calendar {
  /// Read-only. The unique identifier for this calendar
  String? id;

  /// The name of this calendar
  String? name;

  /// Read-only. If the calendar is read-only
  bool? isReadOnly;

  /// Read-only. If the calendar is the default
  bool? isDefault;

  /// Read-only. If Android exposes this calendar as visible.
  /// Not available on iOS/macOS (null).
  bool? isVisible;

  /// Read-only. If Android's Calendar Provider is configured to sync events.
  /// Not available on iOS/macOS (null).
  bool? syncEvents;

  /// Read-only. Color of the calendar
  int? color;

  // Read-only. Account name associated with the calendar
  String? accountName;

  // Read-only. Account type associated with the calendar
  String? accountType;

  // Read-only. Source identifier for the calendar's account source.
  // On iOS/macOS this is the EKSource.sourceIdentifier (e.g. "iCloud").
  // Not available on Android (null).
  String? sourceIdentifier;

  // Read-only. Owner account email address.
  // On Android this is CalendarContract.Calendars.OWNER_ACCOUNT.
  // Not available on iOS/macOS (null).
  String? ownerAccount;

  Calendar(
      {this.id,
      this.name,
      this.isReadOnly,
      this.isDefault,
      this.isVisible,
      this.syncEvents,
      this.color,
      this.accountName,
      this.accountType,
      this.sourceIdentifier,
      this.ownerAccount});

  Calendar.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    isReadOnly = json['isReadOnly'];
    isDefault = json['isDefault'];
    isVisible = json['isVisible'];
    syncEvents = json['syncEvents'];
    color = json['color'];
    accountName = json['accountName'];
    accountType = json['accountType'];
    sourceIdentifier = json['sourceIdentifier'];
    ownerAccount = json['ownerAccount'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'id': id,
      'name': name,
      'isReadOnly': isReadOnly,
      'isDefault': isDefault,
      'isVisible': isVisible,
      'syncEvents': syncEvents,
      'color': color,
      'accountName': accountName,
      'accountType': accountType,
      'sourceIdentifier': sourceIdentifier,
      'ownerAccount': ownerAccount,
    };

    return data;
  }
}
