import Foundation
import Testing
@testable import Timelane

@MainActor
struct BackupSettingsViewModelTests {
    final class Relaunches { var count = 0 }

    struct Fixture {
        let model: BackupSettingsViewModel
        let service: CloudBackupService
        let store: InMemoryCloudBackupStore
        let relaunches: Relaunches
        let restore: PendingRestore
    }

    func make(projects: Int = 1, entries: Int = 1) throws -> Fixture {
        let store = InMemoryCloudBackupStore()
        let restore = PendingRestore.temporary()
        let service = CloudBackupService(
            snapshotter: BackupSnapshotter(database: try BackupFixtures.database(projects: projects, entries: entries)),
            store: store, settings: InMemoryBackupSettingsStore(), pendingRestore: restore)
        let relaunches = Relaunches()
        let model = BackupSettingsViewModel(service: service, relaunch: { relaunches.count += 1 })
        return Fixture(model: model, service: service, store: store, relaunches: relaunches, restore: restore)
    }

    @Test func unavailableAccountStaysOff() async throws {
        let f = try make()
        f.store.status = .noAccount
        await f.model.setEnabled(true)
        #expect(!f.model.isEnabled)
        #expect(f.model.errorMessage == "Sign in to iCloud in System Settings to use iCloud backup.")
        #expect(f.store.uploadCount == 0)
    }

    @Test func noRemoteBackupEnablesAndUploads() async throws {
        let f = try make()
        await f.model.setEnabled(true)
        #expect(f.model.isEnabled)
        #expect(f.store.uploadCount == 1)
        #expect(f.model.pendingChoice == nil)
    }

    @Test func existingBackupWithDataAsksFirst() async throws {
        let f = try make()
        f.store.seed(data: Data("x".utf8), info: BackupFixtures.info())
        await f.model.setEnabled(true)
        #expect(f.model.pendingChoice == BackupFixtures.info())
        #expect(!f.model.isEnabled)
        #expect(f.store.uploadCount == 0)
    }

    @Test func existingEmptyBackupIsReplacedWithoutAsking() async throws {
        let f = try make()
        f.store.seed(data: Data("x".utf8), info: BackupFixtures.info(projects: 0, entries: 0))
        await f.model.setEnabled(true)
        #expect(f.model.isEnabled)
        #expect(f.store.uploadCount == 1)
    }

    @Test func replaceUploads() async throws {
        let f = try make()
        f.store.seed(data: Data("x".utf8), info: BackupFixtures.info())
        await f.model.setEnabled(true)
        await f.model.resolveChoice(.replace)
        #expect(f.model.isEnabled)
        #expect(f.store.uploadCount == 1)
        #expect(f.model.pendingChoice == nil)
    }

    @Test func cancelStaysOff() async throws {
        let f = try make()
        f.store.seed(data: Data("x".utf8), info: BackupFixtures.info())
        await f.model.setEnabled(true)
        await f.model.resolveChoice(.cancel)
        #expect(!f.model.isEnabled)
        #expect(f.store.uploadCount == 0)
        #expect(f.model.pendingChoice == nil)
    }

    @Test func restoreChoiceStagesAndRelaunches() async throws {
        let source = try make(projects: 2, entries: 2)
        await source.service.backUpNow(automatic: false)
        let f = try make()
        defer { try? FileManager.default.removeItem(at: f.restore.directory) }
        f.store.seed(data: try #require(source.store.storedData), info: try #require(source.store.info))
        await f.model.setEnabled(true)
        await f.model.resolveChoice(.restore)
        #expect(f.restore.hasPendingRestore)
        #expect(f.relaunches.count == 1)
        #expect(f.model.isEnabled)
    }

    @Test func disablingKeepsTheRemoteBackup() async throws {
        let f = try make()
        await f.model.setEnabled(true)
        await f.model.setEnabled(false)
        #expect(!f.model.isEnabled)
        #expect(f.store.info != nil)
        #expect(f.store.storedData != nil)
    }

    @Test func requestRestoreWithoutBackupShowsError() async throws {
        let f = try make()
        await f.model.requestRestore()
        #expect(!f.model.isConfirmingRestore)
        #expect(f.model.errorMessage == BackupError.noBackup.errorDescription)
    }

    @Test func confirmedRestoreRelaunches() async throws {
        let f = try make()
        defer { try? FileManager.default.removeItem(at: f.restore.directory) }
        await f.model.setEnabled(true)
        await f.model.requestRestore()
        #expect(f.model.isConfirmingRestore)
        await f.model.confirmRestore()
        #expect(f.relaunches.count == 1)
    }
}
