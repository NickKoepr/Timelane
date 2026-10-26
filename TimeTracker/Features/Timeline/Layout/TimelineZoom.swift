import CoreGraphics

/// The discrete zoom levels of the timeline.
enum TimelineZoom: Int, CaseIterable, Comparable, Sendable {
    case hour = 0      // 80 pt per hour (overview)
    case halfHour      // 160 pt per hour
    case quarterHour   // 320 pt per hour
    case tenMinutes    // 480 pt per hour (10 min = 80 pt)

    var pointsPerHour: CGFloat {
        switch self {
        case .hour: 80
        case .halfHour: 160
        case .quarterHour: 320
        case .tenMinutes: 480
        }
    }

    /// Interval between labelled grid lines.
    var labelIntervalMinutes: Int {
        switch self {
        case .hour: 60
        case .halfHour: 30
        case .quarterHour: 15
        case .tenMinutes: 10
        }
    }

    /// Interval between faint grid lines.
    var minorLineMinutes: Int {
        switch self {
        case .hour, .halfHour: 15
        case .quarterHour, .tenMinutes: 5
        }
    }

    var displayName: String {
        switch self {
        case .hour: "1 h"
        case .halfHour: "30 min"
        case .quarterHour: "15 min"
        case .tenMinutes: "10 min"
        }
    }

    func zoomedIn() -> TimelineZoom { TimelineZoom(rawValue: rawValue + 1) ?? self }
    func zoomedOut() -> TimelineZoom { TimelineZoom(rawValue: rawValue - 1) ?? self }

    static func < (lhs: TimelineZoom, rhs: TimelineZoom) -> Bool { lhs.rawValue < rhs.rawValue }
}
