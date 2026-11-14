import Foundation

enum SyncAccountChange: Equatable, Sendable {
    case signIn
    case signOut
    case switchAccounts
}

/// What an engine reports to `SyncService`, as plain values.
enum SyncEngineEvent: Sendable {
    /// Opaque engine state to persist; handed back to `start(stateSerialization:)` on the next launch.
    case stateUpdate(Data)
    case accountChange(SyncAccountChange)
    case fetched(saves: [SyncServerRecord], deletes: [SyncRecordID])
    /// `saved` holds the records as they were sent, with the new system fields.
    case sent(saved: [SyncServerRecord], deleted: [SyncRecordID], failed: [SyncFailedSend])
    /// The zone was deleted by someone else (another device reset iCloud, or the user cleared the data).
    case zoneDeleted
}
