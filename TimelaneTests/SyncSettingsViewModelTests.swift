import Foundation
import Testing
@testable import Timelane

@MainActor
struct SyncSettingsViewModelTests {
    struct Fixture {
        let model: SyncSettingsViewModel
        let device: SyncTestDevice
        let server: InMemorySyncServer
    }

    /// A Mac with sync still off; iCloud holds one project when `remoteData` is true.
    func make(remoteData: Bool, localProject: Bool = true) async throws -> Fixture {
        let server = InMemorySyncServer()
        if remoteData {
            let other = try SyncTestDevice(server: server)
            try await other.insertProject("Remote", created: SyncTestWorld.h(0))
            try await other.service.enable(.replaceICloud)
        }
        let device = try SyncTestDevice(server: server)
        if localProject { try await device.insertProject("Local", created: SyncTestWorld.h(1)) }
        return Fixture(model: SyncSettingsViewModel(service: device.service), device: device, server: server)
    }

    @Test func remoteDataAsksEvenWhenThisMacIsEmpty() async throws {            // A1, A3
        let f = try await make(remoteData: true, localProject: false)
        await f.model.setEnabled(true)
        #expect(f.model.isChoosingExistingData)
        #expect(!f.model.isEnabled)
    }

    @Test func remoteDataAsksWithLocalData() async throws {                     // A1
        let f = try await make(remoteData: true)
        await f.model.setEnabled(true)
        #expect(f.model.isChoosingExistingData)
        #expect(!f.model.isEnabled)
    }

    @Test func emptyICloudEnablesWithoutAsking() async throws {                 // A2
        let f = try await make(remoteData: false)
        await f.model.setEnabled(true)
        #expect(!f.model.isChoosingExistingData)
        #expect(f.model.isEnabled)
        #expect(f.server.records.count == 1)
        #expect(f.model.errorMessage == nil)
    }

    @Test func replaceICloudUploadsThisMac() async throws {
        let f = try await make(remoteData: true)
        await f.model.setEnabled(true)
        await f.model.resolveChoice(.replaceICloud)
        let names = try await f.device.allProjects().map(\.name)
        #expect(!f.model.isChoosingExistingData)
        #expect(f.model.isEnabled)
        #expect(names == ["Local"])
        #expect(f.server.records.count == 1)
    }

    @Test func replaceLocalDownloadsICloud() async throws {
        let f = try await make(remoteData: true)
        await f.model.setEnabled(true)
        await f.model.resolveChoice(.replaceLocal)
        let names = try await f.device.allProjects().map(\.name)
        #expect(f.model.isEnabled)
        #expect(names == ["Remote"])
    }

    @Test func cancelLeavesSyncOffAndDataAlone() async throws {
        let f = try await make(remoteData: true)
        await f.model.setEnabled(true)
        await f.model.resolveChoice(.cancel)
        let names = try await f.device.allProjects().map(\.name)
        #expect(!f.model.isChoosingExistingData)
        #expect(!f.model.isEnabled)
        #expect(names == ["Local"])
        #expect(f.server.records.count == 1)
    }

    @Test func unavailableAccountShowsErrorAndStaysOff() async throws {
        let f = try await make(remoteData: false)
        f.device.engine.account = .noAccount
        await f.model.setEnabled(true)
        #expect(!f.model.isEnabled)
        #expect(f.model.errorMessage == "Sign in to iCloud in System Settings to use iCloud Sync.")
        #expect(f.server.records.isEmpty)
    }

    @Test func offlineICloudShowsErrorAndStaysOff() async throws {
        let f = try await make(remoteData: false)
        f.server.isOnline = false
        await f.model.setEnabled(true)
        #expect(!f.model.isEnabled)
        #expect(f.model.errorMessage != nil)
    }

    @Test func turningOffAsksFirstAndKeepsData() async throws {                 // A4
        let f = try await make(remoteData: false)
        await f.model.setEnabled(true)
        await f.model.setEnabled(false)
        #expect(f.model.isConfirmingDisable)
        #expect(f.model.isEnabled)
        await f.model.confirmDisable()
        let names = try await f.device.allProjects().map(\.name)
        #expect(!f.model.isConfirmingDisable)
        #expect(!f.model.isEnabled)
        #expect(names == ["Local"])
        #expect(f.server.records.count == 1)
    }

    @Test func switchingOffWhileAlreadyOffAsksNothing() async throws {
        let f = try await make(remoteData: false)
        await f.model.setEnabled(false)
        #expect(!f.model.isConfirmingDisable)
    }

    @Test func accountNoticeIsShown() async throws {                            // A5
        let f = try await make(remoteData: false)
        await f.model.setEnabled(true)
        await f.device.service.disable(notice: "Sync turned off: you signed out of iCloud.")
        #expect(f.model.notices == ["Sync turned off: you signed out of iCloud."])
        #expect(!f.model.isEnabled)
    }

    @Test func statusTextMapsEachState() async throws {
        let f = try await make(remoteData: false)
        let service = f.device.service
        #expect(f.model.statusText == "Off")
        await f.model.setEnabled(true)
        #expect(f.model.statusText.hasPrefix("Last synced"))
        service.isSyncing = true
        #expect(f.model.statusText == "Syncing…")
        service.isSyncing = false
        service.pauseReason = "iCloud storage is full"
        #expect(f.model.statusText == "Sync paused: iCloud storage is full")
        service.pauseReason = nil
        service.errorMessage = "Boom"
        #expect(f.model.statusText == "Sync failed: Boom")
        service.errorMessage = nil
        service.hasRecordsFromNewerApp = true
        #expect(f.model.statusText == "Update Timelane on this device to keep syncing")
    }
}
