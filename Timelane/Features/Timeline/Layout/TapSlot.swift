import CoreGraphics
import Foundation

/// The time slot a tap on an empty spot of the timeline stands for (touch screens): a block of
/// `TimelineZoom.tapSlotMinutes` that starts on that grid and contains the tapped time.
enum TapSlot {
    /// The slot at vertical position `y`; never leaves the day.
    static func range(atY y: CGFloat, geometry: TimelineGeometry, zoom: TimelineZoom) -> DateRange {
        let length = Double(zoom.tapSlotMinutes * 60)
        let offset = geometry.date(forY: y).timeIntervalSince(geometry.day.start)
        let floored = geometry.day.start.addingTimeInterval((offset / length).rounded(.down) * length)
        // A tap on the very last pixel of the day still gives a full slot (the one before midnight).
        let start = max(min(floored, geometry.day.end.addingTimeInterval(-length)), geometry.day.start)
        return DateRange(start: start, end: min(start.addingTimeInterval(length), geometry.day.end))
    }
}

extension TimelineZoom {
    /// Length of the entry a tap creates: 30 minutes when zoomed out, the zoom step when zoomed in.
    var tapSlotMinutes: Int {
        switch self {
        case .hour, .halfHour: 30
        case .quarterHour: 15
        case .tenMinutes: 10
        }
    }
}
