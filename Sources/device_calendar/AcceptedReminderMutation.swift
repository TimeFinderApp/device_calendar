import EventKit
import Foundation

#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

extension DeviceCalendarPlugin {
    static func reminderLifetime(_ reminder: EKReminder) -> String? {
        reminder.creationDate.map { String($0.timeIntervalSinceReferenceDate.bitPattern, radix: 16) }
    }

    func handleReminderMutation(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        if call.method == "getReminderStoreIdentity" {
            eventKitQueue.async { [self] in
                eventStore.refreshSourcesIfNecessary()
                let identity = eventStore.eventStoreIdentifier
                DispatchQueue.main.async { result(identity) }
            }
            return
        }
        guard let arguments = call.arguments as? [String: Any],
              let generation = arguments["generation"] as? String else {
            result(FlutterError(
                code: ReminderMutationError.invalid.rawValue, message: "Missing mutation generation", details: nil
            ))
            return
        }
        eventKitQueue.async { [self] in
            do {
                if call.method == "createReminderForTask" {
                    try createAcceptedReminder(arguments, generation: generation, result: result)
                    return
                }
                let response = try performReminderMutation(call.method, arguments, generation: generation)
                let reply = response
                DispatchQueue.main.async { result(reply) }
            } catch let error as ReminderMutationError {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: error.rawValue, message: "Reminder mutation authority refused", details: nil
                    ))
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "SAVE_ERROR", message: "Reminder update refused", details: error.localizedDescription
                    ))
                }
            }
        }
    }

    private func performReminderMutation(
        _ method: String, _ arguments: [String: Any], generation: String
    ) throws -> Any? {
        if method == "beginReminderMutations" {
            try reminderMutationAuthority.begin(generation)
            return nil
        }
        if method == "endReminderMutations" {
            reminderMutationAuthority.end(generation)
            return nil
        }
        guard let id = arguments["attempt"] as? String else { throw ReminderMutationError.invalid }
        switch method {
        case "registerReminderMutation":
            guard let entity = arguments["entity"] as? String,
                  let revision = arguments["revision"] as? Int,
                  let fields = arguments["fields"] as? [String] else { throw ReminderMutationError.invalid }
            try reminderMutationAuthority.register(
                generation: generation, id: id, entity: entity, revision: revision, fields: Set(fields)
            )
        case "acceptReminderMutation":
            try reminderMutationAuthority.accept(
                generation: generation, id: id, fields: (arguments["fields"] as? [String]).map(Set.init)
            )
        case "finishReminderMutation":
            reminderMutationAuthority.finish(generation: generation, id: id)
        case "updateReminderFields":
            return try updateAcceptedReminder(arguments, generation: generation, attempt: id)
        case "deleteReminderForTask":
            return try deleteAcceptedReminder(arguments, generation: generation, attempt: id)
        default:
            throw ReminderMutationError.invalid
        }
        return nil
    }

    private func deleteAcceptedReminder(
        _ arguments: [String: Any], generation: String, attempt: String
    ) throws -> Bool {
        guard let reminderId = arguments["id"] as? String, !reminderId.isEmpty,
              let list = arguments["list"] as? String, !list.isEmpty else { throw ReminderMutationError.invalid }
        guard try reminderMutationAuthority.consumeDeletion(generation: generation, id: attempt) else { return false }
        eventStore.refreshSourcesIfNecessary()
        guard let reminder = eventStore.calendarItem(withIdentifier: reminderId) as? EKReminder else { return true }
        guard reminder.calendar.calendarIdentifier == list else { throw ReminderMutationError.retired }
        if let lifetime = arguments["lifetime"] as? String,
           Self.reminderLifetime(reminder) != lifetime { throw ReminderMutationError.retired }
        try eventStore.remove(reminder, commit: true)
        return true
    }

    private func createAcceptedReminder(
        _ arguments: [String: Any], generation: String, result: @escaping FlutterResult
    ) throws {
        guard let attempt = arguments["attempt"] as? String else { throw ReminderMutationError.invalid }
        let creation = try AcceptedReminderCreation(arguments)
        eventStore.refreshSourcesIfNecessary()
        eventStore.fetchReminders(matching: eventStore.predicateForReminders(in: nil)) { [self] reminders in
            eventKitQueue.async { [self] in
                do {
                    eventStore.refreshSourcesIfNecessary()
                    guard let reminders else { throw ReminderMutationError.invalid }
                    let fields = try reminderMutationAuthority.consumeCreation(
                        generation: generation, id: attempt, fields: creation.adoptedFields
                    )
                    let id = try materializeReminder(creation, reminders: reminders, fields: fields)
                    DispatchQueue.main.async { result(id) }
                } catch {
                    let code = (error as? ReminderMutationError)?.rawValue ?? "SAVE_ERROR"
                    DispatchQueue.main.async {
                        result(FlutterError(code: code, message: "Reminder creation refused", details: nil))
                    }
                }
            }
        }
    }

    private func materializeReminder(
        _ creation: AcceptedReminderCreation, reminders: [EKReminder], fields: Set<String>
    ) throws -> String {
        guard let calendar = eventStore.calendar(withIdentifier: creation.list) else {
            throw ReminderMutationError.retired
        }
        let existing = creation.existingId.flatMap { eventStore.calendarItem(withIdentifier: $0) as? EKReminder }
        let matches = existing.map { [$0] } ?? reminders.filter { $0.url == creation.url }
        guard matches.count <= 1 else { throw ReminderMutationError.invalid }
        let reminder: EKReminder
        if let match = matches.first {
            guard let existing = eventStore.calendarItem(
                withIdentifier: match.calendarItemIdentifier
            ) as? EKReminder, existing.calendar.calendarIdentifier == creation.list else {
                throw ReminderMutationError.retired
            }
            if creation.existingId != nil, let lifetime = creation.lifetime,
               Self.reminderLifetime(existing) != lifetime { throw ReminderMutationError.retired }
            reminder = existing
            // A recovered identity retains external fields; only a fresh
            // accepted field grant can update it after creation.
            applyReminderFields(creation.adoption, to: reminder, fields: fields)
            if !fields.isEmpty { try eventStore.save(reminder, commit: true) }
        } else {
            reminder = EKReminder(eventStore: eventStore)
            reminder.calendar = calendar
            applyReminderFields(
                creation.baseline, to: reminder, fields: ["title", "notes", "isCompleted", "dueDate"]
            )
            reminder.url = creation.url
            try eventStore.save(reminder, commit: true)
        }
        return reminder.calendarItemIdentifier
    }

    private func applyReminderFields(_ values: AcceptedReminderFields, to reminder: EKReminder, fields: Set<String>) {
        if fields.contains("title") { reminder.title = values.title! }
        if fields.contains("notes") { reminder.notes = values.notes }
        if fields.contains("isCompleted") { reminder.isCompleted = values.completed! }
        if fields.contains("dueDate") { reminder.dueDateComponents = values.due }
    }

    private func updateAcceptedReminder(
        _ arguments: [String: Any], generation: String, attempt: String
    ) throws -> Bool {
        guard let id = arguments["id"] as? String, !id.isEmpty,
              let list = arguments["list"] as? String, !list.isEmpty,
              let values = arguments["values"] as? [String: Any] else { throw ReminderMutationError.invalid }
        let parsed = try AcceptedReminderFields(values)
        let owned = try reminderMutationAuthority.consume(generation: generation, id: attempt, fields: Set(values.keys))
        if owned.isEmpty { return false }
        // Lookup belongs immediately beside the save; Dart read/merge results
        // cannot preserve external EventKit edits during asynchronous preparation.
        eventStore.refreshSourcesIfNecessary()
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder,
              reminder.calendar.calendarIdentifier == list else { throw ReminderMutationError.retired }
        if let lifetime = arguments["lifetime"] as? String,
           Self.reminderLifetime(reminder) != lifetime { throw ReminderMutationError.retired }
        applyReminderFields(parsed, to: reminder, fields: owned)
        try eventStore.save(reminder, commit: true)
        return true
    }
}

