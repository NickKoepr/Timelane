import Foundation

@MainActor @Observable
final class MenuBarViewModel {
    private(set) var entries: [TimeEntry] = []
    private var sessions: [AppSession] = []

    private let timeEntries: any TimeEntryRepository
    private let appSessions: any AppSessionRepository
    private let calendar: Calendar

    init(timeEntries: any TimeEntryRepository, appSessions: any AppSessionRepository,
         calendar: Calendar = .current) {
        self.timeEntries = timeEntries
        self.appSessions = appSessions
        self.calendar = calendar
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
        _ = await (observedEntries, observedSessions)
    }

    private func observeEntries(in range: DateRange) async {
        for await value in timeEntries.observeEntries(in: range) { entries = value }
    }

    private func observeSessions(in range: DateRange) async {
        for await value in appSessions.observeSessions(in: range) { sessions = value }
    }
}
