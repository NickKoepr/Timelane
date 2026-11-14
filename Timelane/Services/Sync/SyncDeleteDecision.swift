import Foundation

/// What to do when a delete and an edit meet. "Delete wins", except that a project that still has
/// time entries is brought back (the entry wins).
enum SyncDeleteDecision: Equatable, Sendable {
    /// Remove the local row and drop its pending save.
    case deleteLocal
    /// The project still has entries: keep it and upload it again with the same `syncId`.
    case resurrect
    /// Nothing to do: already gone locally (deleted on both devices).
    case alreadyGone

    /// A delete arrived from the server.
    static func forRemoteDelete(recordType: SyncRecordType, existsLocally: Bool, dependentEntryCount: Int) -> SyncDeleteDecision {
        guard existsLocally else { return .alreadyGone }
        if recordType == .project, dependentEntryCount > 0 { return .resurrect }
        return .deleteLocal
    }

    enum RemoteSave: Equatable, Sendable {
        case apply
        /// The row is deleted locally and that delete is still pending: the edit loses.
        case ignore
    }

    /// A modification arrived from the server.
    static func forRemoteSave(hasPendingLocalDelete: Bool) -> RemoteSave {
        hasPendingLocalDelete ? .ignore : .apply
    }

    enum MissingProject: Equatable, Sendable {
        /// Re-create the project from the tombstone copy of a locally deleted project.
        case resurrectFromTombstone
        /// No copy known: park the entry until the project shows up.
        case park
    }

    /// An entry arrived for a project that does not exist locally.
    static func forEntryWithMissingProject(hasTombstone: Bool) -> MissingProject {
        hasTombstone ? .resurrectFromTombstone : .park
    }

    /// A delete that the server rejects as `unknownItem` was deleted by someone else: success.
    static func deleteFailureCountsAsSuccess(isUnknownItem: Bool) -> Bool { isUnknownItem }
}
