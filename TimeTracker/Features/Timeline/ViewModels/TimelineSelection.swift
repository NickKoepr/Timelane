import Foundation

/// The time range being dragged on the timeline. Handles dragging upwards.
struct TimelineSelection: Equatable {
    var anchor: Date
    var current: Date

    init(anchor: Date, current: Date) {
        self.anchor = anchor
        self.current = current
    }

    init(range: DateRange) {
        self.init(anchor: range.start, current: range.end)
    }

    var start: Date { min(anchor, current) }
    var end: Date { max(anchor, current) }
    var duration: TimeInterval { end.timeIntervalSince(start) }
    var range: DateRange { DateRange(start: start, end: end) }

    /// "10:00 – 13:00 (3:00)"
    var label: String {
        let from = start.formatted(date: .omitted, time: .shortened)
        let to = end.formatted(date: .omitted, time: .shortened)
        return "\(from) – \(to) (\(DurationFormatter.hoursMinutes(duration)))"
    }
}
