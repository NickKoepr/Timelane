import Foundation
import Testing
@testable import Timelane

@MainActor
struct CloudBackupServiceTests {
    final class Clock { var now = Date(timeIntervalSince1970: 1_000_000) }
    struct Boom: LocalizedError { var errorDescription: String? { "boom" } }

    struct Fixture {
        let device: SyncTestDevice
        let service: CloudBackupService
        let store: InMemoryCloudBackupStore
        let settings: InMemoryBackupSettingsStore
        let clock: Clock
    }

    /// A device with `projects` projects; iCloud (sync) is on and caught up unless `syncOn` is false.
    func make(syncOn: Bool = true, projects: Int = 1, mac: Bool = true, server: InMemorySyncServer = InMemorySyncServer(),
              store: InMemoryCloudBackupStore = InMemoryCloudBackupStore(), clock: Clock = Clock()) async throws -> Fixture {
        let device = try SyncTestDevice(server: server)
        for index in 0..<projects { try await device.insertProject("P\(index)", created: SyncTestWorld.h(Double(index))) }
        if syncOn { try await device.service.enable(.replaceICloud) }
        let settings = InMemoryBackupSettingsStore()
        let service = device.backupService(store: store, backsUpActivity: mac, settings: settings,
                                           now: { clock.now }, deviceName: mac ? "Test Mac" : "Test iPhone")
        return Fixture(device: device, service: service, store: store, settings: settings, clock: clock)
    }

    @Test func backUpNowUploadsBothParts() async throws {
        let f = try await make()
        await f.service.backUpNow()
        #expect(f.store.uploads == [.projectsAndHours, .appActivity])
        #expect(f.store.info(.projectsAndHours)?.projectCount == 1)
        #expect(f.settings.activityUploadedAt == f.clock.now)
        #expect(f.service.lastError == nil)
        #expect(!f.service.isWorking)
    }

    @Test func nothingRunsWhileICloudIsOff() async throws {
        let f = try await make(syncOn: false)
        await f.service.tick()
        await f.service.backUpNow()
        #expect(f.store.uploads.isEmpty)
    }

    @Test func projectsWaitUntilThisDeviceIsCaughtUp() async throws {
        let f = try await make()
        try await f.device.insertProject("Not sent yet", created: SyncTestWorld.h(5))
        await f.service.tick()
        #expect(f.store.uploadCount(.projectsAndHours) == 0)
        #expect(f.service.projectsSkip == .waitingForSync)
        #expect(f.store.uploadCount(.appActivity) == 1)          // activity does not depend on sync

        await f.device.service.syncNow()
        await f.service.tick()                                   // no 15-minute wait after waiting for sync
        #expect(f.store.uploadCount(.projectsAndHours) == 1)
        #expect(f.store.info(.projectsAndHours)?.projectCount == 2)
    }

    @Test func noBackupBeforeTheFirstSyncPassAfterLaunch() async throws {
        let f = try await make()
        f.device.service.completedPassSinceLaunch = false        // as right after a relaunch
        await f.service.tick()
        #expect(f.store.uploadCount(.projectsAndHours) == 0)
        await f.device.service.syncNow()
        await f.service.tick()
        #expect(f.store.uploadCount(.projectsAndHours) == 1)
    }

    @Test func manualBackupWhileNotCaughtUpExplainsWhy() async throws {
        let server = InMemorySyncServer()
        let f = try await make(server: server)
        try await f.device.insertProject("Not sent yet", created: SyncTestWorld.h(5))
        server.isOnline = false                                  // the sync before the backup fails
        await f.service.backUpNow()
        #expect(f.store.uploadCount(.projectsAndHours) == 0)
        #expect(f.service.lastError == BackupError.waitingForSync.errorDescription)
    }

    @Test func phoneNeverWritesTheActivityBackup() async throws {
        let store = InMemoryCloudBackupStore()
        let server = InMemorySyncServer()
        let mac = try await make(server: server, store: store)
        try BackupFixtures.addSession(mac.device.database, from: 0, to: 600)
        await mac.service.backUpNow()
        let macActivity = store.storedData(.appActivity)

        let phone = try SyncTestDevice(server: server)
        try await phone.service.enable(.replaceLocal)
        let phoneBackup = phone.backupService(store: store, backsUpActivity: false)
        await phoneBackup.backUpNow()
        #expect(store.uploads == [.projectsAndHours, .appActivity, .projectsAndHours])
        #expect(store.storedData(.appActivity) == macActivity)
        #expect(store.info(.projectsAndHours)?.projectCount == 1)
    }

