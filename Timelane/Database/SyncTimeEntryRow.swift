import Foundation
import GRDB

/// A stored time entry plus its per-field-group modification times. The groups are not part of
/// `TimeEntry` (the UI never needs them); only the sync layer reads them.
struct SyncTimeEntryRow: Equatable, Sendable, FetchableRecord {
    var entry: TimeEntry
    /// `start` and `end`.
    var timesUpdatedAt: Date
    /// `title` and `note`.
    var textUpdatedAt: Date
    /// `projectId`.
    var projectUpdatedAt: Date

    init(entry: TimeEntry, timesUpdatedAt: Date, textUpdatedAt: Date, projectUpdatedAt: Date) {
        self.entry = entry
        self.timesUpdatedAt = timesUpdatedAt
        self.textUpdatedAt = textUpdatedAt
        self.projectUpdatedAt = projectUpdatedAt
    }

    init(row: Row) throws {
        entry = try TimeEntry(row: row)
        let times: Double = row["timesUpdatedAt"]
        let text: Double = row["textUpdatedAt"]
        let project: Double = row["projectUpdatedAt"]
        timesUpdatedAt = Date(timeIntervalSince1970: times)
        textUpdatedAt = Date(timeIntervalSince1970: text)
        projectUpdatedAt = Date(timeIntervalSince1970: project)
    }

    static func fetch(_ db: Database, id: Int64) throws -> SyncTimeEntryRow? {
        try fetchOne(db, sql: "SELECT * FROM timeEntry WHERE id = ?", arguments: [id])
    }

    static func fetch(_ db: Database, ids: [Int64]) throws -> [SyncTimeEntryRow] {
        guard !ids.isEmpty else { return [] }
        let marks = databaseQuestionMarks(count: ids.count)
        return try fetchAll(db, sql: "SELECT * FROM timeEntry WHERE id IN (\(marks)) ORDER BY start",
                            arguments: StatementArguments(ids))
    }
}
