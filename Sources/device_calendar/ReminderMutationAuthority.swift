import Foundation

enum ReminderMutationError: String, Error {
    case invalid = "INVALID_REMINDER_MUTATION"
    case retired = "RETIRED_REMINDER_MUTATION"
    case capacity = "REMINDER_MUTATION_CAPACITY"
}

// Confined to the plugin's existing EventKit queue. These are publication grants,
// not another Task command queue or a source of write/retry authority.
final class ReminderMutationAuthority {
    private struct Attempt {
        let entity: String
        let revision: Int
        let fields: Set<String>
        var accepted = false
        var consumed = false
    }

    private(set) var generation: String?
    private var attempts: [String: Attempt] = [:]
    private var fences: [String: [String: Int]] = [:]
    private let supportedFields: Set<String> = ["title", "notes", "dueDate", "isCompleted"]

    func begin(_ value: String) throws {
        guard !value.isEmpty else { throw ReminderMutationError.invalid }
        guard generation != value else { return }
        generation = value
        attempts.removeAll()
        fences.removeAll()
    }

    func end(_ value: String) {
        guard generation == value else { return }
        generation = nil
        attempts.removeAll()
        fences.removeAll()
    }

    func register(generation: String, id: String, entity: String, revision: Int, fields: Set<String>) throws {
        try requireGeneration(generation)
        guard !id.isEmpty, !entity.isEmpty, revision > 0,
              !fields.isEmpty, fields.isSubset(of: supportedFields), attempts[id] == nil else {
            throw ReminderMutationError.invalid
        }
        // Never evict a live older attempt and thereby forget a newer fence.
        guard attempts.count < 128 else { throw ReminderMutationError.capacity }
        attempts[id] = Attempt(entity: entity, revision: revision, fields: fields)
    }

    func accept(generation: String, id: String) throws {
        try requireGeneration(generation)
        guard var attempt = attempts[id], !attempt.consumed else { throw ReminderMutationError.retired }
        attempt.accepted = true
        attempts[id] = attempt
        for field in attempt.fields {
            fences[attempt.entity, default: [:]][field] = max(
                fences[attempt.entity]?[field] ?? 0, attempt.revision
            )
        }
    }

    func consume(generation: String, id: String, fields: Set<String>) throws -> Set<String> {
        try requireGeneration(generation)
        guard var attempt = attempts[id], attempt.accepted, !attempt.consumed else {
            throw ReminderMutationError.retired
        }
        guard fields == attempt.fields else { throw ReminderMutationError.invalid }
        attempt.consumed = true
        attempts[id] = attempt
        return attempt.fields.filter { fences[attempt.entity]?[$0] == attempt.revision }
    }

    func finish(generation: String, id: String) {
        guard self.generation == generation, let attempt = attempts.removeValue(forKey: id) else { return }
        if !attempts.values.contains(where: { $0.entity == attempt.entity }) {
            fences.removeValue(forKey: attempt.entity)
        }
    }

    private func requireGeneration(_ value: String) throws {
        guard generation == value else { throw ReminderMutationError.retired }
    }
}
