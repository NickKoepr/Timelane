import Foundation

/// Whether Timelane may show notifications (System Settings ▸ Notifications).
enum NotificationAuthorization: Sendable, Equatable {
    /// The user hasn't been asked yet; turning a reminder on shows the system prompt.
    case notDetermined
    case denied
    case authorized
}
