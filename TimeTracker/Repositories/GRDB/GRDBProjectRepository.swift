import Foundation
import GRDB

struct GRDBProjectRepository: ProjectRepository {
    let database: AppDatabase

    func observeProjects(includeArchived: Bool) -> AsyncStream<[Project]> {
        database.stream { db in try Self.fetchProjects(db, includeArchived: includeArchived) }
    }

    func monthTotals(in range: DateRange) async throws -> [ProjectMonthTotal] {
        try await database.writer.read { db in try Self.fetchTotals(db, in: range) }
    }

    func observeMonthTotals(in range: DateRange) -> AsyncStream<[ProjectMonthTotal]> {
        database.stream { db in try Self.fetchTotals(db, in: range) }
    }

    func save(_ project: Project) async throws -> Project {
        do {
            return try await database.writer.write { db in
                var saved = project
                try saved.save(db)
                return saved
            }
        } catch let error as DatabaseError where error.extendedResultCode == .SQLITE_CONSTRAINT_UNIQUE {
            throw RepositoryError.duplicateName
        }
    }

    func archive(id: Int64, archived: Bool) async throws {
        try await database.writer.write { db in
            try db.execute(sql: "UPDATE project SET isArchived = ? WHERE id = ?", arguments: [archived, id])
        }
    }

    func delete(id: Int64) async throws {
        try await database.writer.write { db in
            let count = try TimeEntry.filter(Column("projectId") == id).fetchCount(db)
            guard count == 0 else { throw RepositoryError.projectHasEntries }
            _ = try Project.deleteOne(db, id: id)
        }
    }

    // MARK: Queries

    private static func fetchProjects(_ db: Database, includeArchived: Bool) throws -> [Project] {
        var request = Project.order(Column("name").collating(.nocase))
        if !includeArchived { request = request.filter(Column("isArchived") == false) }
        return try request.fetchAll(db)
    }

    /// Entries are clipped to the range, so an entry crossing midnight counts in both months.
    private static func fetchTotals(_ db: Database, in range: DateRange) throws -> [ProjectMonthTotal] {
        let sql = """
            SELECT project.*, COALESCE(SUM(
                MIN(timeEntry."end", :rangeEnd) - MAX(timeEntry.start, :rangeStart)
            ), 0) AS totalSeconds
            FROM project
            LEFT JOIN timeEntry ON timeEntry.projectId = project.id
                AND timeEntry.start < :rangeEnd AND timeEntry."end" > :rangeStart
            GROUP BY project.id
            ORDER BY totalSeconds DESC, project.name COLLATE NOCASE
            """
        let arguments: StatementArguments = [
            "rangeStart": range.start.timeIntervalSince1970,
            "rangeEnd": range.end.timeIntervalSince1970,
        ]
        return try ProjectMonthTotal.fetchAll(db, sql: sql, arguments: arguments)
    }
}
