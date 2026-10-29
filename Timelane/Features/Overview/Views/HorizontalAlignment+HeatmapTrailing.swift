import SwiftUI

extension HorizontalAlignment {
    private enum HeatmapTrailing: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context[.trailing] }
    }

    /// The trailing edge of the heatmap's last squares, so the legend sits under them instead of at the far edge.
    static let heatmapTrailing = HorizontalAlignment(HeatmapTrailing.self)
}
