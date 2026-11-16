import Foundation
import Testing
@testable import Timelane

@MainActor
struct DailyReminderServiceTests {
    struct TestError: Error {}

    struct Fixture {
        let service: DailyReminderService
        let scheduler: InMemoryNotificationScheduler
        let store: InMemoryDailyReminderSettingsStore
    }

    func make(status: NotificationAuthorization = .notDetermined, grantsPermission: Bool = true,
              settings: DailyReminderSettings = DailyReminderSettings()) -> Fixture {
        let scheduler = InMemoryNotificationScheduler(status: status, grantsPermission: grantsPermission)
        let store = InMemoryDailyReminderSettingsStore(settings: settings)
        return Fixture(service: DailyReminderService(store: store, scheduler: scheduler), scheduler: scheduler, store: store)
    }

    @Test func offByDefaultAndSchedulesNothing() async {
        let f = make(status: .authorized)
        await f.service.refresh()
        #expect(!f.service.settings.isEnabled)
        #expect(f.scheduler.pendingRequests.isEmpty)
        #expect(f.scheduler.authorizationRequestCount == 0)
    }

    @Test func enablingAsksPermissionAndSchedulesWeekdays() async throws {
        let f = make()
        let allowed = try await f.service.setEnabled(true)
        #expect(allowed)
        #expect(f.scheduler.authorizationRequestCount == 1)
        #expect(f.service.authorization == .authorized)
        #expect(f.service.settings.isEnabled)
        #expect(f.store.settings.isEnabled)
        #expect(f.scheduler.pendingRequests.map(\.weekday) == [2, 3, 4, 5, 6])
    }

    @Test func refusedPermissionStaysOff() async throws {
        let f = make(grantsPermission: false)
        let allowed = try await f.service.setEnabled(true)
        #expect(!allowed)
        #expect(f.service.authorization == .denied)
        #expect(!f.service.settings.isEnabled)
        #expect(!f.store.settings.isEnabled)
        #expect(f.scheduler.pendingRequests.isEmpty)
    }

    @Test func earlierDeniedPermissionStaysOff() async throws {
        let f = make(status: .denied)
        let allowed = try await f.service.setEnabled(true)
        #expect(!allowed)
        #expect(!f.service.settings.isEnabled)
    }

    @Test func requestErrorPropagatesAndStaysOff() async {
        let f = make()
        f.scheduler.error = TestError()
        await #expect(throws: TestError.self) { try await f.service.setEnabled(true) }
        #expect(!f.service.settings.isEnabled)
    }

    @Test func disablingRemovesEveryRequestWithoutAsking() async throws {
        let f = make()
        try await f.service.setEnabled(true)
        try await f.service.setEnabled(false)
        #expect(!f.service.settings.isEnabled)
        #expect(!f.store.settings.isEnabled)
        #expect(f.scheduler.pendingRequests.isEmpty)
        #expect(f.scheduler.authorizationRequestCount == 1)
    }

    @Test func turningADayOffRemovesOnlyThatRequest() async throws {
        let f = make()
        try await f.service.setEnabled(true)
        f.service.setDay(4, isOn: false)
        f.service.setDay(7, isOn: true)
        #expect(f.scheduler.pendingRequests.map(\.weekday) == [2, 3, 5, 6, 7])
        #expect(!f.store.settings.day(4).isOn)
    }

    @Test func changingATimeReplacesThatRequest() async throws {
        let f = make()
        try await f.service.setEnabled(true)
        f.service.setTime(hour: 16, minute: 15, for: 6)
        let friday = f.scheduler.pendingRequests.first { $0.weekday == 6 }
        #expect(friday == ReminderRequest(identifier: DailyReminderSchedule.identifier(for: 6), weekday: 6, hour: 16, minute: 15))
        #expect(f.scheduler.pendingRequests.count == 5)
        #expect(f.store.settings.day(6).hour == 16)
    }

    @Test func storedSettingsAreScheduledOnRefresh() async {
        var settings = DailyReminderSettings()
        settings.isEnabled = true
        let f = make(status: .authorized, settings: settings)
        #expect(f.scheduler.pendingRequests.isEmpty)
        await f.service.refresh()
        #expect(f.scheduler.pendingRequests.count == 5)
    }

    @Test func nothingIsScheduledWhileNotAllowedAndRefreshRestoresIt() async throws {
        let f = make()
        try await f.service.setEnabled(true)
        // The user blocks notifications in System Settings.
        f.scheduler.status = .denied
        await f.service.refresh()
        #expect(f.service.authorization == .denied)
        #expect(f.service.settings.isEnabled)
        #expect(f.scheduler.pendingRequests.isEmpty)
        f.service.setDay(7, isOn: true)
        #expect(f.scheduler.pendingRequests.isEmpty)
        // ... and allows them again.
        f.scheduler.status = .authorized
        await f.service.refresh()
        #expect(f.scheduler.pendingRequests.map(\.weekday) == [2, 3, 4, 5, 6, 7])
    }
}
