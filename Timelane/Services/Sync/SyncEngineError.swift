import Foundation

/// Errors an engine throws from `fetchChanges`/`sendChanges`; `SyncService` turns them into a status.
enum SyncEngineError: Error, Equatable, Sendable {
    case offline
    case quotaExceeded
    case notStarted
    case other(String)
}
