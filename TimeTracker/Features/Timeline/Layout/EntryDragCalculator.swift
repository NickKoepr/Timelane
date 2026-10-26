import CoreGraphics
import Foundation

/// Pure math for moving and resizing an entry by dragging. Results are snapped and kept inside the day.
enum EntryDragCalculator {
    /// `original` must lie within `geometry.day`.
    static func range(for mode: EntryDragMode, original: DateRange, translationY: CGFloat,
                      geometry: TimelineGeometry, minimumDuration: TimeInterval) -> DateRange {
        let delta = Double(translationY / geometry.pointsPerHour) * 3600
        let day = geometry.day

        switch mode {
        case .move:
            var start = geometry.snapped(original.start.addingTimeInterval(delta))
            var end = start.addingTimeInterval(original.duration)
            if end > day.end {
                end = day.end
                start = end.addingTimeInterval(-original.duration)
            }
            return DateRange(start: start, end: end)
        case .resizeTop:
            let start = min(geometry.snapped(original.start.addingTimeInterval(delta)),
                            original.end.addingTimeInterval(-minimumDuration))
            return DateRange(start: start, end: original.end)
        case .resizeBottom:
            let end = max(geometry.snapped(original.end.addingTimeInterval(delta)),
                          original.start.addingTimeInterval(minimumDuration))
            return DateRange(start: original.start, end: end)
        }
    }
}
