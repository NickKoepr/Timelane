import Foundation

/// A record as the server has it: the plain value plus the opaque system fields (change tag) of that version.
struct SyncServerRecord: Equatable, Sendable {
    var record: SyncRecord
    var systemFields: Data
}

/// A record the engine is about to upload. `systemFields` is nil for a record the server has never seen.
struct SyncUploadRecord: Equatable, Sendable {
    var record: SyncRecord
    var systemFields: Data?
}
