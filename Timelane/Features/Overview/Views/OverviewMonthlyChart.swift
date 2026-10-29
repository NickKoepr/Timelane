import Charts
import SwiftUI

/// Hours per month for the year, stacked by project color. The project list below acts as the legend.
struct OverviewMonthlyChart: View {
    let year: DateRange
    let bars: [OverviewMonthBar]

    var body: some View {
        let names = Array(Set(bars.map(\.projectName))).sorted()
        let colors = names.map { name in
            bars.first { $0.projectName == name }.map { ProjectColor.color(hex: $0.colorHex) } ?? .gray
        }
        Chart(bars) { bar in
            BarMark(x: .value("Month", bar.monthStart, unit: .month),
                    y: .value("Hours", bar.seconds / 3600))
                .foregroundStyle(by: .value("Project", bar.projectName))
        }
        .chartForegroundStyleScale(domain: names, range: colors)
        .chartLegend(.hidden)
        .chartXScale(domain: year.start...year.end)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
            }
        }
        .chartYAxisLabel("Hours")
        .frame(height: 180)
    }
}

#Preview {
    let calendar = Calendar.current
    let year = DateRange.year(of: .now, calendar: calendar)
    let bars = (0..<12).flatMap { month -> [OverviewMonthBar] in
        let start = calendar.date(byAdding: .month, value: month, to: year.start)!
        return [
            OverviewMonthBar(monthStart: start, projectId: 1, projectName: "Alpha", colorHex: "#4F8EF7", seconds: Double(40 + month * 5) * 3600),
            OverviewMonthBar(monthStart: start, projectId: 2, projectName: "Beta", colorHex: "#34C759", seconds: Double(20) * 3600),
        ]
    }
    return OverviewMonthlyChart(year: year, bars: bars).padding().frame(width: 600)
}
