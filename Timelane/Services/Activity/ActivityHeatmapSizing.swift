import CoreGraphics

/// Square size of the heatmap for an available width: grows to fill (within `cellRange`), scrolls below the minimum.
struct ActivityHeatmapSizing: Equatable, Sendable {
    let cell: CGFloat
    let scrolls: Bool

    init(availableWidth: CGFloat, columnCount: Int, labelWidth: CGFloat, spacing: CGFloat,
         cellRange: ClosedRange<CGFloat>) {
        guard columnCount > 0, availableWidth > 0 else {
            cell = cellRange.lowerBound
            scrolls = true
            return
        }
        let fitted = (availableWidth - labelWidth) / CGFloat(columnCount) - spacing
        cell = min(max(fitted, cellRange.lowerBound), cellRange.upperBound)
        scrolls = fitted < cellRange.lowerBound
    }
}
