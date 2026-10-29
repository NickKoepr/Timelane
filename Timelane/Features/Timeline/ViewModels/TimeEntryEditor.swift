import Foundation

/// Use-cases for changing time entries. Every change goes through the overlap resolver
/// and is saved in one transaction.
struct TimeEntryEditor: Sendable {
    static let minimumDuration: TimeInterval = 60

    let repository: any TimeEntryRepository
    var now: @Sendable () -> Date = { .now }
    /// Called after every successful create/update/delete (undo/redo write through the repository directly). Only the shared editor
    /// of `AppEnvironment` sets it, so other writers never land on the undo stack.
    var onChange: @Sendable (TimeEntryChange) async -> Void = { _ in }

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
        let before = try await repository.entries(ids: [id])
        try await repository.save([], deleting: [id])
        await onChange(TimeEntryChange(before: before, after: []))
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
        // Capture the rows as they are now: an edited entry may have moved outside the range read above.
        let touchedIds = resolution.toDelete + resolution.toSave.compactMap(\.id)
        let before = try await repository.entries(ids: touchedIds)
        let after = try await repository.save(resolution.toSave, deleting: resolution.toDelete)
        await onChange(TimeEntryChange(before: before, after: after))
    }
}
