import Foundation

/// Use-cases for changing time entries. Every change goes through the overlap resolver
/// and is saved in one transaction.
struct TimeEntryEditor: Sendable {
    static let minimumDuration: TimeInterval = 60

    let repository: any TimeEntryRepository
    var now: @Sendable () -> Date = { .now }

    func create(projectId: Int64, range: DateRange, title: String? = nil, note: String?) async throws {
        let entry = TimeEntry(projectId: projectId, start: range.start, end: range.end,
                              title: Self.normalized(title), note: Self.normalized(note),
                              createdAt: now(), updatedAt: now())
        try await apply(entry)
    }

    /// Saves a changed entry (project, note, start or end).
    func update(_ entry: TimeEntry) async throws {
        var changed = entry
        changed.updatedAt = now()
        try await apply(changed)
    }

    func delete(_ entry: TimeEntry) async throws {
        guard let id = entry.id else { return }
        try await repository.save([], deleting: [id])
    }

    /// Trimmed text, or nil when empty.
    static func normalized(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func apply(_ entry: TimeEntry) async throws {
        guard entry.duration >= Self.minimumDuration else { throw TimeEntryEditorError.tooShort }
        let existing = try await repository.entries(in: entry.range)
        let resolution = TimeEntryOverlapResolver.resolve(existing: existing, applying: entry, now: now())
        try await repository.save(resolution.toSave, deleting: resolution.toDelete)
    }
}
