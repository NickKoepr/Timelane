import Foundation
import GRDB
import Testing
@testable import Timelane

@MainActor
struct ActivityBackupTests {
    @Test func ownershipRule() {
        let mine = Date(timeIntervalSince1970: 1_000)
        let remote = BackupFixtures.info(createdAt: mine.addingTimeInterval(0.0004))
        #expect(ActivityBackupOwnership.mayReplace(remote: nil, lastOwnUpload: nil))
        #expect(ActivityBackupOwnership.mayReplace(remote: remote, lastOwnUpload: mine))
        #expect(!ActivityBackupOwnership.mayReplace(remote: remote, lastOwnUpload: nil))
        #expect(!ActivityBackupOwnership.mayReplace(remote: remote, lastOwnUpload: mine.addingTimeInterval(-60)))
    }

    /// A backup file with sessions [0, 600] and [1000, 1600] of Xcode and Xcode tracked for project "Work".
    func backupFile() throws -> (URL, URL) {
        let source = try AppDatabase.inMemory()
        try source.writer.write { db in
            var project = Project(name: "Work", colorHex: "#4F8EF7")
            try project.insert(db)
            var app = TrackedApp(bundleIdentifier: "com.apple.dt.Xcode", name: "Xcode", projectId: project.id)
            try app.insert(db)
        }
        try BackupFixtures.addSession(source, from: 0, to: 600)
        try BackupFixtures.addSession(source, from: 1000, to: 1600)
        let (file, _, directory) = try BackupFixtures.snapshot(of: source, part: .appActivity)
        return (file, directory)
    }

    @Test func mergeAddsOnlyWhatIsMissing() throws {
        let (file, directory) = try backupFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let local = try AppDatabase.inMemory()
        try local.writer.write { db in
            var project = Project(name: "work", colorHex: "#34C759")       // same name, other case and id
            try project.insert(db)
            var safari = TrackedApp(bundleIdentifier: "com.apple.Safari", name: "Safari")
            try safari.insert(db)
        }
        try BackupFixtures.addSession(local, from: 0, to: 600)              // already here

        let result = try ActivityBackupMerger(database: local).merge(from: file)
        let again = try ActivityBackupMerger(database: local).merge(from: file)

        #expect(result == ActivityBackupMerger.Result(sessions: 1, trackedApps: 1))
        #expect(again == ActivityBackupMerger.Result())
        #expect(try BackupFixtures.sessionCount(local) == 2)
        let link = try local.writer.read { db in
            try String.fetchOne(db, sql: """
                SELECT project.name FROM trackedApp JOIN project ON project.id = trackedApp.projectId
                WHERE bundleIdentifier = 'com.apple.dt.Xcode'
                """)
        }
        #expect(link == "work")
        #expect(try local.writer.read { db in try TrackedApp.fetchCount(db) } == 2)
    }

    @Test func restoreBackupOnAMacAddsActivityAndTakesOwnership() async throws {
        let store = InMemoryCloudBackupStore()
        let (file, directory) = try backupFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        try store.seed(.appActivity, file: file, info: BackupFixtures.info(entries: 0, createdAt: Date(timeIntervalSince1970: 5)))
        let source = try BackupFixtures.database(projects: 1, entries: 1)
        try BackupFixtures.seedSnapshot(of: source, part: .projectsAndHours, into: store)
        let device = try SyncTestDevice(server: InMemorySyncServer())
        try await device.service.enable(.replaceICloud)
        let settings = InMemoryBackupSettingsStore()
        let backup = device.backupService(store: store, settings: settings)
        await backup.refreshRemote()
        #expect(backup.activityNotOwned)

        let added = try await backup.restoreBackup()

        #expect(added?.sessions == 2)
        #expect(try BackupFixtures.sessionCount(device.database) == 2)
        #expect(try await device.allEntries().count == 1)
        #expect(store.uploadCount(.appActivity) == 1)
        #expect(!backup.activityNotOwned)
        #expect(settings.activityUploadedAt == store.info(.appActivity)?.createdAt)
    }

    @Test func restoreBackupOnAPhoneLeavesActivityAlone() async throws {
        let store = InMemoryCloudBackupStore()
        let (file, directory) = try backupFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        try store.seed(.appActivity, file: file, info: BackupFixtures.info(entries: 0))
        try BackupFixtures.seedSnapshot(of: try BackupFixtures.database(projects: 1, entries: 1), part: .projectsAndHours, into: store)
        let phone = try SyncTestDevice(server: InMemorySyncServer())
        try await phone.service.enable(.replaceICloud)
        let backup = phone.backupService(store: store, backsUpActivity: false)

        let added = try await backup.restoreBackup()

        #expect(added == nil)
        #expect(try BackupFixtures.sessionCount(phone.database) == 0)
        #expect(store.uploadCount(.appActivity) == 0)
        #expect(!store.downloads.contains(.appActivity))
    }

    @Test func iCloudMigrationTellsBackupOnlyDevicesOnce() {
        let backupOnly = InMemoryBackupSettingsStore(legacyBackupEnabled: true)
        #expect(ICloudMigration.run(settings: backupOnly, isSyncEnabled: false) == ICloudMigration.backupMovedNotice)
        #expect(ICloudMigration.run(settings: backupOnly, isSyncEnabled: false) == nil)
        #expect(ICloudMigration.run(settings: InMemoryBackupSettingsStore(legacyBackupEnabled: true), isSyncEnabled: true) == nil)
        #expect(ICloudMigration.run(settings: InMemoryBackupSettingsStore(), isSyncEnabled: false) == nil)
    }
}
