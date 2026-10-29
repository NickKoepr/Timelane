import SwiftUI

/// GitHub-style grid: one square per day (column = week, row = weekday), brighter for more hours.
/// Squares grow to fill the width (9–16 pt); below 9 pt the grid scrolls horizontally, newest weeks first in view.
struct ActivityHeatmap: View {
    let layout: ActivityHeatmapLayout
    let dailyTotals: [Date: TimeInterval]
    let today: Date
    let onSelectDay: (Date) -> Void

    private let spacing: CGFloat = 2
    private let labelWidth: CGFloat = 32
    private let monthRowHeight: CGFloat = 16
    private let cellRange: ClosedRange<CGFloat> = 9...16

    var body: some View {
        GeometryReader { proxy in
            let fitted = (proxy.size.width - labelWidth) / CGFloat(layout.columnCount) - spacing
            let cell = min(max(fitted, cellRange.lowerBound), cellRange.upperBound)
            HStack(alignment: .top, spacing: 0) {
                weekdayLabels(cell: cell)
                if fitted < cellRange.lowerBound {
                    ScrollView(.horizontal, showsIndicators: false) { grid(cell: cell) }
                        .defaultScrollAnchor(.trailing)
                } else {
                    grid(cell: cell)
                }
            }
        }
        .frame(height: monthRowHeight + 7 * (cellRange.upperBound + spacing))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Registered hours per day")
    }

    private func step(_ cell: CGFloat) -> CGFloat { cell + spacing }

    private func weekdayLabels(cell: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.weekdayLabels, id: \.row) { label in
                Text(label.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: labelWidth - 4, height: cell, alignment: .leading)
                    .offset(y: monthRowHeight + CGFloat(label.row) * step(cell))
            }
        }
        .frame(width: labelWidth, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private func grid(cell: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.monthLabels, id: \.column) { label in
                Text(label.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .offset(x: CGFloat(label.column) * step(cell))
                    .accessibilityHidden(true)
            }
            ForEach(layout.cells, id: \.day) { square in
                let seconds = dailyTotals[square.day] ?? 0
                let isFuture = square.day > today
                RoundedRectangle(cornerRadius: 2)
                    .fill(ActivityLevel(seconds: seconds).color)
                    .opacity(isFuture ? 0.5 : 1)
                    .frame(width: cell, height: cell)
                    .contentShape(Rectangle())
                    .offset(x: CGFloat(square.column) * step(cell),
                            y: monthRowHeight + CGFloat(square.row) * step(cell))
                    .onTapGesture { onSelectDay(square.day) }
                    .help(description(of: square.day, seconds: seconds))
                    .accessibilityElement()
                    .accessibilityLabel(description(of: square.day, seconds: seconds))
            }
        }
        .frame(width: CGFloat(layout.columnCount) * step(cell),
               height: monthRowHeight + 7 * step(cell), alignment: .topLeading)
    }

    /// "Tue, 3 Mar 2026 · 5h 30m" (or "No hours").
    private func description(of day: Date, seconds: TimeInterval) -> String {
        let date = day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
        return "\(date) · \(seconds > 0 ? DurationFormatter.short(seconds) : "No hours")"
    }
}

#Preview {
    let calendar = Calendar.current
    let year = DateRange.year(of: .now, calendar: calendar)
    let start = calendar.startOfDay(for: .now)
    let totals = Dictionary(uniqueKeysWithValues: (0..<60).compactMap { offset -> (Date, TimeInterval)? in
        calendar.date(byAdding: .day, value: -offset, to: start).map { ($0, Double(offset % 7) * 3600) }
    })
    return VStack(alignment: .trailing) {
        ActivityHeatmap(layout: ActivityHeatmapLayout(year: year, calendar: calendar),
                        dailyTotals: totals, today: start, onSelectDay: { _ in })
        ActivityLegend()
    }
    .padding()
    .frame(width: 800)
}
