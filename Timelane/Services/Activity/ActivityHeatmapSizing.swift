import CoreGraphics

/// Square size of the heatmap for an available width: grows to fill (within `cellRange`), scrolls below the minimum.
struct ActivityHeatmapSizing: Equatable, Sendable {
    let cell: CGFloat
    let scrolls: Bool
    /// Trailing edge of the last square column (weekday labels included); can exceed the width when it scrolls.
    let contentWidth: CGFloat

    init(availableWidth: CGFloat, columnCount: Int, labelWidth: CGFloat, spacing: CGFloat,
         cellRange: ClosedRange<CGFloat>) {
        if columnCount > 0, availableWidth > 0 {
            let fitted = (availableWidth - labelWidth) / CGFloat(columnCount) - spacing
            cell = min(max(fitted, cellRange.lowerBound), cellRange.upperBound)
            scrolls = fitted < cellRange.lowerBound
        } else {
            cell = cellRange.lowerBound
            scrolls = true
        }
        contentWidth = labelWidth + CGFloat(max(columnCount, 0)) * (cell + spacing) - spacing
    }

    /// Where content below the heatmap (the legend) ends: under the last squares, or at the edge while scrolling.
    func visibleTrailing(in availableWidth: CGFloat) -> CGFloat {
        min(contentWidth, availableWidth)
    }
}
