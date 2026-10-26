import CoreGraphics

/// Horizontal geometry of the two lanes for a given column width (x relative to the column's leading edge).
/// Used by `TimelineColumn` and `TimelineLaneHeader`, so header and lanes can never drift apart.
struct TimelineLaneLayout: Equatable {
    let totalWidth: CGFloat

    init(totalWidth: CGFloat) { self.totalWidth = max(totalWidth, 0) }

    /// Width shared by both lanes (without the gap between them).
    var availableWidth: CGFloat {
        max(totalWidth - TimelineMetrics.labelWidth - TimelineMetrics.laneSpacing - TimelineMetrics.laneInset * 2, 0)
    }

    var appX: CGFloat { TimelineMetrics.labelWidth + TimelineMetrics.laneInset }
    var appWidth: CGFloat { availableWidth * TimelineMetrics.appLaneFraction }
    var entryX: CGFloat { appX + appWidth + TimelineMetrics.laneSpacing }
    var entryWidth: CGFloat { availableWidth - appWidth }
    /// Centre of the gap between the lanes.
    var dividerX: CGFloat { appX + appWidth + TimelineMetrics.laneSpacing / 2 }
}
