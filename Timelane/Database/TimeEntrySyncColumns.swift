import Foundation
import GRDB

/// Keeps the per-field-group timestamps of `timeEntry` in step with saves. A group's timestamp only
/// moves when one of its fields really changed, so two devices editing different groups can merge.
enum TimeEntrySyncColumns {
    /// Dates are stored as Doubles; smaller differences are round-trip noise, not edits.
    private static let tolerance: TimeInterval = 0.001

    /// Call right after `saved` was written. `previous` is the row as stored before (nil for an insert).
    static func stamp(_ db: Database, saved: TimeEntry, previous: TimeEntry?) throws {
        guard let id = saved.id else { return }
        let times = previous.map { !sameTimes($0, saved) } ?? true
        let text = previous.map { $0.title != saved.title || $0.note != saved.note } ?? true
        let project = previous.map { $0.projectId != saved.projectId } ?? true

        var assignments: [String] = []
        var values: [any DatabaseValueConvertible] = []
        let stamp = saved.updatedAt.timeIntervalSince1970
        for (changed, column) in [(times, "timesUpdatedAt"), (text, "textUpdatedAt"), (project, "projectUpdatedAt")]
        where changed {
            assignments.append("\(column) = ?")
            values.append(stamp)
        }
        guard !assignments.isEmpty else { return }
        values.append(id)
        try db.execute(sql: "UPDATE timeEntry SET \(assignments.joined(separator: ", ")) WHERE id = ?",
                       arguments: StatementArguments(values))
    }

    private static func sameTimes(_ a: TimeEntry, _ b: TimeEntry) -> Bool {
        abs(a.start.timeIntervalSince(b.start)) < tolerance && abs(a.end.timeIntervalSince(b.end)) < tolerance
    }
}
