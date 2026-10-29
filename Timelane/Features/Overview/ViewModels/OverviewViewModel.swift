import Foundation

@MainActor @Observable
final class OverviewViewModel {
    private(set) var year: DateRange
    /// nil = all projects.
    var selectedProjectId: Int64?
    /// Archived ones included, for names, colors and the picker.
    private(set) var projects: [Project] = []
    private(set) var activity: YearActivity
    /// False until the first entries arrive, so the screen doesn't flash its empty state while loading.
    private(set) var isLoaded = false
    var errorMessage: String?

    private let timeEntries: any TimeEntryRepository
    private let projectRepository: any ProjectRepository
    let calendar: Calendar
    let now: () -> Date

    init(timeEntries: any TimeEntryRepository, projects: any ProjectRepository,
         calendar: Calendar = .current, now: @escaping () -> Date = { .now }) {
        self.timeEntries = timeEntries
        self.projectRepository = projects
        self.calendar = calendar
        self.now = now
        let year = DateRange.year(of: now(), calendar: calendar)
        self.year = year
        self.activity = YearActivity(entries: [], year: year, calendar: calendar)
    }

    var yearTitle: String { String(calendar.component(.year, from: year.start)) }
    var isCurrentYear: Bool { year == .year(of: now(), calendar: calendar) }

    func goToPreviousYear() { year = year.shiftedYears(-1, calendar: calendar) }
    func goToNextYear() { year = year.shiftedYears(1, calendar: calendar) }
    func goToCurrentYear() { year = .year(of: now(), calendar: calendar) }

    /// The filter actually applied: a project that no longer exists counts as "all projects".
    var effectiveProjectId: Int64? {
        guard let id = selectedProjectId, projects.contains(where: { $0.id == id }) else { return nil }
        return id
    }

    /// Observes the entries of the year and all projects. Re-run (via `.task(id: year)`) when the year changes.
    func task() async {
        async let entries: Void = observeEntries(in: year)
        async let projects: Void = observeProjects()
        _ = await (entries, projects)
    }

    private func observeEntries(in range: DateRange) async {
        for await entries in timeEntries.observeEntries(in: range) {
            activity = YearActivity(entries: entries, year: range, calendar: calendar)
            isLoaded = true
        }
    }

    private func observeProjects() async {
        for await projects in projectRepository.observeProjects(includeArchived: true) {
            self.projects = projects
        }
    }
}
