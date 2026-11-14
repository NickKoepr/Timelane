import Foundation
import GRDB
import Testing
@testable import Timelane

struct SyncSchemaTests {
    /// "recordType|syncId|kind" per queued row.
    private static func outbox(_ db: Database) throws -> [String] {
        try Row.fetchAll(db, sql: "SELECT recordType, syncId, kind FROM syncOutbox ORDER BY recordType, syncId")
            .map { "\($0["recordType"] as String)|\($0["syncId"] as String)|\($0["kind"] as String)" }
    }

    @Test func v5BackfillsUniqueSyncIdsAndTimestampsFromV4Data() throws {
        let queue = try DatabaseQueue()
        let migrator = Migrations.makeMigrator()
        try migrator.migrate(queue, upTo: "v4")
        try queue.write { db in
            try db.execute(sql: "INSERT INTO project (name, colorHex, isArchived, createdAt) VALUES ('P', '#FFFFFF', 0, 111)")
            try db.execute(sql: "INSERT INTO project (name, colorHex, isArchived, createdAt) VALUES ('Q', '#FFFFFF', 0, 222)")
            try db.execute(sql: "INSERT INTO timeEntry (projectId, start, end, createdAt, updatedAt) VALUES (1, 100, 200, 0, 333)")
            try db.execute(sql: "INSERT INTO timeEntry (projectId, start, end, createdAt, updatedAt) VALUES (2, 300, 400, 0, 444)")
        }
        try migrator.migrate(queue)
        try queue.read { db in
            let projects = try Project.order(Column("id")).fetchAll(db)
            #expect(Set(projects.map(\.syncId)).count == 2)
            #expect(projects.map(\.updatedAt.timeIntervalSince1970) == [111, 222])
            let rows = try SyncTimeEntryRow.fetch(db, ids: [1, 2])
            #expect(Set(rows.map(\.entry.syncId)).count == 2)
            #expect(rows.map(\.timesUpdatedAt.timeIntervalSince1970) == [333, 444])
            #expect(rows.map(\.textUpdatedAt.timeIntervalSince1970) == [333, 444])
            #expect(rows.map(\.projectUpdatedAt.timeIntervalSince1970) == [333, 444])
            // Stored as uppercase text, and the backfill itself queued nothing.
            #expect(try String.fetchOne(db, sql: "SELECT syncId FROM project WHERE id = 1") == projects[0].syncId.uuidString)
            #expect(try Self.outbox(db).isEmpty)
        }
    }

    @Test func triggersQueueInsertUpdateAndDelete() async throws {
        let db = try AppDatabase.inMemory()
        let projects = GRDBProjectRepository(database: db)
        let entries = GRDBTimeEntryRepository(database: db)
        let project = try await projects.save(Project(name: "Alpha", colorHex: "#4F8EF7"))
        let start = TestCalendar.date(2026, 11, 3, 9)
        let entry = try await entries.save([TimeEntry(projectId: project.id!, start: start, end: start.addingTimeInterval(3600))],
                                           deleting: []).first!
        try await db.writer.write { db in
            #expect(try Self.outbox(db) == ["Project|\(project.syncId.uuidString)|save",
                                            "TimeEntry|\(entry.syncId.uuidString)|save"])
            try db.execute(sql: "DELETE FROM syncOutbox")
        }
        var moved = entry
        moved.end = start.addingTimeInterval(7200)
        try await entries.save([moved], deleting: [])
        try await db.writer.write { db in
            #expect(try Self.outbox(db).count == 1)
            try db.execute(sql: "DELETE FROM syncOutbox")
        }
        try await entries.save([], deleting: [entry.id!])
        let afterDelete = try await db.writer.read { db in try Self.outbox(db) }
        #expect(afterDelete == ["TimeEntry|\(entry.syncId.uuidString)|delete"])
    }

    @Test func triggersStaySilentWhileApplyingRemote() async throws {
        let db = try AppDatabase.inMemory()
        try await db.writer.write { db in
            try db.execute(sql: "INSERT INTO syncApplyingRemote (marker) VALUES (1)")
            try db.execute(sql: "INSERT INTO project (name, colorHex, isArchived, createdAt, updatedAt, syncId) VALUES ('R', '#FFFFFF', 0, 1, 1, ?)",
                           arguments: [UUID().uuidString])
            try db.execute(sql: "UPDATE project SET colorHex = '#000000'")
            try db.execute(sql: "DELETE FROM project")
            #expect(try Self.outbox(db).isEmpty)
            try db.execute(sql: "DELETE FROM syncApplyingRemote")
            try db.execute(sql: "INSERT INTO project (name, colorHex, isArchived, createdAt, updatedAt, syncId) VALUES ('S', '#FFFFFF', 0, 1, 1, ?)",
                           arguments: [UUID().uuidString])
            #expect(try Self.outbox(db).count == 1)
        }
    }

    @Test func projectSaveAndArchiveBumpUpdatedAt() async throws {
        let db = try AppDatabase.inMemory()
        let projects = GRDBProjectRepository(database: db)
        let old = Date(timeIntervalSince1970: 1000)
        let saved = try await projects.save(Project(name: "Alpha", colorHex: "#4F8EF7", createdAt: old))
        #expect(saved.updatedAt > old)
        #expect(saved.createdAt == old)
        try await db.writer.write { db in
            try db.execute(sql: "UPDATE project SET updatedAt = 1000")
        }
        try await projects.archive(id: saved.id!, archived: true)
        let archived = try await projects.projects(includeArchived: true).first!
        #expect(archived.updatedAt.timeIntervalSince1970 > 1000)
        #expect(archived.syncId == saved.syncId)
    }
}
