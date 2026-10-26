import Foundation
import GRDB

struct GRDBTimeEntryRepository: TimeEntryRepository {
    let database: AppDatabase

    func observeEntries(in range: DateRange) -> AsyncStream<[TimeEntry]> {
        database.stream { db in try Self.fetch(db, in: range) }
    }

    func entries(in range: DateRange) async throws -> [TimeEntry] {
        try await database.writer.read { db in try Self.fetch(db, in: range) }
    }

    func save(_ entries: [TimeEntry], deleting ids: [Int64]) async throws {
        guard entries.allSatisfy({ $0.end > $0.start }) else { throw RepositoryError.invalidRange }
        try await database.writer.write { db in
            _ = try TimeEntry.deleteAll(db, ids: ids)
            for entry in entries {
                var copy = entry
                try copy.save(db)
            }
        }
    }

    private static func fetch(_ db: Database, in range: DateRange) throws -> [TimeEntry] {
        try TimeEntry
            .filter(Column("start") < range.end.timeIntervalSince1970)
            .filter(Column("end") > range.start.timeIntervalSince1970)
            .order(Column("start"))
            .fetchAll(db)
    }
}
