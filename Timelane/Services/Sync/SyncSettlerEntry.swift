import Foundation

/// A time entry as the settler sees it.
struct SyncSettlerEntry: Equatable, Sendable {
    var syncId: UUID
    var fields: TimeEntryFields
}
