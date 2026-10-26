import Foundation

/// A display-ready (clipped, merged) stretch of time spent in one app.
struct AppSessionBlockModel: Identifiable, Hashable, Sendable {
    let bundleIdentifier: String
    let appName: String
    let start: Date
    let end: Date

    var id: String { "\(bundleIdentifier)-\(start.timeIntervalSince1970)" }
    var duration: TimeInterval { end.timeIntervalSince(start) }
    var range: DateRange { DateRange(start: start, end: end) }
}
