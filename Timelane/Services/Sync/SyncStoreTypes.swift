import Foundation

/// Keys of the small `syncState` table.
enum SyncStateKey: String, Sendable {
    case enabled
    case engineState
    case lastSync
}

/// One row of the outbox: a record with a local change that still has to reach the server.
struct SyncOutboxItem: Equatable, Sendable {
    enum Kind: String, Sendable {
        case save
        case delete
    }

    var id: SyncRecordID
    var kind: Kind
}

/// Changes received from the server, applied in one transaction.
struct SyncInboundBatch: Equatable, Sendable {
    var saves: [SyncServerRecord] = []
    var deletes: [SyncRecordID] = []

    var isEmpty: Bool { saves.isEmpty && deletes.isEmpty }
}

/// What applying an inbound batch did, for the service to report.
struct SyncApplyResult: Equatable, Sendable {
    /// Local ids of time entries that a remote change updated or removed (undo history must forget them, E1).
    var changedEntryIds: Set<Int64> = []
    /// Records whose local version still differs from the server's: send them again.
    var requeue: [SyncRecordID] = []
    /// Names of projects that lost their customer id because another project has the same one (C3).
    var clearedCustomIdProjects: [String] = []
    /// Some record came from a newer app version and is parked (E4).
    var hasRecordsFromNewerApp = false
}

struct SyncParkedRecord: Equatable, Sendable {
    var record: SyncRecord
    var reason: String
}

/// A tracked app's project link, remembered by project name while the projects are replaced (A1).
struct SyncTrackedAppLink: Equatable, Sendable {
    var bundleIdentifier: String
    var projectName: String
}

enum SyncParkReason {
    static let missingProject = "Waiting for its project"
    static let newerApp = "Update Timelane on this device"
    static let invalid = "Invalid time range"
}
