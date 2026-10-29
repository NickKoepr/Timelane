import Foundation

/// Everything one export contains, independent of the file format.
struct MonthExport: Sendable, Hashable {
    struct ProjectTotal: Sendable, Hashable {
        var name: String
        var colorHex: String
        var isArchived: Bool
        var totalSeconds: TimeInterval
    }

    struct Entry: Sendable, Hashable {
        var projectName: String
        var start: Date        // clipped to the month
        var end: Date          // clipped to the month
        var title: String?
        var note: String?
        var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    var month: DateRange
    var generatedAt: Date
    var timeZone: TimeZone
    var projects: [ProjectTotal]   // only projects with hours this month, sorted by total desc, then name
    var entries: [Entry]           // sorted by start
    var totalSeconds: TimeInterval { projects.reduce(0) { $0 + $1.totalSeconds } }
}