    @Test func activityOfAnotherMacIsKeptWhenThisMacTakesOver() async throws {
        let f = try await make()
        let other = try AppDatabase.inMemory()
        try BackupFixtures.addSession(other, bundle: "com.other", from: 0, to: 600)
        try BackupFixtures.seedSnapshot(of: other, part: .appActivity, into: f.store,
                                        createdAt: Date(timeIntervalSince1970: 5))
        try BackupFixtures.addSession(f.device.database, from: 1000, to: 1600)

        await f.service.backUpNow()

        #expect(f.service.lastError == nil)
        #expect(f.store.uploadCount(.appActivity) == 1)
        #expect(try BackupFixtures.sessionCount(f.device.database) == 2)     // the other Mac's session was added
        #expect(f.settings.activityUploadedAt == f.store.info(.appActivity)?.createdAt)

        f.service.markDirty(.appActivity)
        f.clock.now.addTimeInterval(60 * 60)
        await f.service.tick()                                   // now it is ours: no download, just replace
        #expect(f.store.uploadCount(.appActivity) == 2)
        #expect(f.store.downloads == [.appActivity])
    }

    @Test func automaticBackupOfEmptyDeviceKeepsRemoteWithData() async throws {
        let f = try await make(projects: 0)
        f.store.seed(.projectsAndHours, data: Data("remote".utf8), info: BackupFixtures.info(projects: 3, entries: 5))
        await f.service.tick()
        #expect(f.store.uploadCount(.projectsAndHours) == 0)
        #expect(f.service.projectsSkip == .emptyDevice)
        await f.service.backUpNow()                              // manual: always replaces
        #expect(f.store.uploadCount(.projectsAndHours) == 1)
    }

    @Test func tickRespectsTheSchedules() async throws {
        let f = try await make()
        await f.service.tick()                                   // dirty at launch
        #expect(f.store.uploads.count == 2)
        f.service.markDirty(.projectsAndHours)
        f.service.markDirty(.appActivity)
        f.clock.now.addTimeInterval(60)
        await f.service.tick()                                   // too soon for both
        #expect(f.store.uploads.count == 2)
        f.clock.now.addTimeInterval(15 * 60)
        await f.service.tick()                                   // projects again, activity waits an hour
        #expect(f.store.uploadCount(.projectsAndHours) == 2)
        #expect(f.store.uploadCount(.appActivity) == 1)
        await f.service.tick()                                   // not dirty
        #expect(f.store.uploadCount(.projectsAndHours) == 2)
    }

    @Test func storeErrorIsReportedNotThrown() async throws {
        let f = try await make()
        f.store.error = Boom()
        await f.service.backUpNow()
        #expect(f.service.lastError == "boom")
        #expect(!f.service.isWorking)
    }

    @Test func unavailableAccountIsReported() async throws {
        let f = try await make()
        f.store.status = .noAccount
        await f.service.backUpNow()
        #expect(f.store.uploads.isEmpty)
        #expect(f.service.lastError == BackupError.iCloudUnavailable(.noAccount).errorDescription)
    }

    @Test func refreshReadsEveryPart() async throws {
        let f = try await make()
        f.store.seed(.legacy, data: Data(), info: BackupFixtures.info())
        await f.service.backUpNow()
        await f.service.refreshRemote()
        #expect(Set(f.service.remote.keys) == [.projectsAndHours, .appActivity])   // legacy was cleaned up
        #expect(f.service.restorableProjects == f.store.info(.projectsAndHours))
    }

    // MARK: Legacy cleanup

    @Test func legacyBackupWithoutActivityIsRemoved() async throws {
        let f = try await make(mac: false)
        let old = try BackupFixtures.database(projects: 1, entries: 1)
        try BackupFixtures.seedSnapshot(of: old, part: .legacy, into: f.store)
        await f.service.backUpNow()
        #expect(f.store.info(.legacy) == nil)
    }

    @Test func legacyBackupWithActivityStaysUntilAnActivityBackupExists() async throws {
        let store = InMemoryCloudBackupStore()
        let phone = try await make(mac: false, store: store)
        let old = try BackupFixtures.database(projects: 1, entries: 1)
        try BackupFixtures.addSession(old, from: 0, to: 600)
        try BackupFixtures.seedSnapshot(of: old, part: .legacy, into: store)

        await phone.service.backUpNow()
        #expect(store.info(.legacy) != nil)
        #expect(store.downloads == [.legacy])
        phone.clock.now.addTimeInterval(20 * 60)
        await phone.service.backUpNow()
        #expect(store.downloads == [.legacy])                    // checked once per legacy backup

        store.seed(.appActivity, data: Data(), info: BackupFixtures.info(entries: 0))
        await phone.service.backUpNow()
        #expect(store.info(.legacy) == nil)
    }
}
