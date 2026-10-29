import SwiftUI

/// Total · Active days · Average per active day · Longest streak · Busiest day. Wraps to 2–3 columns when narrow.
struct OverviewStatTiles: View {
    let statistics: ActivityStatistics
    let showsCurrentStreak: Bool

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            OverviewStatTile(title: "Total hours", value: DurationFormatter.short(statistics.totalSeconds))
            OverviewStatTile(title: "Active days", value: "\(statistics.activeDays)")
            OverviewStatTile(title: "Average per active day",
                             value: DurationFormatter.short(statistics.averagePerActiveDay))
            OverviewStatTile(title: "Longest streak", value: dayCount(statistics.longestStreak),
                             caption: showsCurrentStreak ? "Current: \(dayCount(statistics.currentStreak))" : nil)
            OverviewStatTile(title: "Busiest day",
                             value: statistics.busiestDay.map { DurationFormatter.short($0.seconds) } ?? "–",
                             caption: statistics.busiestDay.map { $0.day.formatted(.dateTime.day().month(.abbreviated)) })
        }
    }

    private func dayCount(_ days: Int) -> String { days == 1 ? "1 day" : "\(days) days" }
}

#Preview {
    let calendar = Calendar.current
    let year = DateRange.year(of: .now, calendar: calendar)
    let day = calendar.startOfDay(for: .now)
    let statistics = ActivityStatistics(dailyTotals: [day: 7200], year: year, today: day, calendar: calendar)
    return OverviewStatTiles(statistics: statistics, showsCurrentStreak: true).padding().frame(width: 480)
}
