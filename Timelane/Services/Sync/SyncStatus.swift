import Foundation

enum SyncStatus: Equatable, Sendable {
    case off
    case idle(lastSync: Date?)
    case syncing
    case paused(reason: String)
    case needsAppUpdate
    case error(String)
}

/// How to turn sync on when local and iCloud data may both exist (A1).
enum SyncEnableChoice: Equatable, Sendable {
    /// Upload every local project and entry; iCloud is emptied first when it has data ("Replace iCloud with this device").
    case replaceICloud
    /// Wipe local projects and entries and download everything from iCloud ("Replace this device with iCloud").
    case replaceLocal
}
