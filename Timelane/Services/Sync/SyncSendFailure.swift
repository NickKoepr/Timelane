import Foundation

/// Why one record could not be sent. Plain values: no CloudKit types.
enum SyncSendFailure: Equatable, Sendable {
    /// The server has a newer version; merge with it and send again.
    case serverRecordChanged(server: SyncRecord, systemFields: Data)
    /// The record does not exist on the server: for a delete that is success (B4).
    case unknownItem
    case zoneNotFound
    case quotaExceeded
    case networkUnavailable
    case other(String)
}

struct SyncFailedSend: Equatable, Sendable {
    var id: SyncRecordID
    var isDelete: Bool
    var failure: SyncSendFailure
}
