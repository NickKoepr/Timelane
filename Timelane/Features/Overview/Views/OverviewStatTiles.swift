import SwiftUI

/// Total · Active days · Average per active day · Busiest day. Wraps to 2–3 columns when narrow.
struct OverviewStatTiles: View {
    let statistics: ActivityStatistics

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            OverviewStatTile(title: "Total hours", value: DurationFormatter.short(statistics.totalSeconds))
            OverviewStatTile(title: "Active days", value: "\(statistics.activeDays)")
            OverviewStatTile(title: "Average per active day",
                             value: DurationFormatter.short(statistics.averagePerActiveDay))
            OverviewStatTile(title: "Busiest day",
                             value: statistics.busiestDay.map { DurationFormatter.short($0.seconds) } ?? "–",
                             caption: statistics.busiestDay.map { $0.day.formatted(.dateTime.day().month(.abbreviated)) })
        }
    }
}

#Preview {
    let day = Calendar.current.startOfDay(for: .now)
    let statistics = ActivityStatistics(dailyTotals: [day: 7200])
    return OverviewStatTiles(statistics: statistics).padding().frame(width: 480)
}
