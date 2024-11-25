import EventKit
import Foundation

#if os(macOS)
import FlutterMacOS
#elseif os(iOS)
import EventKitUI
import Flutter
import UIKit
#endif

#if os(macOS)
typealias XColor = NSColor
typealias EKEventViewDelegate = NSObject
typealias UINavigationControllerDelegate = NSObject
#elseif os(iOS)
typealias XColor = UIColor
#endif

extension Date {
    var millisecondsSinceEpoch: Double { return self.timeIntervalSince1970 * 1000.0 }
}

extension EKParticipant {
    var emailAddress: String? {
        return self.value(forKey: "emailAddress") as? String
    }
}

extension String {
    func match(_ regex: String) -> [[String]] {
        let nsString = self as NSString
        return (try? NSRegularExpression(pattern: regex, options: []))?.matches(in: self, options: [], range: NSMakeRange(0, nsString.length)).map { match in
            (0..<match.numberOfRanges).map { match.range(at: $0).location == NSNotFound ? "" : nsString.substring(with: match.range(at: $0)) }
        } ?? []
    }
}

#if os(macOS)
public class DeviceCalendarPluginBase: NSObject {}
#elseif os(iOS)
public class DeviceCalendarPluginBase: NSObject, EKEventViewDelegate, UINavigationControllerDelegate {

    public func eventViewController(_ controller: EKEventViewController, didCompleteWith action: EKEventViewAction) {}
}
#endif

// Singleton implementation for SharedEventStore
class SharedEventStore {
    static let shared = EKEventStore()
}

public class DeviceCalendarPlugin: DeviceCalendarPluginBase, FlutterPlugin {
    struct DeviceCalendar: Codable {
        let id: String
        let name: String
        let isReadOnly: Bool
        let isDefault: Bool
        let color: Int
        let accountName: String
        let accountType: String
    }

    struct Event: Codable {
        let eventId: String
        let calendarId: String
        let eventTitle: String
        let eventDescription: String?
        let eventStartDate: Int64
        let eventEndDate: Int64
        let eventStartTimeZone: String?
        let eventAllDay: Bool
        let attendees: [Attendee]
        let eventLocation: String?
        let eventURL: String?
        let recurrenceRule: RecurrenceRule?
        let organizer: Attendee?
        let reminders: [CalendarReminder]
        let availability: Availability?
        let eventStatus: EventStatus?
        let eventIsDetached: Bool
        let eventOccurrenceDate: Int64
    }

    struct RecurrenceRule: Codable {
        let freq: String
        let count: Int?
        let interval: Int
        let until: String?
        let byday: [String]?
        let bymonthday: [Int]?
        let byyearday: [Int]?
        let byweekno: [Int]?
        let bymonth: [Int]?
        let bysetpos: [Int]?
        let sourceRruleString: String?
    }

    struct Attendee: Codable {
        let name: String?
        let emailAddress: String
        let role: Int
        let attendanceStatus: Int
        let isCurrentUser: Bool
    }

    struct CalendarReminder: Codable {
        let minutes: Int
    }

    enum Availability: String, Codable {
        case BUSY
        case FREE
        case TENTATIVE
        case UNAVAILABLE
    }

    enum EventStatus: String, Codable {
        case CONFIRMED
        case TENTATIVE
        case CANCELED
        case NONE
    }

    // MZ - Added from Reminders Package
    struct Reminder: Codable {
        let list: List
        let id: String
        let title: String
        let dueDate: DateComponents?
        let priority: Int
        let isCompleted: Bool
        let notes: String?

        init(reminder: EKReminder) {
            self.list = List(list: reminder.calendar)
            self.id = reminder.calendarItemIdentifier
            self.title = reminder.title
            self.dueDate = reminder.dueDateComponents
            self.priority = reminder.priority
            self.isCompleted = reminder.isCompleted
            self.notes = reminder.notes
        }

        func toJson() -> String? {
            let jsonData = try? JSONEncoder().encode(self)
            return String(data: jsonData ?? Data(), encoding: .utf8)
        }
    }

    struct List: Codable {
        let title: String
        let id: String

        init(list: EKCalendar) {
            self.title = list.title
            self.id = list.calendarIdentifier
        }

        func toJson() -> String? {
            let jsonData = try? JSONEncoder().encode(self)
            return String(data: jsonData ?? Data(), encoding: .utf8)
        }
    }

    static let channelName = "plugins.builttoroam.com/device_calendar"
    let notFoundErrorCode = "404"
    let notAllowed = "405"
    let genericError = "500"
    let unauthorizedErrorCode = "401"
    let unauthorizedErrorMessage = "The user has not allowed this application to modify their calendar(s)"
    let calendarNotFoundErrorMessageFormat = "The calendar with the ID %@ could not be found"
    let calendarReadOnlyErrorMessageFormat = "Calendar with ID %@ is read-only"
    let eventNotFoundErrorMessageFormat = "The event with the ID %@ could not be found"
    let eventStore = SharedEventStore.shared
    // MZ - Added variable from Reminders Package
    lazy var defaultList: EKCalendar = {
        return eventStore.defaultCalendarForNewReminders() ?? EKCalendar(for: .reminder, eventStore: eventStore)
    }()
    // let getPlatformVersionMethod = "getPlatformVersion"
    let hasAccessMethod = "hasAccess"
    let getPermissionStatusMethod = "getPermissionStatus"
    let requestPermissionMethod = "requestPermission"
    let getDefaultListIdMethod = "getDefaultListId"
    let getDefaultListMethod = "getDefaultList"
    let getAllListsMethod = "getAllLists"
    let getRemindersMethod = "getReminders"
    let saveReminderMethod = "saveReminder"
    let deleteReminderMethod = "deleteReminder"
    //
    let requestPermissionsMethod = "requestPermissions"
    let hasPermissionsMethod = "hasPermissions"
    let retrieveCalendarsMethod = "retrieveCalendars"
    let retrieveEventsMethod = "retrieveEvents"
    let retrieveSourcesMethod = "retrieveSources"
    let createOrUpdateEventMethod = "createOrUpdateEvent"
    let createCalendarMethod = "createCalendar"
    let deleteCalendarMethod = "deleteCalendar"
    let deleteEventMethod = "deleteEvent"
    let deleteEventInstanceMethod = "deleteEventInstance"
    let showEventModalMethod = "showiOSEventModal"
    let startCalendarTrackingMethod = "startCalendarTracking"
    let stopCalendarTrackingMethod = "stopCalendarTracking"
    let calendarIdArgument = "calendarId"
    let startDateArgument = "startDate"
    let endDateArgument = "endDate"
    let eventIdArgument = "eventId"
    let eventIdsArgument = "eventIds"
    let eventTitleArgument = "eventTitle"
    let eventDescriptionArgument = "eventDescription"
    let eventAllDayArgument = "eventAllDay"
    let eventStartDateArgument =  "eventStartDate"
    let eventEndDateArgument = "eventEndDate"
    let eventStartTimeZoneArgument = "eventStartTimeZone"
    let eventLocationArgument = "eventLocation"
    let eventURLArgument = "eventURL"
    let attendeesArgument = "attendees"
    let recurrenceRuleArgument = "recurrenceRule"
    let recurrenceFrequencyArgument = "freq"
    let countArgument = "count"
    let intervalArgument = "interval"
    let untilArgument = "until"
    let byWeekDaysArgument = "byday"
    let byMonthDaysArgument = "bymonthday"
    let byYearDaysArgument = "byyearday"
    let byWeeksArgument = "byweekno"
    let byMonthsArgument = "bymonth"
    let bySetPositionsArgument = "bysetpos"
    let dayArgument = "day"
    let occurrenceArgument = "occurrence"
    let nameArgument = "name"
    let emailAddressArgument = "emailAddress"
    let roleArgument = "role"
    let remindersArgument = "reminders"
    let minutesArgument = "minutes"
    let followingInstancesArgument = "followingInstances"
    let calendarNameArgument = "calendarName"
    let calendarColorArgument = "calendarColor"
    let availabilityArgument = "availability"
    let attendanceStatusArgument = "attendanceStatus"
    let eventStatusArgument = "eventStatus"
    let validFrequencyTypes = [EKRecurrenceFrequency.daily, EKRecurrenceFrequency.weekly, EKRecurrenceFrequency.monthly, EKRecurrenceFrequency.yearly]
    
