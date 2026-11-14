import Foundation

/// The iCloud zone was deleted by someone else. There is only one iCloud dataset, so this device follows it:
/// - another device chose "Replace iCloud data" (the zone exists again): local data is replaced by iCloud's;
/// - the data was removed (iCloud settings, or no zone after a few checks): sync turns off, local data stays.
extension SyncService {
    static let zoneRemovedNotice = "The iCloud data of Timelane was removed (on another device or in iCloud settings). "
        + "Sync was turned off; your data on this device is kept."
    static var replacedNotice: String { "Another device replaced the iCloud data, so the projects and hours on "
        + "\(DeviceKind.current.thisDevice) were replaced by the ones in iCloud." }

    /// Marks the reset; nothing is uploaded or applied until a sync round handled it.
    func noteRemoteReset() {
        guard !isResettingZone else { return }
        remoteResetPending = true
        scheduleSync()
    }

    func followRemoteReset() async throws {
        guard try await zoneExistsSoon() else {
            remoteResetPending = false
            await disable(notice: Self.zoneRemovedNotice)
            return
        }
        isResettingZone = true
        defer { isResettingZone = false }
        let links = try await store.wipeLocalSyncedData()
        try await store.setState(.engineState, nil)
        await engine.restartFresh()
        remoteResetPending = false
        try await engine.fetchChanges()
        try await store.relinkTrackedApps(links)
        notice = Self.replacedNotice
    }

    /// The replacing device deletes the zone and creates it again right away; give it a moment.
    private func zoneExistsSoon() async throws -> Bool {
        for attempt in 0..<3 {
            if try await engine.zoneExists() { return true }
            if attempt < 2 { try? await Task.sleep(for: zoneCheckDelay) }
        }
        return false
    }
}
