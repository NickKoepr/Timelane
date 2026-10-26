import Foundation
import GRDB

struct GRDBAppSessionRepository: AppSessionRepository {
    let database: AppDatabase

    func observeSessions(in range: DateRange) -> AsyncStream<[AppSession]> {
        database.stream { db in try Self.fetch(db, in: range) }
    }

    func sessions(in range: DateRange) async throws -> [AppSession] {
        try await database.writer.read { db in try Self.fetch(db, in: range) }
    }

    func start(_ session: AppSession) async throws -> AppSession {
        try await database.writer.write { db in
            var copy = session
            try copy.insert(db)
            return copy
        }
    }

    func close(id: Int64, at end: Date) async throws {
        try await database.writer.write { db in
            try db.execute(
                sql: "UPDATE appSession SET \"end\" = MAX(start, ?) WHERE id = ?",
                arguments: [end.timeIntervalSince1970, id]
            )
        }
    }

    func closeDanglingSessions(at end: Date?) async throws {
        try await database.writer.write { db in
            if let end {
                try db.execute(
                    sql: "UPDATE appSession SET \"end\" = MAX(start, ?) WHERE \"end\" IS NULL",
                    arguments: [end.timeIntervalSince1970]
                )
            } else {
                try db.execute(sql: "UPDATE appSession SET \"end\" = start + 60 WHERE \"end\" IS NULL")
            }
        }
    }

    /// Sessions overlapping the range, including a still-open one (`end IS NULL`).
    private static func fetch(_ db: Database, in range: DateRange) throws -> [AppSession] {
        try AppSession
            .filter(Column("start") < range.end.timeIntervalSince1970)
            .filter(Column("end") == nil || Column("end") > range.start.timeIntervalSince1970)
            .order(Column("start"))
            .fetchAll(db)
    }
}
