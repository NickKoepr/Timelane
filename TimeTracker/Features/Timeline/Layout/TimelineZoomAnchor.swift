import CoreGraphics
import Foundation

/// Pure math to keep the time in the middle of the visible area in place when the scale changes.
enum TimelineZoomAnchor {
    /// The time at the centre of a visible area.
    static func centerDate(offset: CGFloat, height: CGFloat, geometry: TimelineGeometry) -> Date {
        geometry.date(forY: offset + height / 2)
    }

    /// Scroll offset that puts `date` in the centre of a visible area of `height` (never negative).
    static func offset(keeping date: Date, centeredIn height: CGFloat, geometry: TimelineGeometry) -> CGFloat {
        max(geometry.y(for: date) - height / 2, 0)
    }
}
