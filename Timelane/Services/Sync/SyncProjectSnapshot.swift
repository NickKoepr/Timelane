import Foundation

/// A project as the conflict resolver sees it: synced fields plus the local id (nil if not stored yet).
struct SyncProjectSnapshot: Equatable, Sendable {
    var localId: Int64?
    var syncId: UUID
    var fields: ProjectFields
}
