import Foundation

protocol TimeEntryRepository: Sendable {
    func observeEntries(in range: DateRange) -> AsyncStream<[TimeEntry]>
    func entries(in range: DateRange) async throws -> [TimeEntry]
    /// The entries with these ids (missing ids are skipped).
    func entries(ids: [Int64]) async throws -> [TimeEntry]
    /// Deletes and saves in one transaction. Entries with `id == nil` are inserted; an entry with an id
    /// is updated, or re-inserted with that id when its row no longer exists. Returns the saved rows with ids.
    @discardableResult
    func save(_ entries: [TimeEntry], deleting ids: [Int64]) async throws -> [TimeEntry]
}
