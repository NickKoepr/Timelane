import Foundation

/// Registered seconds per calendar day, per project, for one year. Entries are clipped to the year
/// and split at midnight (an entry 23:00–01:00 adds 1 h to each day). DST-safe: days come from the calendar.
struct YearActivity: Sendable, Hashable {
    let year: DateRange
    /// Start of day → project id → seconds. Only days with time.
    let secondsByDay: [Date: [Int64: TimeInterval]]

    init(entries: [TimeEntry], year: DateRange, calendar: Calendar) {
        var result: [Date: [Int64: TimeInterval]] = [:]
        for entry in entries {
            guard let clipped = entry.range.intersection(with: year) else { continue }
            var day = calendar.startOfDay(for: clipped.start)
            while day < clipped.end {
                let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
                if let part = clipped.intersection(with: DateRange(start: day, end: next)) {
                    result[day, default: [:]][entry.projectId, default: 0] += part.duration
                }
                day = next
            }
        }
        self.year = year
        self.secondsByDay = result
    }

    func seconds(on day: Date, projectId: Int64?) -> TimeInterval {
        guard let perProject = secondsByDay[day] else { return 0 }
        return Self.sum(perProject, projectId: projectId)
    }

    func dailyTotals(projectId: Int64?) -> [Date: TimeInterval] {
        var totals: [Date: TimeInterval] = [:]
        for (day, perProject) in secondsByDay {
            let seconds = Self.sum(perProject, projectId: projectId)
            if seconds > 0 { totals[day] = seconds }
        }
        return totals
    }

    func projectTotals() -> [Int64: TimeInterval] {
        var totals: [Int64: TimeInterval] = [:]
        for perProject in secondsByDay.values {
            for (id, seconds) in perProject { totals[id, default: 0] += seconds }
        }
        return totals
    }

    /// 12 items (one per month, in order), each project id → seconds; respects the filter.
    func monthlyTotals(projectId: Int64?, calendar: Calendar) -> [[Int64: TimeInterval]] {
        var months = Array(repeating: [Int64: TimeInterval](), count: 12)
        for (day, perProject) in secondsByDay {
            let index = calendar.component(.month, from: day) - 1
            guard months.indices.contains(index) else { continue }
            for (id, seconds) in perProject where projectId == nil || projectId == id {
                months[index][id, default: 0] += seconds
            }
        }
        return months
    }

    private static func sum(_ perProject: [Int64: TimeInterval], projectId: Int64?) -> TimeInterval {
        if let projectId { return perProject[projectId] ?? 0 }
        return perProject.values.reduce(0, +)
    }
}
