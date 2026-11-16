import Foundation

/// One weekday of the daily reminder: on or off, with its own time of day.
struct ReminderDay: Codable, Equatable, Sendable {
    /// `Calendar` weekday: 1 = Sunday … 7 = Saturday.
    var weekday: Int
    var isOn: Bool
    var hour: Int
    var minute: Int
}
