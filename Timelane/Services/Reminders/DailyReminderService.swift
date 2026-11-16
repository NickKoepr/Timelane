import Foundation
import Observation

/// The opt-in reminder to log hours (off by default). Keeps the system's pending notifications in step with the
/// settings: every change replaces all of the reminder's requests, and nothing is added while notifications are
/// not allowed.
@MainActor @Observable
final class DailyReminderService {
    private(set) var settings: DailyReminderSettings
    private(set) var authorization: NotificationAuthorization = .notDetermined

    private let store: any DailyReminderSettingsStore
    private let scheduler: any NotificationScheduler

    init(store: any DailyReminderSettingsStore, scheduler: any NotificationScheduler) {
        self.store = store
        self.scheduler = scheduler
        self.settings = store.settings
    }

    /// Turning on asks for permission first (the system prompt shows only once). Without it the reminder stays
    /// off and this returns false. Turning off never asks.
    @discardableResult
    func setEnabled(_ enabled: Bool) async throws -> Bool {
        if enabled {
            let granted = try await scheduler.requestAuthorization()
            authorization = granted ? .authorized : .denied
            guard granted else { return false }
        }
        update { $0.isEnabled = enabled }
        return true
    }

    func setDay(_ weekday: Int, isOn: Bool) {
        update { $0.setDay(weekday, isOn: isOn) }
    }

    func setTime(hour: Int, minute: Int, for weekday: Int) {
        update { $0.setTime(hour: hour, minute: minute, for: weekday) }
    }

    /// Re-reads the permission and re-adds the requests. Runs at launch, when the app becomes active and when the
    /// Settings tab opens: the user may have allowed or blocked notifications in System Settings meanwhile.
    func refresh() async {
        authorization = await scheduler.authorization()
        reschedule()
    }

    private func update(_ change: (inout DailyReminderSettings) -> Void) {
        change(&settings)
        store.settings = settings
        reschedule()
    }

    private func reschedule() {
        let requests = authorization == .authorized ? DailyReminderSchedule.requests(for: settings) : []
        scheduler.replace(DailyReminderSchedule.allIdentifiers, with: requests)
    }
}
