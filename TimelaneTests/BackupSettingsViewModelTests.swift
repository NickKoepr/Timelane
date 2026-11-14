import Foundation
import Testing
@testable import Timelane

@MainActor
struct BackupSettingsViewModelTests {
    struct Fixture {
        let model: BackupSettingsViewModel
        let service: CloudBackupService
        let store: InMemoryCloudBackupStore
        let device: SyncTestDevice
    }

    func make() async throws -> Fixture {
        let device = try SyncTestDevice(server: InMemorySyncServer())
        try await device.insertProject("Work", created: SyncTestWorld.h(0))
        try await device.service.enable(.replaceICloud)
        let store = InMemoryCloudBackupStore()
        let service = device.backupService(store: store)
        return Fixture(model: BackupSettingsViewModel(service: service), service: service, store: store, device: device)
    }

    @Test func statusBeforeAndAfterABackup() async throws {
        let f = try await make()
        await f.model.task()
        #expect(f.model.projectsStatusText == "No backup yet")
        await f.model.backUpNow()
        #expect(f.model.projectsStatusText.hasPrefix("Latest backup "))
        #expect(f.model.projectsStatusText.hasSuffix("from Test Mac · 1 projects, 0 time entries"))
    }

    @Test func legacyBackupIsShownAndRestorable() async throws {
        let f = try await make()
        f.store.seed(.legacy, data: Data(), info: BackupFixtures.info())
        await f.model.task()
        #expect(f.model.projectsStatusText.hasPrefix("Backup of an older Timelane version"))
        #expect(f.model.restoreCandidate != nil)
    }

    @Test func restoreWithoutBackupShowsError() async throws {
        let f = try await make()
        await f.model.requestRestore()
        #expect(!f.model.isConfirmingRestore)
        #expect(f.model.shownError == BackupError.noBackup.errorDescription)
    }

    @Test func restoreAsksThenReplaces() async throws {
        let f = try await make()
        await f.model.backUpNow()
        try await f.device.insertProject("Later", created: SyncTestWorld.h(1))
        await f.device.service.syncNow()
        await f.model.requestRestore()
        #expect(f.model.isConfirmingRestore)
        await f.model.confirmRestore()
        let names = try await f.device.allProjects().map(\.name)
        #expect(!f.model.isConfirmingRestore)
        #expect(f.model.shownError == nil)
        #expect(names == ["Work"])
    }
}
