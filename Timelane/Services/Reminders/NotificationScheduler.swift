import Foundation

/// The system's notification center, behind a protocol: tests, previews and screenshot mode never touch it.
@MainActor
protocol NotificationScheduler: AnyObject {
    func authorization() async -> NotificationAuthorization
    /// Shows the system prompt the first time; afterwards answers without asking. True when alerts are allowed.
    func requestAuthorization() async throws -> Bool
    /// Removes the pending requests with `identifiers`, then adds `requests`. Synchronous, so a later call always
    /// wins over an earlier one; failures are only logged.
    func replace(_ identifiers: [String], with requests: [ReminderRequest])
}
