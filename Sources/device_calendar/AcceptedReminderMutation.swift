import EventKit
import Foundation

#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

extension DeviceCalendarPlugin {
    func handleReminderMutation(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let generation = arguments["generation"] as? String else {
            result(FlutterError(
                code: ReminderMutationError.invalid.rawValue, message: "Missing mutation generation", details: nil
            ))
            return
        }
        eventKitQueue.async { [self] in
            do {
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
            try reminderMutationAuthority.accept(generation: generation, id: id)
        case "finishReminderMutation":
            reminderMutationAuthority.finish(generation: generation, id: id)
        case "updateReminderFields":
            return try updateAcceptedReminder(arguments, generation: generation, attempt: id)
        default:
            throw ReminderMutationError.invalid
        }
        return nil
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
        if owned.contains("title") { reminder.title = parsed.title! }
        if owned.contains("notes") { reminder.notes = parsed.notes }
        if owned.contains("isCompleted") { reminder.isCompleted = parsed.completed! }
        if owned.contains("dueDate") { reminder.dueDateComponents = parsed.due }
        try eventStore.save(reminder, commit: true)
        return true
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
