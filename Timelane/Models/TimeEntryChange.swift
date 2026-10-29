import Foundation

/// One user action on time entries: the affected rows before and after it.
struct TimeEntryChange: Equatable, Sendable {
    var before: [TimeEntry]   // rows (with ids) as they were; empty for a pure create
    var after: [TimeEntry]    // rows (with ids) as they are now; empty for a pure delete

    var inverted: TimeEntryChange { TimeEntryChange(before: after, after: before) }

    /// Ids of rows that exist before the change but not after it.
    var removedIds: [Int64] {
        let kept = Set(after.compactMap(\.id))
        return before.compactMap(\.id).filter { !kept.contains($0) }
    }
}
