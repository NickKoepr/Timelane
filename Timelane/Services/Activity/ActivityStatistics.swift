import Foundation

/// Summary numbers of a year for the project filter.
struct ActivityStatistics: Sendable, Hashable {
    struct BusiestDay: Sendable, Hashable {
        let day: Date
        let seconds: TimeInterval
    }

    let totalSeconds: TimeInterval
    /// Days with more than 0 s.
    let activeDays: Int
    /// 0 when there are no active days.
    let averagePerActiveDay: TimeInterval
    let busiestDay: BusiestDay?

    init(dailyTotals: [Date: TimeInterval]) {
        let active = dailyTotals.filter { $0.value > 0 }
        totalSeconds = active.values.reduce(0, +)
        activeDays = active.count
        averagePerActiveDay = active.isEmpty ? 0 : totalSeconds / Double(active.count)
        busiestDay = active.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key > rhs.key   // ties: earliest day wins
        }.map { BusiestDay(day: $0.key, seconds: $0.value) }
    }
}
