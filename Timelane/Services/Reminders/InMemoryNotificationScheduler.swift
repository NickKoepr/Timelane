import Foundation

/// Fake `NotificationScheduler` for tests, previews and screenshot mode: keeps the requests in memory.
@MainActor
final class InMemoryNotificationScheduler: NotificationScheduler {
    var status: NotificationAuthorization
    /// The user's answer to the system prompt (asked while `status` is `.notDetermined`).
    var grantsPermission: Bool
    var error: (any Error)?
    private(set) var authorizationRequestCount = 0
    private var pending: [String: ReminderRequest] = [:]

    init(status: NotificationAuthorization = .notDetermined, grantsPermission: Bool = true) {
        self.status = status
        self.grantsPermission = grantsPermission
    }

    /// The scheduled requests in weekday order.
    var pendingRequests: [ReminderRequest] {
        pending.values.sorted { $0.weekday < $1.weekday }
    }

    func authorization() async -> NotificationAuthorization { status }

    func requestAuthorization() async throws -> Bool {
        authorizationRequestCount += 1
        if let error { throw error }
        if status == .notDetermined { status = grantsPermission ? .authorized : .denied }
        return status == .authorized
    }

    func replace(_ identifiers: [String], with requests: [ReminderRequest]) {
        for identifier in identifiers { pending[identifier] = nil }
        for request in requests { pending[request.identifier] = request }
    }
}
