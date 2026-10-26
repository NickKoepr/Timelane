import Foundation

/// Use-cases for changing time entries. Every change goes through the overlap resolver
/// and is saved in one transaction.
struct TimeEntryEditor: Sendable {
    static let minimumDuration: TimeInterval = 60

    let repository: any TimeEntryRepository
    var now: @Sendable () -> Date = { .now }

    func create(projectId: Int64, range: DateRange, note: String?) async throws {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = TimeEntry(projectId: projectId, start: range.start, end: range.end,
                              note: trimmed?.isEmpty == true ? nil : trimmed,
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

    private func apply(_ entry: TimeEntry) async throws {
        guard entry.duration >= Self.minimumDuration else { throw TimeEntryEditorError.tooShort }
        let existing = try await repository.entries(in: entry.range)
        let resolution = TimeEntryOverlapResolver.resolve(existing: existing, applying: entry, now: now())
        try await repository.save(resolution.toSave, deleting: resolution.toDelete)
    }
}
