import CoreGraphics
import Foundation

/// Pure mapping between time and vertical position on the timeline of one day.
/// Uses the real duration of the day (23/25 hours on DST changes).
struct TimelineGeometry: Equatable, Sendable {
    static let defaultPointsPerHour: CGFloat = 80

    let day: DateRange
    var pointsPerHour: CGFloat = TimelineGeometry.defaultPointsPerHour
    var snapMinutes: Int = 5

    var totalHeight: CGFloat { CGFloat(day.duration / 3600) * pointsPerHour }

    func y(for date: Date) -> CGFloat {
        let seconds = min(max(date.timeIntervalSince(day.start), 0), day.duration)
        return CGFloat(seconds / 3600) * pointsPerHour
    }

    /// Clamped to the day.
    func date(forY y: CGFloat) -> Date {
        let seconds = Double(y / pointsPerHour) * 3600
        return day.start.addingTimeInterval(min(max(seconds, 0), day.duration))
    }

    /// Rounds to the nearest `snapMinutes`, measured from the start of the day.
    func snapped(_ date: Date) -> Date {
        let step = Double(snapMinutes * 60)
        let offset = date.timeIntervalSince(day.start)
        let rounded = (offset / step).rounded() * step
        return day.start.addingTimeInterval(min(max(rounded, 0), day.duration))
    }

    /// Frame of a time range, clipped to the day.
    func frame(for start: Date, end: Date) -> (y: CGFloat, height: CGFloat) {
        let top = y(for: start)
        return (top, max(y(for: end) - top, 0))
    }
}
