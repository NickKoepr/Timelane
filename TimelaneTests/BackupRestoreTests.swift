import Foundation
import GRDB
import Testing
@testable import Timelane

/// Restoring projects and hours with iCloud on: every device follows, app activity stays.
@MainActor
struct BackupRestoreTests {
    func h(_ hours: Double) -> Date { SyncTestWorld.h(hours) }

    @Test func restoreReplacesProjectsAndHoursOnAllDevices() async throws {
        let (a, b, server) = try await SyncTestWorld.pair()
        let store = InMemoryCloudBackupStore()
        let backup = a.backupService(store: store)
        let old = try await a.insertProject("Old", created: h(0))
        try await a.addEntry(old, from: h(1), to: h(2), at: h(2))
        try await SyncTestDevice.syncAll([a, b])
        await backup.backUpNow()

        try await a.insertProject("New", created: h(3))
        try await a.addEntry(old, from: h(4), to: h(5), at: h(5), recordingHistory: true)
        try await SyncTestDevice.syncAll([a, b])
        #expect(a.history.canUndo)

        try await backup.restoreProjects()
        try await SyncTestDevice.syncAll([a, b])

        let projectsA = try await a.allProjects().map(\.name)
        let projectsB = try await b.allProjects().map(\.name)
        let entriesB = try await b.allEntries()
        #expect(projectsA == ["Old"])
        #expect(projectsB == ["Old"])
        #expect(entriesB.count == 1)
        #expect(server.records.count == 2)
        #expect(!a.history.canUndo)                               // undo steps referred to replaced rows
        #expect(b.service.notice == SyncService.replacedNotice)
        let outboxA = try await a.outbox()
        #expect(outboxA.isEmpty)
        #expect(!a.service.restoreUploadPending)
    }

    @Test func restoreKeepsAppActivityAndGivesNewIds() async throws {
        let (a, _, _) = try await SyncTestWorld.pair()
        let backup = a.backupService(store: InMemoryCloudBackupStore())
        let project = try await a.insertProject("Old", created: h(0))
        try await a.addEntry(project, from: h(1), to: h(2), at: h(2))
        await a.service.syncNow()
        try BackupFixtures.addSession(a.database, from: 0, to: 600)
        await backup.backUpNow()
        try BackupFixtures.addSession(a.database, from: 1000, to: 1600)     // after the backup
        let oldIds = try await a.allEntries().compactMap(\.id)

        try await backup.restoreProjects()

        let newIds = try await a.allEntries().compactMap(\.id)
        #expect(try BackupFixtures.sessionCount(a.database) == 2)
        #expect(newIds.count == 1)
        #expect(newIds.allSatisfy { id in oldIds.allSatisfy { id > $0 } })
        #expect(FileManager.default.fileExists(atPath: backup.safetyCopy.path))
    }

    @Test func restoreKeepsTrackedAppLinks() async throws {
        let (a, _, _) = try await SyncTestWorld.pair()
        let backup = a.backupService(store: InMemoryCloudBackupStore())
        let project = try await a.insertProject("Linked", created: h(0))
        try await a.database.writer.write { db in
            var app = TrackedApp(bundleIdentifier: "com.apple.dt.Xcode", name: "Xcode", projectId: project.id)
            try app.insert(db)
        }
        await a.service.syncNow()
        await backup.backUpNow()
        try await backup.restoreProjects()
        let linked = try await a.database.writer.read { db in
            try String.fetchOne(db, sql: "SELECT project.name FROM trackedApp JOIN project ON project.id = trackedApp.projectId")
        }
        #expect(linked == "Linked")
    }

    @Test func restoreFromAnOlderVersionsWholeDatabaseBackup() async throws {
        let (a, b, _) = try await SyncTestWorld.pair()
        let store = InMemoryCloudBackupStore()
        let backup = a.backupService(store: store)
        // A v3 database (before customer ids and sync), as an old version uploaded it.
        let directory = try BackupFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("old.sqlite")
        let queue = try DatabaseQueue(path: file.path)
        try Migrations.makeMigrator().migrate(queue, upTo: "v3")
        try await queue.write { db in
            try db.execute(sql: "INSERT INTO project (name, colorHex, isArchived, createdAt) VALUES ('Legacy', '#4F8EF7', 0, 0)")
            try db.execute(sql: """
                INSERT INTO timeEntry (projectId, start, "end", createdAt, updatedAt) VALUES (1, 0, 3600, 0, 0)
                """)
            try db.execute(sql: "INSERT INTO appSession (bundleIdentifier, appName, start, \"end\") VALUES ('x', 'X', 0, 10)")
        }
        try queue.close()
        try store.seed(.legacy, file: file, info: BackupFixtures.info(projects: 1, entries: 1))

        try await backup.restoreProjects()
        try await SyncTestDevice.syncAll([a, b])

        let projectsB = try await b.allProjects().map(\.name)
        let entriesA = try await a.allEntries()
        #expect(projectsB == ["Legacy"])
        #expect(entriesA.count == 1)
        #expect(try BackupFixtures.sessionCount(a.database) == 0)          // projects and hours only
    }

    @Test func interruptedRestoreFinishesAfterARelaunch() async throws {
        let (a, b, server) = try await SyncTestWorld.pair()
        try await a.insertProject("Current", created: h(0))
        try await SyncTestDevice.syncAll([a, b])
        let source = try BackupFixtures.database(projects: 2, entries: 1)
        let (file, _, directory) = try BackupFixtures.snapshot(of: source)
        defer { try? FileManager.default.removeItem(at: directory) }

        // The local step committed, then the app quit before iCloud was replaced.
        await a.service.stopEngine()
        try await a.store.restoreSyncedData(from: file, uploadPending: true)

        let relaunched = SyncService(store: GRDBSyncStore(database: a.database), engine: FakeSyncEngine(server: server),
                                     forwardDelay: .zero, zoneCheckDelay: .zero, syncsAutomatically: false)
        await relaunched.load()
        #expect(relaunched.restoreUploadPending)
        await relaunched.syncNow()
        await b.service.syncNow()

        let projectsB = try await b.allProjects().map(\.name).sorted()
        #expect(!relaunched.restoreUploadPending)
        #expect(projectsB == ["Project 0", "Project 1"])
        let pending = try await a.store.state(.restoreUploadPending)
        #expect(pending == nil)
    }

    @Test func offlineRestoreReplacesICloudOnceOnline() async throws {
        let (a, b, server) = try await SyncTestWorld.pair()
        let store = InMemoryCloudBackupStore()
        let backup = a.backupService(store: store)
        try await a.insertProject("Backed up", created: h(0))
        try await SyncTestDevice.syncAll([a, b])
        await backup.backUpNow()
        try await a.insertProject("Later", created: h(1))
        try await SyncTestDevice.syncAll([a, b])

        server.isOnline = false
        await #expect(throws: (any Error).self) { try await backup.restoreProjects() }
        #expect(a.service.restoreUploadPending)
        let projectsA = try await a.allProjects().map(\.name)
        #expect(projectsA == ["Backed up"])

        server.isOnline = true
        await a.service.syncNow()
        await b.service.syncNow()
        let projectsB = try await b.allProjects().map(\.name)
        #expect(!a.service.restoreUploadPending)
        #expect(projectsB == ["Backed up"])
    }
}
