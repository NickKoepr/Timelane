import CoreGraphics

/// Horizontal layout constants shared by the timeline views.
enum TimelineMetrics {
    static let labelWidth: CGFloat = 54
    /// Tracked apps get 1/3 of the lane width, "Logged hours" the other 2/3.
    static let appLaneFraction: CGFloat = 1.0 / 3.0
    static let laneSpacing: CGFloat = 8
    static let laneInset: CGFloat = 2
}