    var flutterResult : FlutterResult?
    private var eventChangeObserver: NSObjectProtocol?
    private var calendarChannel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
#if os(macOS)
            let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger)
#elseif os(iOS)
            let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
#endif
            let instance = DeviceCalendarPlugin()
            instance.calendarChannel = channel
            registrar.addMethodCallDelegate(instance, channel: channel)
        }

        public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
            switch call.method {
            case requestPermissionsMethod:
                requestPermissions(result)
            case hasPermissionsMethod:
                hasPermissions(result)
            case retrieveCalendarsMethod:
                retrieveCalendars(result)
            case retrieveEventsMethod:
                retrieveEvents(call, result)
            case createOrUpdateEventMethod:
                createOrUpdateEvent(call, result)
            case deleteEventMethod:
                deleteEvent(call, result)
            case deleteEventInstanceMethod:
                deleteEvent(call, result)
            case createCalendarMethod:
                createCalendar(call, result)
            case deleteCalendarMethod:
                deleteCalendar(call, result)
            case startCalendarTrackingMethod:
                startCalendarTracking(result)
            case stopCalendarTrackingMethod:
                stopCalendarTracking(result)
            // MZ - Added from Reminders Package
            case hasAccessMethod:
                result(hasAccess)
            case getPermissionStatusMethod:
                getPermissionStatus(result)
            case requestPermissionMethod:
                requestPermission { granted in
                    result(granted)
                }
            case getDefaultListIdMethod:
                getDefaultListId(result)
            case getDefaultListMethod:
                getDefaultList(result)
            case getAllListsMethod:
                getAllLists(result)
            case getRemindersMethod:
                if let args = call.arguments as? [String: String?] {
                    if let id = args["id"] {
                        getReminders(id, result)
                    }
                }
            case saveReminderMethod:
                if let args = call.arguments as? [String: Any] {
                    if let reminder = args["reminder"] as? [String: Any] {
                        saveReminder(reminder, result)
                    }
                }
            case deleteReminderMethod:
                if let args = call.arguments as? [String: String] {
                    if let id = args["id"] {
                        deleteReminder(id, result)
                    }
                }
            //
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // MZ - Added from Reminders Package
        var hasAccess: Bool {
            return hasReminderPermission()
        }

        private func hasPermissions(_ result: FlutterResult) {
            let hasPermissions = hasEventPermissions()
            result(hasPermissions)
        }

        private func getSource() -> EKSource? {
            // Try to find a local source first
            if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
                return localSource
            }

            // Fall back to the default source for new events
            if let defaultSource = eventStore.defaultCalendarForNewEvents?.source {
                return defaultSource
            }

            // Check for iCloud source
            if let iCloudSource = eventStore.sources.first(where: { $0.sourceType == .calDAV && $0.title == "iCloud" }) {
                return iCloudSource
            }

            // If no source is found, log available sources for debugging
            print("Available sources:")
            for source in eventStore.sources {
                print("Source: \(source.title), Type: \(source.sourceType.rawValue)")
            }

            return nil // No valid source found
        }

        // MZ - Calendar Monitoring Methods
        private func startCalendarTracking(_ result: @escaping FlutterResult) {
            if eventChangeObserver == nil {
                eventChangeObserver = NotificationCenter.default.addObserver(
                    forName: .EKEventStoreChanged,
                    object: eventStore,
                    queue: OperationQueue.main
                ) { [weak self] (notification) in
                    self?.sendEventChangeNotification()
                }
                result(true)
            } else {
                result(false)
            }
        }

        private func stopCalendarTracking(_ result: @escaping FlutterResult) {
            if let observer = eventChangeObserver {
                NotificationCenter.default.removeObserver(observer)
                eventChangeObserver = nil
                result(true)
            } else {
                result(false)
            }
        }

        private func sendEventChangeNotification() {
            // MZ - Notify Flutter about the calendar event changes
            calendarChannel?.invokeMethod("onCalendarEventChange", arguments: nil)
        }

        private func createCalendar(_ call: FlutterMethodCall, _ result: FlutterResult) {
            let arguments = call.arguments as! Dictionary<String, AnyObject>
            let calendar: EKCalendar

            do {
                if #available(iOS 17, macOS 14, *) {
                    // For iOS 17 and macOS 14 or later
                    calendar = EKCalendar(eventStore: eventStore)
                    calendar.entityType = .event
                    // Set the source
                    guard let source = getSource() else {
                        result(FlutterError(code: self.genericError, message: "Failed to find a valid calendar source.", details: nil))
                        return
                    }
                    calendar.source = source
                } else {
                    // For earlier versions
                    calendar = EKCalendar(for: .event, eventStore: eventStore)
                    // Set the source
                    guard let source = getSource() else {
                        result(FlutterError(code: self.genericError, message: "Failed to find a valid calendar source.", details: nil))
                        return
                    }
                    calendar.source = source
                }

                // Set the calendar properties
                calendar.title = arguments[calendarNameArgument] as! String
                if let calendarColor = arguments[calendarColorArgument] as? String,
                   let xColor = XColor(hex: calendarColor) {
                    calendar.cgColor = xColor.cgColor
                } else {
                    // Use full opacity for the default color
                    calendar.cgColor = XColor(red: 1.0, green: 0, blue: 0, alpha: 1.0).cgColor // Default red color
                }

                // Save the calendar
                try eventStore.saveCalendar(calendar, commit: true)
                result(calendar.calendarIdentifier)
            } catch {
                eventStore.reset()
                result(FlutterError(code: self.genericError, message: error.localizedDescription, details: nil))
            }
        }

        private func retrieveCalendars(_ result: @escaping FlutterResult) {
            checkPermissionsThenExecute(permissionsGrantedAction: {
            DispatchQueue.main.async {
                let ekCalendars = self.eventStore.calendars(for: .event)
                let defaultCalendar = self.eventStore.defaultCalendarForNewEvents
                var calendars = [DeviceCalendar]()
                for ekCalendar in ekCalendars {
#if os(macOS)
                    let calendarColor = ekCalendar.color.rgb()!
#elseif os(iOS)
                    let calendarColor = UIColor(cgColor: ekCalendar.cgColor).rgb()!
#endif
                    let calendar = DeviceCalendar(
                        id: ekCalendar.calendarIdentifier,
                        name: ekCalendar.title,
                        isReadOnly: !ekCalendar.allowsContentModifications,
                        isDefault: defaultCalendar?.calendarIdentifier == ekCalendar.calendarIdentifier,
                        color: calendarColor,
                        accountName: ekCalendar.source.title,
                        accountType: self.getAccountType(ekCalendar.source.sourceType))
                    calendars.append(calendar)
                }

                self.encodeJsonAndFinish(codable: calendars, result: result)
            }
            }, result: result)
        }


        private func deleteCalendar(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        checkPermissionsThenExecute(permissionsGrantedAction: { [weak self] in
            guard let self = self else { return }
                let arguments = call.arguments as! Dictionary<String, AnyObject>
            let calendarId = arguments[self.calendarIdArgument] as! String

                let ekCalendar = self.eventStore.calendar(withIdentifier: calendarId)
                if ekCalendar == nil {
                    self.finishWithCalendarNotFoundError(result: result, calendarId: calendarId)
                    return
                }

                if !(ekCalendar!.allowsContentModifications) {
                    self.finishWithCalendarReadOnlyError(result: result, calendarId: calendarId)
                    return
                }

                do {
                    try self.eventStore.removeCalendar(ekCalendar!, commit: true)
                    result(true)
                } catch {
                    self.eventStore.reset()
                    result(FlutterError(code: self.genericError, message: error.localizedDescription, details: nil))
                }
            }, result: result)
        }


        private func getAccountType(_ sourceType: EKSourceType) -> String {
            switch (sourceType) {
            case .local:
                return "Local";
            case .exchange:
                return "Exchange";
            case .calDAV:
                return "CalDAV";
            case .mobileMe:
                return "MobileMe";
            case .subscribed:
                return "Subscribed";
            case .birthdays:
                return "Birthdays";
            default:
                return "Unknown";
            }
        }

    private func retrieveEvents(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        checkPermissionsThenExecute(permissionsGrantedAction: { [weak self] in
            guard let self = self else { return }

            guard let arguments = call.arguments as? [String: AnyObject],
                  let calendarId = arguments[self.calendarIdArgument] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing arguments", details: nil))
                return
            }

            let startDateMillisecondsSinceEpoch = arguments[self.startDateArgument] as? NSNumber
            let endDateMillisecondsSinceEpoch = arguments[self.endDateArgument] as? NSNumber
            let eventIdArgs = arguments[self.eventIdsArgument] as? [String]

            var events = [Event]()

            let specifiedStartEndDates = startDateMillisecondsSinceEpoch != nil && endDateMillisecondsSinceEpoch != nil

            if specifiedStartEndDates {
                let startDate = Date(timeIntervalSince1970: startDateMillisecondsSinceEpoch!.doubleValue / 1000.0)
                let endDate = Date(timeIntervalSince1970: endDateMillisecondsSinceEpoch!.doubleValue / 1000.0)

                if let ekCalendar = self.eventStore.calendar(withIdentifier: calendarId) {
                    let predicate = self.eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [ekCalendar])
                    let ekEvents = self.eventStore.events(matching: predicate)
                    for ekEvent in ekEvents {
                        let event = self.createEventFromEkEvent(calendarId: calendarId, ekEvent: ekEvent)
                        events.append(event)
                    }
                }
            }

            guard let eventIds = eventIdArgs else {
                self.encodeJsonAndFinish(codable: events, result: result)
                return
            }

            if specifiedStartEndDates {
                events = events.filter { e in
                    e.calendarId == calendarId && eventIds.contains(e.eventId)
                }

                self.encodeJsonAndFinish(codable: events, result: result)
                return
            }

            for eventId in eventIds {
                if let ekEvent = self.eventStore.event(withIdentifier: eventId) {
                    let event = self.createEventFromEkEvent(calendarId: calendarId, ekEvent: ekEvent)
                    events.append(event)
                }
            }

            self.encodeJsonAndFinish(codable: events, result: result)
        }, result: result)
    }


    private func createEventFromEkEvent(calendarId: String, ekEvent: EKEvent) -> Event {
        var attendees = [Attendee]()
        if ekEvent.attendees != nil {
            for ekParticipant in ekEvent.attendees! {
                let attendee = convertEkParticipantToAttendee(ekParticipant: ekParticipant)
                if attendee == nil {
                    continue
                }

                attendees.append(attendee!)
            }
        }

        var reminders = [CalendarReminder]()
        if ekEvent.alarms != nil {
            for alarm in ekEvent.alarms! {
                reminders.append(CalendarReminder(minutes: Int(-alarm.relativeOffset / 60)))
            }
        }

        let recurrenceRule = parseEKRecurrenceRules(ekEvent)
        let event = Event(
            eventId: ekEvent.eventIdentifier,
            calendarId: calendarId,
            eventTitle: ekEvent.title ?? "New Event",
            eventDescription: ekEvent.notes,
            eventStartDate: Int64(ekEvent.startDate.millisecondsSinceEpoch),
            eventEndDate: Int64(ekEvent.endDate.millisecondsSinceEpoch),
            eventStartTimeZone: ekEvent.timeZone?.identifier,
            eventAllDay: ekEvent.isAllDay,
            attendees: attendees,
            eventLocation: ekEvent.location,
            eventURL: ekEvent.url?.absoluteString,
            recurrenceRule: recurrenceRule,
            organizer: convertEkParticipantToAttendee(ekParticipant: ekEvent.organizer),
            reminders: reminders,
            availability: convertEkEventAvailability(ekEventAvailability: ekEvent.availability),
            eventStatus: convertEkEventStatus(ekEventStatus: ekEvent.status),
            eventIsDetached: ekEvent.isDetached,
            eventOccurrenceDate: Int64(ekEvent.occurrenceDate.millisecondsSinceEpoch)
        )

        return event
    }

        private func convertEkParticipantToAttendee(ekParticipant: EKParticipant?) -> Attendee? {
            if ekParticipant == nil || ekParticipant?.emailAddress == nil {
                return nil
            }

            let attendee = Attendee(
                name: ekParticipant!.name,
                emailAddress:  ekParticipant!.emailAddress!,
                role: ekParticipant!.participantRole.rawValue,
                attendanceStatus: ekParticipant!.participantStatus.rawValue,
                isCurrentUser: ekParticipant!.isCurrentUser
            )

            return attendee
        }

    private func convertEkEventAvailability(ekEventAvailability: EKEventAvailability?) -> Availability? {
        switch ekEventAvailability {
        case .busy:
            return Availability.BUSY
        case .free:
            return Availability.FREE
        case .tentative:
            return Availability.TENTATIVE
        case .unavailable:
            return Availability.UNAVAILABLE
        default:
            return nil
        }
    }

    private func convertEkEventStatus(ekEventStatus: EKEventStatus?) -> EventStatus? {
        switch ekEventStatus {
        case .confirmed:
            return EventStatus.CONFIRMED
        case .tentative:
            return EventStatus.TENTATIVE
        case .canceled:
            return EventStatus.CANCELED
        case .none?:
            return EventStatus.NONE
        default:
            return nil
        }
    }
    
    private func parseEKRecurrenceRules(_ ekEvent: EKEvent) -> RecurrenceRule? {
        var recurrenceRule: RecurrenceRule?

        // MZ - Added for debugging purposes
        if ekEvent.isDetached {
            print("Debug: The event with ID \(ekEvent.eventIdentifier ?? "unknown") is a detached occurrence from its recurrence rule.")
        }

        if ekEvent.hasRecurrenceRules {
            let ekRecurrenceRule = ekEvent.recurrenceRules![0]
            var frequency: String
            switch ekRecurrenceRule.frequency {
            case EKRecurrenceFrequency.daily:
                frequency = "DAILY"
            case EKRecurrenceFrequency.weekly:
                frequency = "WEEKLY"
            case EKRecurrenceFrequency.monthly:
                frequency = "MONTHLY"
            case EKRecurrenceFrequency.yearly:
                frequency = "YEARLY"
            default:
                frequency = "DAILY"
            }

            var count: Int?
            var endDate: String?
            if(ekRecurrenceRule.recurrenceEnd?.occurrenceCount != nil  && ekRecurrenceRule.recurrenceEnd?.occurrenceCount != 0) {
                count = ekRecurrenceRule.recurrenceEnd?.occurrenceCount
            }

            let endDateRaw = ekRecurrenceRule.recurrenceEnd?.endDate
            if(endDateRaw != nil) {
                endDate = formateDateTime(dateTime: endDateRaw!)
            }

            let byWeekDays = ekRecurrenceRule.daysOfTheWeek
            let byMonthDays = ekRecurrenceRule.daysOfTheMonth
            let byYearDays = ekRecurrenceRule.daysOfTheYear
            let byWeeks = ekRecurrenceRule.weeksOfTheYear
            let byMonths = ekRecurrenceRule.monthsOfTheYear
            let bySetPositions = ekRecurrenceRule.setPositions

            recurrenceRule = RecurrenceRule(
                freq: frequency,
                count: count,
                interval: ekRecurrenceRule.interval,
                until: endDate,
                byday: byWeekDays?.map {weekDayToString($0)},
                bymonthday: byMonthDays?.map {Int(truncating: $0)},
                byyearday: byYearDays?.map {Int(truncating: $0)},
                byweekno: byWeeks?.map {Int(truncating: $0)},
                bymonth: byMonths?.map {Int(truncating: $0)},
                bysetpos: bySetPositions?.map {Int(truncating: $0)},
                sourceRruleString: rruleStringFromEKRRule(ekRecurrenceRule)
            )
        }
        //print("RECURRENCERULE_RESULT: \(recurrenceRule as AnyObject)")
        return recurrenceRule
    }

    private func weekDayToString(_ entry : EKRecurrenceDayOfWeek) -> String {
        let weekNumber = entry.weekNumber
        let day = dayValueToString(entry.dayOfTheWeek.rawValue)
        if (weekNumber == 0) {
            return "\(day)"
        } else {
            return "\(weekNumber)\(day)"
        }
    }

    private func dayValueToString(_ day: Int) -> String {
        switch day {
        case 1: return "SU"
        case 2: return "MO"
        case 3: return "TU"
        case 4: return "WE"
        case 5: return "TH"
        case 6: return "FR"
        case 7: return "SA"
        default: return "SU"
        }
    }

    private func formateDateTime(dateTime: Date) -> String {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        func twoDigits(_ n: Int) -> String {
            if (n < 10) {return "0\(n)"} else {return "\(n)"}
        }

        func fourDigits(_ n: Int) -> String {
            let absolute = abs(n)
            let sign = n < 0 ? "-" : ""
            if (absolute >= 1000) {return "\(n)"}
            if (absolute >= 100) {return "\(sign)0\(absolute)"}
            if (absolute >= 10) {return "\(sign)00\(absolute)"}
            return "\(sign)000\(absolute)"
        }

        let year = calendar.component(.year, from: dateTime)
        let month = calendar.component(.month, from: dateTime)
        let day = calendar.component(.day, from: dateTime)
        let hour = calendar.component(.hour, from: dateTime)
        let minutes = calendar.component(.minute, from: dateTime)
        let seconds = calendar.component(.second, from: dateTime)

        assert(year >= 0 && year <= 9999)

        let yearString = fourDigits(year)
        let monthString = twoDigits(month)
        let dayString = twoDigits(day)
        let hourString = twoDigits(hour)
        let minuteString = twoDigits(minutes)
        let secondString = twoDigits(seconds)
        let utcSuffix = calendar.timeZone == TimeZone(identifier: "UTC") ? "Z" : ""
        return "\(yearString)-\(monthString)-\(dayString)T\(hourString):\(minuteString):\(secondString)\(utcSuffix)"

    }

    private func createEKRecurrenceRules(_ arguments: [String : AnyObject]) -> [EKRecurrenceRule]?{
        let recurrenceRuleArguments = arguments[recurrenceRuleArgument] as? Dictionary<String, AnyObject>

        //print("ARGUMENTS: \(recurrenceRuleArguments as AnyObject)")

        if recurrenceRuleArguments == nil {
            return nil
        }

        let recurrenceFrequency = recurrenceRuleArguments![recurrenceFrequencyArgument] as? String
        let totalOccurrences = recurrenceRuleArguments![countArgument] as? NSInteger
        let interval = recurrenceRuleArguments![intervalArgument] as? NSInteger
        var recurrenceInterval = 1
        var endDate = recurrenceRuleArguments![untilArgument] as? String
        var namedFrequency: EKRecurrenceFrequency
        switch recurrenceFrequency {
        case "YEARLY":
            namedFrequency = EKRecurrenceFrequency.yearly
        case "MONTHLY":
            namedFrequency = EKRecurrenceFrequency.monthly
        case "WEEKLY":
            namedFrequency = EKRecurrenceFrequency.weekly
        case "DAILY":
            namedFrequency = EKRecurrenceFrequency.daily
        default:
            namedFrequency = EKRecurrenceFrequency.daily
        }

        var recurrenceEnd: EKRecurrenceEnd?
        if endDate != nil {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

            if (!endDate!.hasSuffix("Z")){
                endDate!.append("Z")
            }

            let dateTime = dateFormatter.date(from: endDate!)
            if dateTime != nil {
                recurrenceEnd = EKRecurrenceEnd(end: dateTime!)
            }
        } else if(totalOccurrences != nil && totalOccurrences! > 0) {
            recurrenceEnd = EKRecurrenceEnd(occurrenceCount: totalOccurrences!)
        }

        if interval != nil && interval! > 1 {
            recurrenceInterval = interval!
        }

        let byWeekDaysStrings = recurrenceRuleArguments![byWeekDaysArgument] as? [String]
        var byWeekDays = [EKRecurrenceDayOfWeek]()

        if (byWeekDaysStrings != nil) {
            byWeekDaysStrings?.forEach { string in
                let entry = recurrenceDayOfWeekFromString(recDay: string)
                if entry != nil {byWeekDays.append(entry!)}
            }
        }

        let byMonthDays = recurrenceRuleArguments![byMonthDaysArgument] as? [Int]
        let byYearDays = recurrenceRuleArguments![byYearDaysArgument] as? [Int]
        let byWeeks = recurrenceRuleArguments![byWeeksArgument] as? [Int]
        let byMonths = recurrenceRuleArguments![byMonthsArgument] as? [Int]
        let bySetPositions = recurrenceRuleArguments![bySetPositionsArgument] as? [Int]

        let ekrecurrenceRule = EKRecurrenceRule(
            recurrenceWith: namedFrequency,
            interval: recurrenceInterval,
            daysOfTheWeek: byWeekDays.isEmpty ? nil : byWeekDays,
            daysOfTheMonth: byMonthDays?.map {NSNumber(value: $0)},
            monthsOfTheYear: byMonths?.map {NSNumber(value: $0)},
            weeksOfTheYear: byWeeks?.map {NSNumber(value: $0)},
            daysOfTheYear: byYearDays?.map {NSNumber(value: $0)},
            setPositions: bySetPositions?.map {NSNumber(value: $0)},
            end: recurrenceEnd)
        //print("ekrecurrenceRule: \(String(describing: ekrecurrenceRule))")
        return [ekrecurrenceRule]
    }

    private func rruleStringFromEKRRule(_ ekRrule: EKRecurrenceRule) -> String {
        let ekRRuleAnyObject = ekRrule as AnyObject
        var ekRRuleString = "\(ekRRuleAnyObject)"
        if let range = ekRRuleString.range(of: "RRULE ") {
            ekRRuleString = String(ekRRuleString[range.upperBound...])
            //print("EKRULE_RESULT_STRING: \(ekRRuleString)")
        }
        return ekRRuleString
    }

    private func setAttendees(_ arguments: [String : AnyObject], _ ekEvent: EKEvent?) {
        let attendeesArguments = arguments[attendeesArgument] as? [Dictionary<String, AnyObject>]
        if attendeesArguments == nil {
            return
        }

        var attendees = [EKParticipant]()
        for attendeeArguments in attendeesArguments! {
            let name = attendeeArguments[nameArgument] as! String
            let emailAddress = attendeeArguments[emailAddressArgument] as! String
            let role = attendeeArguments[roleArgument] as! Int

            if (ekEvent!.attendees != nil) {
                let existingAttendee = ekEvent!.attendees!.first { element in
                    return element.emailAddress == emailAddress
                }
                if existingAttendee != nil && ekEvent!.organizer?.emailAddress != existingAttendee?.emailAddress{
                    attendees.append(existingAttendee!)
                    continue
                }
            }

            let attendee = createParticipant(
                name: name,
                emailAddress: emailAddress,
                role: role)

            if (attendee == nil) {
                continue
            }

            attendees.append(attendee!)
        }

        ekEvent!.setValue(attendees, forKey: "attendees")
    }

    private func createReminders(_ arguments: [String : AnyObject]) -> [EKAlarm]?{
        let remindersArguments = arguments[remindersArgument] as? [Dictionary<String, AnyObject>]
        if remindersArguments == nil {
            return nil
        }

        var reminders = [EKAlarm]()
        for reminderArguments in remindersArguments! {
            let minutes = reminderArguments[minutesArgument] as! Int
            reminders.append(EKAlarm.init(relativeOffset: 60 * Double(-minutes)))
        }

        return reminders
    }

    private func recurrenceDayOfWeekFromString(recDay: String) -> EKRecurrenceDayOfWeek? {
        let results = recDay.match("(?:(\\+|-)?([0-9]{1,2}))?([A-Za-z]{2})").first
        var recurrenceDayOfWeek : EKRecurrenceDayOfWeek?
        if (results != nil) {
            var occurrence : Int?
            let numberMatch = results![2]
            if (!numberMatch.isEmpty) {
                occurrence = Int(numberMatch)
                if (1 > occurrence! || occurrence! > 53) {
                    print("OCCURRENCE_ERROR: OUT OF RANGE -> \(String(describing: occurrence))")
                }
                if (results![1] == "-") {
                    occurrence = -occurrence!
                }
            }
            let dayMatch = results![3]

            var weekday = EKWeekday.monday

            switch dayMatch {
            case "MO":
                weekday = EKWeekday.monday
            case "TU":
                weekday = EKWeekday.tuesday
            case "WE":
                weekday = EKWeekday.wednesday
            case "TH":
                weekday = EKWeekday.thursday
            case "FR":
                weekday = EKWeekday.friday
            case "SA":
                weekday = EKWeekday.saturday
            case "SU":
                weekday = EKWeekday.sunday
            default:
                weekday = EKWeekday.sunday
            }

            if occurrence != nil {
                recurrenceDayOfWeek = EKRecurrenceDayOfWeek(dayOfTheWeek: weekday, weekNumber: occurrence!)
            } else {
                recurrenceDayOfWeek = EKRecurrenceDayOfWeek(weekday)
            }
        }
        return recurrenceDayOfWeek
    }


    private func setAvailability(_ arguments: [String : AnyObject]) -> EKEventAvailability? {
        guard let availabilityValue = arguments[availabilityArgument] as? String else {
            return .unavailable
        }

        switch availabilityValue.uppercased() {
        case Availability.BUSY.rawValue:
            return .busy
        case Availability.FREE.rawValue:
            return .free
        case Availability.TENTATIVE.rawValue:
            return .tentative
        case Availability.UNAVAILABLE.rawValue:
            return .unavailable
        default:
            return nil
        }
    }

    private func createOrUpdateEvent(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        checkPermissionsThenExecute(permissionsGrantedAction: { [weak self] in
            guard let self = self else { return }
            let arguments = call.arguments as! Dictionary<String, AnyObject>
            let calendarId = arguments[self.calendarIdArgument] as! String
            let eventId = arguments[self.eventIdArgument] as? String
            let isAllDay = arguments[self.eventAllDayArgument] as! Bool
            let startDateMillisecondsSinceEpoch = arguments[self.eventStartDateArgument] as! NSNumber
            let endDateDateMillisecondsSinceEpoch = arguments[self.eventEndDateArgument] as! NSNumber
            let startDate = Date (timeIntervalSince1970: startDateMillisecondsSinceEpoch.doubleValue / 1000.0)
            let endDate = Date (timeIntervalSince1970: endDateDateMillisecondsSinceEpoch.doubleValue / 1000.0)
            let startTimeZoneString = arguments[self.eventStartTimeZoneArgument] as? String
            let title = arguments[self.eventTitleArgument] as! String
            let description = arguments[self.eventDescriptionArgument] as? String
            let location = arguments[self.eventLocationArgument] as? String
            let url = arguments[self.eventURLArgument] as? String
            let ekCalendar = self.eventStore.calendar(withIdentifier: calendarId)
            if (ekCalendar == nil) {
                self.finishWithCalendarNotFoundError(result: result, calendarId: calendarId)
                return
            }

            if !(ekCalendar!.allowsContentModifications) {
                self.finishWithCalendarReadOnlyError(result: result, calendarId: calendarId)
                return
            }

            var ekEvent: EKEvent?
            if eventId == nil {
                ekEvent = EKEvent.init(eventStore: self.eventStore)
            } else {
                ekEvent = self.eventStore.event(withIdentifier: eventId!)
                if(ekEvent == nil) {
                    self.finishWithEventNotFoundError(result: result, eventId: eventId!)
                    return
                }
            }

            ekEvent!.title = title
            ekEvent!.notes = description
            ekEvent!.isAllDay = isAllDay
            ekEvent!.startDate = startDate
            ekEvent!.endDate = endDate
            
            if (!isAllDay) { 
                let timeZone = TimeZone(identifier: startTimeZoneString ?? TimeZone.current.identifier) ?? .current
                ekEvent!.timeZone = timeZone
            }
            
            ekEvent!.calendar = ekCalendar!
            ekEvent!.location = location

            // Create and add URL object only when if the input string is not empty or nil
            if let urlCheck = url, !urlCheck.isEmpty {
                let iosUrl = URL(string: url ?? "")
                ekEvent!.url = iosUrl
            }
            else {
                ekEvent!.url = nil
            }

            ekEvent!.recurrenceRules = self.createEKRecurrenceRules(arguments)
            self.setAttendees(arguments, ekEvent)
            ekEvent!.alarms = self.createReminders(arguments)

            if let availability = self.setAvailability(arguments) {
                ekEvent!.availability = availability
            }

            do {
                try self.eventStore.save(ekEvent!, span: .futureEvents)
                result(ekEvent!.eventIdentifier)
            } catch {
                self.eventStore.reset()
                result(FlutterError(code: self.genericError, message: error.localizedDescription, details: nil))
            }
        }, result: result)
    }

    private func createParticipant(name: String, emailAddress: String, role: Int) -> EKParticipant? {
        let ekAttendeeClass: AnyClass? = NSClassFromString("EKAttendee")
        if let type = ekAttendeeClass as? NSObject.Type {
            let participant = type.init()
            participant.setValue(UUID().uuidString, forKey: "UUID")
            participant.setValue(name, forKey: "displayName")
            participant.setValue(emailAddress, forKey: "emailAddress")
            participant.setValue(role, forKey: "participantRole")
            return participant as? EKParticipant
        }
        return nil
    }

    private func deleteEvent(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        checkPermissionsThenExecute(permissionsGrantedAction: { [weak self] in
            guard let self = self else { return }
            let arguments = call.arguments as! Dictionary<String, AnyObject>
            let calendarId = arguments[self.calendarIdArgument] as! String
            let eventId = arguments[self.eventIdArgument] as! String
            let startDateNumber = arguments[self.eventStartDateArgument] as? NSNumber
            let endDateNumber = arguments[self.eventEndDateArgument] as? NSNumber
            let followingInstances = arguments[self.followingInstancesArgument] as? Bool

            let ekCalendar = self.eventStore.calendar(withIdentifier: calendarId)
            if ekCalendar == nil {
                self.finishWithCalendarNotFoundError(result: result, calendarId: calendarId)
                return
            }

            if !(ekCalendar!.allowsContentModifications) {
                self.finishWithCalendarReadOnlyError(result: result, calendarId: calendarId)
                return
            }

            if (startDateNumber == nil && endDateNumber == nil && followingInstances == nil) {
                let ekEvent = self.eventStore.event(withIdentifier: eventId)
                if ekEvent == nil {
                    self.finishWithEventNotFoundError(result: result, eventId: eventId)
                    return
                }

                do {
                    try self.eventStore.remove(ekEvent!, span: .futureEvents)
                    result(true)
                } catch {
                    self.eventStore.reset()
                    result(FlutterError(code: self.genericError, message: error.localizedDescription, details: nil))
                }
            }
            else {
                let startDate = Date (timeIntervalSince1970: startDateNumber!.doubleValue / 1000.0)
                let endDate = Date (timeIntervalSince1970: endDateNumber!.doubleValue / 1000.0)

                let predicate = self.eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
                let foundEkEvents = self.eventStore.events(matching: predicate) as [EKEvent]?

                if foundEkEvents == nil || foundEkEvents?.count == 0 {
                    self.finishWithEventNotFoundError(result: result, eventId: eventId)
                    return
                }

                let ekEvent = foundEkEvents!.first(where: {$0.eventIdentifier == eventId})

                do {
                    if (!followingInstances!) {
                        try self.eventStore.remove(ekEvent!, span: .thisEvent, commit: true)
                    }
                    else {
                        try self.eventStore.remove(ekEvent!, span: .futureEvents, commit: true)
                    }

                    result(true)
                } catch {
                    self.eventStore.reset()
                    result(FlutterError(code: self.genericError, message: error.localizedDescription, details: nil))
                }
            }
        }, result: result)
    }

    private func showEventModal(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
#if os(iOS)
        checkPermissionsThenExecute(permissionsGrantedAction: { [weak self] in
            guard let self = self else { return }
                let arguments = call.arguments as! Dictionary<String, AnyObject>
            let eventId = arguments[self.eventIdArgument] as! String
                let event = self.eventStore.event(withIdentifier: eventId)

                if event != nil {
                    let eventController = EKEventViewController()
                    eventController.event = event!
                    eventController.delegate = self
                    eventController.allowsEditing = true
                    eventController.allowsCalendarPreview = true

                let flutterViewController = self.getTopMostViewController()
                    let navigationController = UINavigationController(rootViewController: eventController)

                    navigationController.toolbar.isTranslucent = false
                    navigationController.toolbar.tintColor = .blue
                    navigationController.toolbar.backgroundColor = .white

                    flutterViewController.present(navigationController, animated: true, completion: nil)


                } else {
                    result(FlutterError(code: self.genericError, message: self.eventNotFoundErrorMessageFormat, details: nil))
                }
            }, result: result)
#endif
        }

