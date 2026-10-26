import Foundation

@MainActor @Observable
final class MenuBarViewModel {
    private(set) var entries: [TimeEntry] = []
    private(set) var trackedApps: [TrackedApp] = []
    private var allSessions: [AppSession] = []

    private let timeEntries: any TimeEntryRepository
    private let appSessions: any AppSessionRepository
    private let trackedAppRepository: any TrackedAppRepository
    private let calendar: Calendar

    init(timeEntries: any TimeEntryRepository, appSessions: any AppSessionRepository,
         trackedApps: any TrackedAppRepository, calendar: Calendar = .current) {
        self.timeEntries = timeEntries
        self.appSessions = appSessions
        self.trackedAppRepository = trackedApps
        self.calendar = calendar
    }

    /// Stored sessions of apps that are no longer tracked stay hidden.
    var sessions: [AppSession] {
        let ids = Set(trackedApps.map(\.bundleIdentifier))
        return allSessions.filter { ids.contains($0.bundleIdentifier) }
    }

    func registeredTotal(now: Date) -> TimeInterval {
        DayTotals.registered(entries: entries, in: .day(of: now, calendar: calendar))
    }

    func trackedTotal(now: Date) -> TimeInterval {
        DayTotals.tracked(sessions: sessions, in: .day(of: now, calendar: calendar), now: now)
    }

    /// Observes today's data. Re-run when the popover appears so "today" stays current.
    func task() async {
        let today = DateRange.day(of: .now, calendar: calendar)
        async let observedEntries: Void = observeEntries(in: today)
        async let observedSessions: Void = observeSessions(in: today)
        async let observedApps: Void = observeTrackedApps()
        _ = await (observedEntries, observedSessions, observedApps)
    }

    private func observeEntries(in range: DateRange) async {
        for await value in timeEntries.observeEntries(in: range) { entries = value }
    }

    private func observeSessions(in range: DateRange) async {
        for await value in appSessions.observeSessions(in: range) { allSessions = value }
    }

    private func observeTrackedApps() async {
        for await value in trackedAppRepository.observeTrackedApps() { trackedApps = value }
    }
}
