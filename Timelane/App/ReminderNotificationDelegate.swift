import Foundation
import UserNotifications

/// Receives the reminder notifications. Nonisolated on purpose: the system calls it on its own queue.
/// Only the live app installs it (never in tests or screenshot mode).
final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    /// Must happen before launch finishes, so a click that launched the app is delivered here.
    nonisolated func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Also show the reminder while Timelane is the frontmost app.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    /// A click on a reminder opens the main window on today's timeline, where the hours are logged.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let isReminder = response.notification.request.identifier.hasPrefix(DailyReminderSchedule.identifierPrefix)
        let isClick = response.actionIdentifier == UNNotificationDefaultActionIdentifier
        completionHandler()
        guard isReminder, isClick else { return }
        Task { @MainActor in AppEnvironment.shared.showTodayOnTimeline() }
    }
}
