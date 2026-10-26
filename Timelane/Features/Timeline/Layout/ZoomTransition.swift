import CoreGraphics
import Foundation

/// Interpolates the timeline scale between two zoom levels with an ease-in-out curve.
struct ZoomTransition: Equatable {
    static let defaultDuration: TimeInterval = 0.25

    let from: CGFloat
    let to: CGFloat
    var duration: TimeInterval = ZoomTransition.defaultDuration

    /// Scale after `elapsed` seconds; exactly `to` once the transition is finished.
    func pointsPerHour(after elapsed: TimeInterval) -> CGFloat {
        guard !isFinished(after: elapsed) else { return to }
        let t = max(elapsed, 0) / duration
        let eased = t < 0.5 ? 2 * t * t : 1 - pow(2 - 2 * t, 2) / 2
        return from + (to - from) * CGFloat(eased)
    }

    func isFinished(after elapsed: TimeInterval) -> Bool { duration <= 0 || elapsed >= duration }
}
