import Foundation

/// Summary numbers of a year for the project filter.
/// Streaks count consecutive calendar days with time; a day without hours (weekends too) breaks them.
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
    let longestStreak: Int
    /// Streak ending today or yesterday; 0 when `today` is not inside the year.
    let currentStreak: Int
    let busiestDay: BusiestDay?

    init(dailyTotals: [Date: TimeInterval], year: DateRange, today: Date, calendar: Calendar) {
        let active = dailyTotals.filter { $0.value > 0 }
        totalSeconds = active.values.reduce(0, +)
        activeDays = active.count
        averagePerActiveDay = active.isEmpty ? 0 : totalSeconds / Double(active.count)
        busiestDay = active.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key > rhs.key   // ties: earliest day wins
        }.map { BusiestDay(day: $0.key, seconds: $0.value) }

        func previous(_ day: Date) -> Date { calendar.date(byAdding: .day, value: -1, to: day) ?? day }

        var longest = 0, run = 0
        var last: Date?
        for day in active.keys.sorted() {
            run = last.map { previous(day) == $0 } == true ? run + 1 : 1
            longest = max(longest, run)
            last = day
        }
        longestStreak = longest

        let todayStart = calendar.startOfDay(for: today)
        if year.contains(todayStart) {
            var day = active[todayStart] != nil ? todayStart : previous(todayStart)
            var streak = 0
            while active[day] != nil {
                streak += 1
                day = previous(day)
            }
            currentStreak = streak
        } else {
            currentStreak = 0
        }
    }
}
