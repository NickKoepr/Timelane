import Foundation

/// One repeating notification: every `weekday` at `hour:minute`, with a stable identifier per weekday.
struct ReminderRequest: Equatable, Sendable {
    let identifier: String
    let weekday: Int
    let hour: Int
    let minute: Int
}