private struct AcceptedReminderCreation {
    let list: String
    let url: URL
    let baseline: AcceptedReminderFields
    let adoption: AcceptedReminderFields
    let adoptedFields: Set<String>
    let existingId: String?
    let lifetime: String?

    init(_ arguments: [String: Any]) throws {
        guard let list = arguments["list"] as? String,
              let marker = arguments["marker"] as? String,
              marker.hasPrefix("timefinder://reminder/"),
              marker.count == "timefinder://reminder/".count + 64,
              let url = URL(string: marker),
              let values = arguments["values"] as? [String: Any],
              Set(values.keys) == Set(["title", "notes", "isCompleted", "dueDate"]) else {
            throw ReminderMutationError.invalid
        }
        existingId = arguments["existingId"] as? String
        lifetime = arguments["lifetime"] as? String
        self.list = list
        self.url = url
        baseline = try AcceptedReminderFields(values)
        let fields = arguments["adoptValues"] as? [String: Any] ?? [:]
        adoption = try AcceptedReminderFields(fields)
        adoptedFields = Set(fields.keys)
    }
}

private struct AcceptedReminderFields {
    let title: String?
    let notes: String?
    let completed: Bool?
    let due: DateComponents?

    init(_ values: [String: Any]) throws {
        title = values["title"] as? String
        notes = values["notes"] as? String
        completed = values["isCompleted"] as? Bool
        if values.keys.contains("title"), title == nil { throw ReminderMutationError.invalid }
        if let note = values["notes"], !(note is NSNull), notes == nil { throw ReminderMutationError.invalid }
        if values.keys.contains("isCompleted"), completed == nil { throw ReminderMutationError.invalid }
        if let date = values["dueDate"], !(date is NSNull) {
            guard let fields = date as? [String: Any],
                  let year = fields["year"] as? Int,
                  let month = fields["month"] as? Int,
                  let day = fields["day"] as? Int,
                  let hasTime = fields["hasTime"] as? Bool,
                  (1...12).contains(month), (1...31).contains(day) else { throw ReminderMutationError.invalid }
            let hour = fields["hour"] as? Int ?? 0
            let minute = fields["minute"] as? Int ?? 0
            guard (0...23).contains(hour), (0...59).contains(minute) else { throw ReminderMutationError.invalid }
            due = DateComponents(
                year: year, month: month, day: day, hour: hasTime ? hour : nil, minute: hasTime ? minute : nil
            )
        } else {
            due = nil
        }
    }
}
