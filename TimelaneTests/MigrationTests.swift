import Foundation
import GRDB
import Testing
@testable import Timelane

struct MigrationTests {
    @Test func v2KeepsV1EntriesAndAddsTitleAndTrackedApps() throws {
        let queue = try DatabaseQueue()
        let full = Migrations.makeMigrator()
        try full.migrate(queue, upTo: "v1")
        try queue.write { db in
            try db.execute(sql: "INSERT INTO project (name, colorHex, isArchived, createdAt) VALUES ('P', '#FFFFFF', 0, 0)")
            try db.execute(sql: "INSERT INTO timeEntry (projectId, start, end, note, createdAt, updatedAt) VALUES (1, 100, 200, 'n', 0, 0)")
        }
        try full.migrate(queue)
        try queue.read { db in
            let entries = try TimeEntry.fetchAll(db)
            #expect(entries.count == 1)
            #expect(entries[0].title == nil)
            #expect(entries[0].note == "n")
            #expect(try db.tableExists("trackedApp"))
        }
    }

    @Test func v3AddsProjectLinkAndNullsItWhenProjectIsDeleted() throws {
        let queue = try DatabaseQueue()
        let migrator = Migrations.makeMigrator()
        try migrator.migrate(queue, upTo: "v2")
        try queue.write { db in
            try db.execute(sql: "INSERT INTO project (name, colorHex, isArchived, createdAt) VALUES ('P', '#FFFFFF', 0, 0)")
            try db.execute(sql: "INSERT INTO trackedApp (bundleIdentifier, name, addedAt) VALUES ('a', 'A', 0)")
        }
        try migrator.migrate(queue)
        try queue.write { db in
            #expect(try TrackedApp.fetchAll(db).first?.projectId == nil)
            try db.execute(sql: "UPDATE trackedApp SET projectId = 1")
            #expect(try TrackedApp.fetchAll(db).first?.projectId == 1)
            try db.execute(sql: "DELETE FROM project WHERE id = 1")
            #expect(try TrackedApp.fetchAll(db).first?.projectId == nil)
        }
    }
}
