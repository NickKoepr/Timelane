import SwiftUI

/// GitHub-style grid: one square per day (column = week, row = weekday), brighter for more hours.
/// Squares grow to fill the width (9–16 pt); below 9 pt the grid scrolls horizontally, newest weeks first in view.
struct ActivityHeatmap: View {
    let layout: ActivityHeatmapLayout
    let dailyTotals: [Date: TimeInterval]
    let today: Date
    let dayDetail: (Date) -> OverviewDayDetail
    let onSelectDay: (Date) -> Void

    private let spacing: CGFloat = 2
    private let labelWidth: CGFloat = 32
    private let monthRowHeight: CGFloat = 16
    private let cellRange: ClosedRange<CGFloat> = 9...16

    @State private var width: CGFloat = 0
    @State private var hover = HeatmapHoverState()

    var body: some View {
        let sizing = heatmapSizing(for: width)
        let cell = sizing.cell
        HStack(alignment: .top, spacing: 0) {
            weekdayLabels(cell: cell)
            if sizing.scrolls {
                ScrollView(.horizontal, showsIndicators: false) { grid(cell: cell) }
                    .defaultScrollAnchor(.trailing)
                    .onScrollPhaseChange { _, phase in if phase != .idle { hover.clear() } }
            } else {
                grid(cell: cell)
            }
        }
        // minWidth 0: measure the offered width, not the grid's, or the heatmap never switches to scrolling.
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .frame(height: monthRowHeight + 7 * step(cell))
        // From the laid-out width, not the `width` state: that lags one pass behind while resizing, and a guide
        // past the frame makes the stack wider than its column, which re-triggers layout in a loop (AppKit crash).
        .alignmentGuide(.heatmapTrailing) { d in heatmapSizing(for: d.width).visibleTrailing(in: d.width) }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .coordinateSpace(name: "heatmap")
        .overlay(alignment: .topLeading) { hoverCard }
        .onDisappear { hover.clear() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Registered hours per day")
    }

    /// Drawn on the outer view (outside the horizontal scroll view), so it is never clipped.
    @ViewBuilder private var hoverCard: some View {
        if let day = hover.day, let frame = hover.frame {
            HeatmapDayHoverCard(detail: dayDetail(day), squareFrame: frame, heatmapWidth: width)
        }
    }

    private func heatmapSizing(for width: CGFloat) -> ActivityHeatmapSizing {
        ActivityHeatmapSizing(availableWidth: width, columnCount: layout.columnCount,
                              labelWidth: labelWidth, spacing: spacing, cellRange: cellRange)
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
            .onHover { inside in
                if inside { hover.enter(day: square.day) } else { hover.leave(day: square.day) }
            }
            .background {
                // Only the hovered square reads its frame, so the grid doesn't carry 371 geometry observers.
                if hover.day == square.day {
                    Color.clear.onGeometryChange(for: CGRect.self) { $0.frame(in: .named("heatmap")) } action: {
                        hover.update(frame: $0)
                    }
                }
            }
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
    return VStack(alignment: .heatmapTrailing) {
        ActivityHeatmap(layout: ActivityHeatmapLayout(year: year, calendar: calendar),
                        dailyTotals: totals, today: start,
                        dayDetail: { OverviewDayDetail(day: $0, secondsByProject: [:], projects: [], highlightedProjectId: nil) },
                        onSelectDay: { _ in })
        ActivityLegend()
    }
    .padding()
    .frame(width: 800)
}
