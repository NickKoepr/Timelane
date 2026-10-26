import Foundation

protocol TimeEntryRepository: Sendable {
    func observeEntries(in range: DateRange) -> AsyncStream<[TimeEntry]>
    func entries(in range: DateRange) async throws -> [TimeEntry]
    /// Deletes and saves in one transaction. Entries with `id == nil` are inserted.
    func save(_ entries: [TimeEntry], deleting ids: [Int64]) async throws
}