#if os(iOS)
        override public func eventViewController(_ controller: EKEventViewController, didCompleteWith action: EKEventViewAction) {
            controller.dismiss(animated: true, completion: nil)

            if flutterResult != nil {
                switch action {
                case .done:
                    flutterResult!(nil)
                case .responded:
                    flutterResult!(nil)
                case .deleted:
                    flutterResult!(nil)
                @unknown default:
                    flutterResult!(nil)
                }
            }
        }

        private func getTopMostViewController() -> UIViewController {
             var topController: UIViewController? = UIApplication.shared.keyWindow?.rootViewController
             while ((topController?.presentedViewController) != nil) {
               topController = topController?.presentedViewController
             }

             return topController!
        }
#endif

    private func finishWithUnauthorizedError(result: @escaping FlutterResult) {
        result(FlutterError(code:self.unauthorizedErrorCode, message: self.unauthorizedErrorMessage, details: nil))
    }

    private func finishWithCalendarNotFoundError(result: @escaping FlutterResult, calendarId: String) {
        let errorMessage = String(format: self.calendarNotFoundErrorMessageFormat, calendarId)
        result(FlutterError(code:self.notFoundErrorCode, message: errorMessage, details: nil))
    }

    private func finishWithCalendarReadOnlyError(result: @escaping FlutterResult, calendarId: String) {
        let errorMessage = String(format: self.calendarReadOnlyErrorMessageFormat, calendarId)
        result(FlutterError(code:self.notAllowed, message: errorMessage, details: nil))
    }

    private func finishWithEventNotFoundError(result: @escaping FlutterResult, eventId: String) {
        let errorMessage = String(format: self.eventNotFoundErrorMessageFormat, eventId)
        result(FlutterError(code:self.notFoundErrorCode, message: errorMessage, details: nil))
    }

    private func encodeJsonAndFinish<T: Codable>(codable: T, result: @escaping FlutterResult) {
        do {
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(codable)
            let jsonString = String(data: jsonData, encoding: .utf8)
            print("JSON: \(jsonString ?? "nil")")
            result(jsonString)
        } catch {
            result(FlutterError(code: genericError, message: error.localizedDescription, details: nil))
        }
    }

    private func checkPermissionsThenExecute(permissionsGrantedAction: @escaping () -> Void, result: @escaping FlutterResult) {
        print("Checking permissions...")
        if hasEventPermissions() {
            print("Permissions already granted.")
            DispatchQueue.main.async {
                permissionsGrantedAction()
            }
        } else {
            print("Requesting permissions...")
            requestPermissions { [weak self] accessGranted in
                guard let self = self else { 
                    print("Self is nil, aborting.")
                    return 
                }
                DispatchQueue.main.async {
                    if accessGranted {
                        print("Permissions granted.")
                        permissionsGrantedAction()
                    } else {
                        print("Permissions not granted.")
                        self.finishWithUnauthorizedError(result: result)
                    }
                }
            }
        }
    }

    private func requestPermissions(_ completion: @escaping (Bool) -> Void) {
        if hasEventPermissions() {
            print("Permissions already granted (checked in requestPermissions).")
            completion(true)
            return
        }
        if #available(iOS 17, macOS 14.0, *) {
            print("Requesting full access to events for iOS 17 or later...")
            Task {
                do {
                    try await eventStore.requestFullAccessToEvents()
                    DispatchQueue.main.async {
                        let status = EKEventStore.authorizationStatus(for: .event)
                        let accessGranted = (status == .fullAccess)
                        print("Full access request status: \(status.rawValue), access granted: \(accessGranted)")
                        completion(accessGranted)
                    }
                } catch {
                    print("Error requesting full access: \(error)")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }
        } else {
            print("Requesting access to events for iOS versions prior to 17...")
            eventStore.requestAccess(to: .event) { (accessGranted: Bool, error: Error?) in
                if let error = error {
                    print("Error requesting access: \(error)")
                }
                print("Access granted: \(accessGranted)")
                DispatchQueue.main.async {
                    completion(accessGranted)
                }
            }
        }
    }

    private func hasEventPermissions() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, macOS 14.0, *) {
            return status == .fullAccess || status == .authorized
        } else {
            return status == .authorized
        }
    }

    // MZ - Reminder Package Methods
    private func getDefaultList(_ result: @escaping FlutterResult) {
        // Since defaultList is not optional, directly return its JSON representation
        if let json = List(list: defaultList).toJson() {
            result(json)
        } else {
            result(FlutterError(code: "JSON_ERROR", message: "Failed to convert default list to JSON", details: nil))
        }
    }

    private func getDefaultListId(_ result: @escaping FlutterResult) {
        result(defaultList.calendarIdentifier)
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        if hasReminderPermission() {
            print("Permission already granted.")
            completion(true)
            return
        }

        if #available(iOS 17.0, macOS 14.0, *) {
            print("Requesting full access to reminders for iOS 17.0+ or macOS 14.0+.")
            Task {
                do {
                    let accessGranted = try await eventStore.requestFullAccessToReminders()
                    DispatchQueue.main.async {
                        let status = EKEventStore.authorizationStatus(for: .reminder)
                        print("Full access request completed. Access granted: \(accessGranted). Authorization status: \(status.rawValue)")
                        completion(accessGranted)
                    }
                } catch {
                    print("Failed to request full access to reminders with error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }
        } else {
            print("Requesting access to reminders for earlier versions.")
            eventStore.requestAccess(to: .reminder) { (accessGranted: Bool, error: Error?) in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Failed to request access to reminders with error: \(error.localizedDescription)")
                    } else {
                        let status = EKEventStore.authorizationStatus(for: .reminder)
                        print("Access request completed. Access granted: \(accessGranted). Authorization status: \(status.rawValue)")
                    }
                    completion(accessGranted)
                }
            }
        }
    }

    private func hasReminderPermission() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if #available(iOS 17.0, macOS 14.0, *) {
            let hasPermission = (status == .fullAccess)
            print("Authorization status for iOS 17.0+ or macOS 14.0+: \(status). Has permission: \(hasPermission)")
            return hasPermission
        } else {
            let hasPermission = (status == .authorized)
            print("Authorization status for earlier versions: \(status). Has permission: \(hasPermission)")
            return hasPermission
        }
    }

    private func getAllLists(_ result: @escaping FlutterResult) {
        let lists = eventStore.calendars(for: .reminder)
        let jsonData = try? JSONEncoder().encode(lists.map { List(list: $0) })
        if let jsonData = jsonData {
            result(String(data: jsonData, encoding: .utf8))
        } else {
            result(FlutterError(code: "JSON_ERROR", message: "Failed to convert lists to JSON", details: nil))
        }
    }

    private func getReminders(_ id: String?, _ result: @escaping FlutterResult) {
        var calendar: [EKCalendar]? = nil
        if let id = id {
            calendar = [eventStore.calendar(withIdentifier: id) ?? EKCalendar()]
        }
        let predicate: NSPredicate? = eventStore.predicateForReminders(in: calendar)
        if let predicate = predicate {
            eventStore.fetchReminders(matching: predicate) { reminders in
                let rems = reminders ?? []
                let resultArray = rems.map { Reminder(reminder: $0) }
                let json = try? JSONEncoder().encode(resultArray)
                result(String(data: json ?? Data(), encoding: .utf8))
            }
        } else {
            result(FlutterError(code: "PREDICATE_ERROR", message: "Failed to create predicate for reminders", details: nil))
        }
    }

    private func saveReminder(_ json: [String: Any], _ result: @escaping FlutterResult) {
        let reminder: EKReminder

        guard let calendarID = json["list"] as? String,
            let list = eventStore.calendar(withIdentifier: calendarID) else {
            result(FlutterError(code: "INVALID_CALENDAR_ID", message: "Invalid calendarID", details: nil))
            return
        }

        if let reminderID = json["id"] as? String,
        let existingReminder = eventStore.calendarItem(withIdentifier: reminderID) as? EKReminder {
            reminder = existingReminder
        } else {
            reminder = EKReminder(eventStore: eventStore)
        }

        reminder.calendar = list
        reminder.title = json["title"] as? String ?? ""
        reminder.priority = json["priority"] as? Int ?? 0
        reminder.isCompleted = json["isCompleted"] as? Bool ?? false
        reminder.notes = json["notes"] as? String
        if let date = json["dueDate"] as? [String: Int] {
            reminder.dueDateComponents = DateComponents(year: date["year"], month: date["month"], day: date["day"])
        } else {
            reminder.dueDateComponents = nil
        }

        do {
            try eventStore.save(reminder, commit: true)
            result(reminder.calendarItemIdentifier)
        } catch {
            result(FlutterError(code: "SAVE_ERROR", message: "Failed to save reminder", details: error.localizedDescription))
        }
    }

    private func deleteReminder(_ id: String, _ result: @escaping FlutterResult) {
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            result(FlutterError(code: "NOT_FOUND", message: "Cannot find reminder with ID: \(id)", details: nil))
            return
        }

        do {
            try eventStore.remove(reminder, commit: true)
            result(nil)
        } catch {
            result(FlutterError(code: "DELETE_ERROR", message: "Failed to delete reminder", details: error.localizedDescription))
        }
    }

    private func getPermissionStatus(_ result: @escaping FlutterResult) {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .authorized:
            result("authorized")
        case .denied:
            result("denied")
        case .notDetermined:
            result("notDetermined")
        case .restricted:
            result("restricted")
        case .fullAccess:
            result("fullAccess")
        case .writeOnly:
            result("writeOnly")
        @unknown default:
            result("unknown")
        }
    }
}

