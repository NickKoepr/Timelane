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
}
