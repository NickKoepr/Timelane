import Foundation

/// What the settler changes: entries to insert or update, and entries to delete (by `syncId`).
struct TimeEntrySettlement: Equatable, Sendable {
    var saves: [SyncSettlerEntry]
    var deletes: [UUID]

    var isEmpty: Bool { saves.isEmpty && deletes.isEmpty }
}