extension Date {
    func convert(from initTimeZone: TimeZone, to targetTimeZone: TimeZone) -> Date {
        let delta = TimeInterval(initTimeZone.secondsFromGMT() - targetTimeZone.secondsFromGMT())
        return addingTimeInterval(delta)
    }
}

extension XColor {
#if os(macOS)
    func rgb() -> Int? {
        let ciColor:CIColor = CIColor(color: self)!
        let fRed : CGFloat = ciColor.red
        let fGreen : CGFloat = ciColor.green
        let fBlue : CGFloat = ciColor.blue
        let fAlpha: CGFloat = ciColor.alpha

        let iRed = Int(fRed * 255.0)
        let iGreen = Int(fGreen * 255.0)
        let iBlue = Int(fBlue * 255.0)
        let iAlpha = Int(fAlpha * 255.0)

        //  (Bits 24-31 are alpha, 16-23 are red, 8-15 are green, 0-7 are blue).
        let rgb = (iAlpha << 24) + (iRed << 16) + (iGreen << 8) + iBlue
        return rgb
    }
#elseif os(iOS)
    func rgb() -> Int? {
        var fRed : CGFloat = 0
        var fGreen : CGFloat = 0
        var fBlue : CGFloat = 0
        var fAlpha: CGFloat = 0
        if self.getRed(&fRed, green: &fGreen, blue: &fBlue, alpha: &fAlpha) {
            let iRed = Int(fRed * 255.0)
            let iGreen = Int(fGreen * 255.0)
            let iBlue = Int(fBlue * 255.0)
            let iAlpha = Int(fAlpha * 255.0)

            //  (Bits 24-31 are alpha, 16-23 are red, 8-15 are green, 0-7 are blue).
            let rgb = (iAlpha << 24) + (iRed << 16) + (iGreen << 8) + iBlue
            return rgb
        } else {
            // Could not extract RGBA components:
            return nil
        }
    }
#endif

    public convenience init?(hex: String) {
        let r, g, b, a: CGFloat

        if hex.hasPrefix("0x") {
            let start = hex.index(hex.startIndex, offsetBy: 2)
            let hexColor = String(hex[start...])

            if hexColor.count == 8 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    a = CGFloat((hexNumber & 0xff000000) >> 24) / 255
                    r = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
                    b = CGFloat((hexNumber & 0x000000ff)) / 255

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }

        return nil
    }

}
