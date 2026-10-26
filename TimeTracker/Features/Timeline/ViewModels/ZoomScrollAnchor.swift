import CoreGraphics
import Foundation

/// Remembers the visible part of the timeline scroll view and the time to keep centred across a zoom change.
/// Deliberately not observable: it is updated on every scroll frame and must not re-render views.
@MainActor
final class ZoomScrollAnchor {
    private(set) var offsetY: CGFloat = 0
    private(set) var height: CGFloat = 0
    private var pendingCenter: Date?

    func visibleAreaChanged(offsetY: CGFloat, height: CGFloat) {
        self.offsetY = offsetY
        self.height = height
    }

    /// Call before the scale changes, with the geometry that is currently drawn.
    func capture(with geometry: TimelineGeometry) {
        pendingCenter = TimelineZoomAnchor.centerDate(offset: offsetY, height: height, geometry: geometry)
    }

    /// Offset that keeps the captured time centred at the scale of `geometry`; nil when nothing was captured.
    /// Stays valid for every frame of an animated zoom, until `finish()`.
    func offset(with geometry: TimelineGeometry) -> CGFloat? {
        pendingCenter.map { TimelineZoomAnchor.offset(keeping: $0, centeredIn: height, geometry: geometry) }
    }

    func finish() { pendingCenter = nil }
}
