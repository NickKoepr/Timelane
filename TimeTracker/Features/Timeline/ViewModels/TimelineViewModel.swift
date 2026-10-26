import Foundation

@MainActor @Observable
final class TimelineViewModel {
    private(set) var day: DateRange
    private(set) var sessionBlocks: [AppSessionBlockModel] = []
    private(set) var entries: [TimeEntry] = []
    private(set) var projects: [Project] = []
    private(set) var now: Date

    private var sessions: [AppSession] = []
    private let timeEntries: any TimeEntryRepository
    private let appSessions: any AppSessionRepository
    private let projectRepository: any ProjectRepository
    private let calendar: Calendar
    private let clock: () -> Date

    init(timeEntries: any TimeEntryRepository, appSessions: any AppSessionRepository,
         projects: any ProjectRepository, calendar: Calendar = .current, clock: @escaping () -> Date = { .now }) {
        self.timeEntries = timeEntries
        self.appSessions = appSessions
        self.projectRepository = projects
        self.calendar = calendar
        self.clock = clock
        self.now = clock()
        self.day = .day(of: clock(), calendar: calendar)
    }

    // MARK: Presentation

    var geometry: TimelineGeometry { TimelineGeometry(day: day) }
    var isToday: Bool { day.contains(clock()) }
    var title: String { day.start.formatted(.dateTime.weekday(.wide).day().month(.wide).year()) }
    var registeredTotal: TimeInterval { DayTotals.registered(entries: entries, in: day) }
    var trackedTotal: TimeInterval { DayTotals.tracked(sessions: sessions, in: day, now: now) }
    var hasActivity: Bool { !sessionBlocks.isEmpty || !entries.isEmpty }

    func project(id: Int64) -> Project? { projects.first { $0.id == id } }

    /// Where the timeline should be scrolled to when a day opens.
    var initialScrollDate: Date {
        isToday ? max(clock().addingTimeInterval(-3600), day.start) : day.start.addingTimeInterval(8 * 3600)
    }

    // MARK: Navigation

    func goToPreviousDay() { day = day.shiftedDays(-1, calendar: calendar) }
    func goToNextDay() { day = day.shiftedDays(1, calendar: calendar) }
    func goToToday() { day = .day(of: clock(), calendar: calendar) }
    func go(to date: Date) { day = .day(of: date, calendar: calendar) }

    // MARK: Observation

    /// Observes the current day. Restart (via `.task(id: day)`) when the day changes.
    func task() async {
        let range = day
        now = clock()
        sessions = []
        entries = []
        rebuildBlocks()
        async let observedEntries: Void = observeEntries(in: range)
        async let observedSessions: Void = observeSessions(in: range)
        async let observedProjects: Void = observeProjects()
        async let ticking: Void = tick()
        _ = await (observedEntries, observedSessions, observedProjects, ticking)
    }

    private func observeEntries(in range: DateRange) async {
        for await value in timeEntries.observeEntries(in: range) { entries = value }
    }

    private func observeSessions(in range: DateRange) async {
        for await value in appSessions.observeSessions(in: range) {
            sessions = value
            now = clock()
            rebuildBlocks()
        }
    }

    private func observeProjects() async {
        for await value in projectRepository.observeProjects(includeArchived: true) { projects = value }
    }

    /// The open session grows while viewing today.
    private func tick() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            now = clock()
            rebuildBlocks()
        }
    }

    private func rebuildBlocks() {
        sessionBlocks = AppSessionMerger.blocks(from: sessions, in: day, now: now)
    }
}
