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

    @State private var width: CGFloat = 0

    var body: some View {
        let fitted = (width - labelWidth) / CGFloat(layout.columnCount) - spacing
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: monthRowHeight + 7 * step(cell))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Registered hours per day")
    }

    private func step(_ cell: CGFloat) -> CGFloat { cell + spacing }

    private func weekdayLabels(cell: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            Color.clear.frame(height: monthRowHeight - spacing)
            ForEach(0..<7, id: \.self) { row in
                Text(layout.weekdayLabels.first { $0.row == row }?.title ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: labelWidth - 4, height: cell, alignment: .leading)
            }
        }
        .frame(width: labelWidth, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    /// Real rows and columns (no offsets), so tooltips and clicks land on the square that is drawn.
    private func grid(cell: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                ForEach(layout.monthLabels, id: \.column) { label in
                    Text(label.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .offset(x: CGFloat(label.column) * step(cell))
                }
            }
            .frame(width: CGFloat(layout.columnCount) * step(cell), height: monthRowHeight, alignment: .topLeading)
            .accessibilityHidden(true)
            HStack(alignment: .top, spacing: spacing) {
                ForEach(Array(layout.weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { row in
                            if let day = week[row] {
                                square(day, cell: cell)
                            } else {
                                Color.clear.frame(width: cell, height: cell)
                            }
                        }
                    }
                }
            }
        }
    }

    private func square(_ square: ActivityHeatmapLayout.Cell, cell: CGFloat) -> some View {
        let seconds = dailyTotals[square.day] ?? 0
        return RoundedRectangle(cornerRadius: 2)
            .fill(ActivityLevel(seconds: seconds).color)
            .opacity(square.day > today ? 0.5 : 1)
            .frame(width: cell, height: cell)
            .contentShape(Rectangle())
            .onTapGesture { onSelectDay(square.day) }
            .help(description(of: square.day, seconds: seconds))
            .accessibilityElement()
            .accessibilityLabel(description(of: square.day, seconds: seconds))
            .accessibilityAddTraits(.isButton)
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
