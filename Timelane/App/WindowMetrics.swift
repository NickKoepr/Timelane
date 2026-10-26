import CoreGraphics

/// Smallest sizes at which every screen still lays out correctly.
enum WindowMetrics {
    static let sidebarMinimumWidth: CGFloat = 160
    /// The narrowest day bar variant needs ≈ 440 pt (‹ Today › + short title + zoom, plus 32 pt padding);
    /// 480 leaves room for the scroll bar and the time-axis column of the timeline below it.
    static let detailMinimumWidth: CGFloat = 480
    /// Sidebar + detail + divider/margins, rounded up.
    static let minimumSize = CGSize(width: 700, height: 520)
}
