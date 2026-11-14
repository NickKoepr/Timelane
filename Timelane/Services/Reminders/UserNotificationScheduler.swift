import Foundation
import os
import UserNotifications

/// `NotificationScheduler` on `UNUserNotificationCenter`. Only the live app creates one; tests and previews use
/// `InMemoryNotificationScheduler`.
///
/// The completion handlers are explicitly `@Sendable` and only hand Sendable values (status, Bool, error) on:
/// the system calls them on its own queue, and a closure inferred as main-actor isolated would trap there.
@MainActor
final class UserNotificationScheduler: NotificationScheduler {
    private nonisolated static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Timelane",
                                                   category: "reminders")

    func authorization() async -> NotificationAuthorization {
        let center = UNUserNotificationCenter.current()
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<UNAuthorizationStatus, Never>) in
            center.getNotificationSettings { @Sendable settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
        return Self.authorization(for: status)
    }

    func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, any Error>) in
            center.requestAuthorization(options: [.alert, .sound]) { @Sendable granted, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: granted) }
            }
        }
    }

    func replace(_ identifiers: [String], with requests: [ReminderRequest]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        for request in requests {
            let identifier = request.identifier
            center.add(Self.notificationRequest(for: request), withCompletionHandler: { @Sendable error in
                guard let error else { return }
                UserNotificationScheduler.logger.error(
                    "Could not schedule \(identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
            })
        }
    }

    private static func notificationRequest(for request: ReminderRequest) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = DailyReminderSchedule.title
        content.body = DailyReminderSchedule.body
        content.sound = .default
        content.threadIdentifier = DailyReminderSchedule.identifierPrefix
        let time = DateComponents(hour: request.hour, minute: request.minute, weekday: request.weekday)
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        return UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger)
    }

    /// Provisional permission also delivers notifications (quietly, in Notification Center).
    private static func authorization(for status: UNAuthorizationStatus) -> NotificationAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized, .provisional: .authorized
        @unknown default: .denied
        }
    }
}
