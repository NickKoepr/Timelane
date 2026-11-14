import Foundation
import GRDB
import Testing
@testable import Timelane

struct BackupSnapshotterTests {
    func database() throws -> AppDatabase {
        let database = try BackupFixtures.database(projects: 2, entries: 3)
        try BackupFixtures.addSession(database, from: 0, to: 600)
        try database.writer.write { db in
            var app = TrackedApp(bundleIdentifier: "com.apple.dt.Xcode", name: "Xcode", projectId: 1)
            try app.insert(db)
        }
        return database
    }

    func counts(_ file: URL) throws -> (projects: Int, entries: Int, sessions: Int, apps: Int, outbox: Int, meta: Int) {
        try DatabaseQueue(path: file.path).read { db in
            (try Project.fetchCount(db), try TimeEntry.fetchCount(db), try AppSession.fetchCount(db),
             try TrackedApp.fetchCount(db), try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM syncOutbox") ?? -1,
             try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM syncState") ?? -1)
        }
    }

    @Test func projectsAndHoursHasNoActivityAndNoSyncMetadata() throws {
        let (file, info, directory) = try BackupFixtures.snapshot(of: try database(), part: .projectsAndHours)
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(info.projectCount == 2)
        #expect(info.timeEntryCount == 3)
        #expect(info.deviceName == "Test Mac")
        #expect(info.schemaVersion == Migrations.makeMigrator().migrations.last)
        let c = try counts(file)
        #expect(c.projects == 2 && c.entries == 3)
        #expect(c.sessions == 0 && c.apps == 0)
        #expect(c.outbox == 0 && c.meta == 0)
    }

    @Test func appActivityHasSessionsAppsAndProjectsButNoHours() throws {
        let (file, info, directory) = try BackupFixtures.snapshot(of: try database(), part: .appActivity)
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(info.timeEntryCount == 0)
        let c = try counts(file)
        #expect(c.projects == 2 && c.entries == 0)
        #expect(c.sessions == 1 && c.apps == 1)
        #expect(c.outbox == 0 && c.meta == 0)
        let link = try DatabaseQueue(path: file.path).read { db in try Int64.fetchOne(db, sql: "SELECT projectId FROM trackedApp") }
        #expect(link == 1)
    }

    @Test func emptyDatabaseHasNoData() throws {
        let (_, info, directory) = try BackupFixtures.snapshot(of: try AppDatabase.inMemory())
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(!info.hasData)
    }
}
