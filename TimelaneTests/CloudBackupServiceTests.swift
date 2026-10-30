import Foundation
import Testing
@testable import Timelane

@MainActor
struct CloudBackupServiceTests {
    final class Clock { var now = Date(timeIntervalSince1970: 1_000_000) }
    struct Boom: LocalizedError { var errorDescription: String? { "boom" } }

    struct Fixture {
        let service: CloudBackupService
        let store: InMemoryCloudBackupStore
        let settings: InMemoryBackupSettingsStore
        let restore: PendingRestore
        let clock: Clock
    }

    func make(projects: Int = 1, entries: Int = 2, enabled: Bool = true) throws -> Fixture {
        let clock = Clock()
        let store = InMemoryCloudBackupStore()
        let settings = InMemoryBackupSettingsStore(isEnabled: enabled)
        let restore = PendingRestore.temporary()
        let service = CloudBackupService(
            snapshotter: BackupSnapshotter(database: try BackupFixtures.database(projects: projects, entries: entries)),
            store: store, settings: settings, pendingRestore: restore, now: { clock.now })
        return Fixture(service: service, store: store, settings: settings, restore: restore, clock: clock)
    }

    @Test func backUpNowUploadsAndRecordsTime() async throws {
        let f = try make()
        await f.service.backUpNow(automatic: false)
        #expect(f.store.uploadCount == 1)
        #expect(f.store.info?.projectCount == 1)
        #expect(f.service.lastBackupAt == f.clock.now)
        #expect(f.settings.lastBackupAt == f.clock.now)
        #expect(f.service.lastError == nil)
        #expect(!f.service.isWorking)
    }

    @Test func automaticBackupOfEmptyDatabaseKeepsRemoteWithData() async throws {
        let f = try make(projects: 0, entries: 0)
        f.store.seed(data: Data("remote".utf8), info: BackupFixtures.info(projects: 3, entries: 5))
        await f.service.backUpNow(automatic: true)
        #expect(f.store.uploadCount == 0)
        #expect(f.service.skippedBecauseEmpty)
        #expect(f.store.storedData == Data("remote".utf8))
    }

    @Test func manualBackupOfEmptyDatabaseReplacesRemote() async throws {
        let f = try make(projects: 0, entries: 0)
        f.store.seed(data: Data("remote".utf8), info: BackupFixtures.info(projects: 3, entries: 5))
        await f.service.backUpNow(automatic: false)
        #expect(f.store.uploadCount == 1)
    }

    @Test func tickRespectsTheSchedule() async throws {
        let f = try make()
        await f.service.tick()                       // not dirty
        #expect(f.store.uploadCount == 0)
        f.service.markDirty()
        await f.service.tick()
        #expect(f.store.uploadCount == 1)
        f.service.markDirty()
        f.clock.now.addTimeInterval(60)
        await f.service.tick()                       // too soon
        #expect(f.store.uploadCount == 1)
        f.clock.now.addTimeInterval(15 * 60)
        await f.service.tick()
        #expect(f.store.uploadCount == 2)
    }

    @Test func tickDoesNothingWhenDisabled() async throws {
        let f = try make(enabled: false)
        f.service.markDirty()
        await f.service.tick()
        #expect(f.store.uploadCount == 0)
    }

    @Test func storeErrorIsReportedNotThrown() async throws {
        let f = try make()
        f.store.error = Boom()
        await f.service.backUpNow(automatic: true)
        #expect(f.service.lastError == "boom")
        #expect(!f.service.isWorking)
        #expect(f.service.lastBackupAt == nil)
    }

    @Test func unavailableAccountIsReported() async throws {
        let f = try make()
        f.store.status = .noAccount
        await f.service.backUpNow(automatic: false)
        #expect(f.store.uploadCount == 0)
        #expect(f.service.lastError == BackupError.iCloudUnavailable(.noAccount).errorDescription)
    }

    @Test func prepareRestoreWithoutBackupThrows() async throws {
        let f = try make()
        await #expect(throws: BackupError.noBackup) { try await f.service.prepareRestore() }
    }

    @Test func prepareRestoreStagesTheBackupAndBlocksUploads() async throws {
        let f = try make()
        defer { try? FileManager.default.removeItem(at: f.restore.directory) }
        await f.service.backUpNow(automatic: false)
        try await f.service.prepareRestore()
        #expect(f.restore.hasPendingRestore)
        await f.service.backUpNow(automatic: false)
        #expect(f.store.uploadCount == 1)
    }
}
