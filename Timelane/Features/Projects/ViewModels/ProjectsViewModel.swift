import Foundation

@MainActor @Observable
final class ProjectsViewModel {
    private(set) var month: DateRange
    private(set) var allTotals: [ProjectMonthTotal] = []
    var showArchived = false
    var errorMessage: String?

    private let repository: any ProjectRepository
    private let calendar: Calendar
    private let now: () -> Date

    init(repository: any ProjectRepository, calendar: Calendar = .current, now: @escaping () -> Date = { .now }) {
        self.repository = repository
        self.calendar = calendar
        self.now = now
        self.month = .month(of: now(), calendar: calendar)
    }

    /// Rows to show: archived projects only when asked for, or when they have hours this month.
    var rows: [ProjectMonthTotal] {
        allTotals
            .filter { !$0.project.isArchived || showArchived || $0.totalSeconds > 0 }
            .sorted {
                if $0.totalSeconds != $1.totalSeconds { return $0.totalSeconds > $1.totalSeconds }
                return $0.project.name.localizedCaseInsensitiveCompare($1.project.name) == .orderedAscending
            }
    }

    /// False when no project exists at all (as opposed to nothing to show this month).
    var hasAnyProjects: Bool { !allTotals.isEmpty }
    var monthTotal: TimeInterval { rows.reduce(0) { $0 + $1.totalSeconds } }
    var isCurrentMonth: Bool { month == .month(of: now(), calendar: calendar) }
    var monthTitle: String { month.start.formatted(.dateTime.month(.wide).year()) }

    func goToPreviousMonth() { month = month.shiftedMonths(-1, calendar: calendar) }
    func goToNextMonth() { month = month.shiftedMonths(1, calendar: calendar) }
    func goToCurrentMonth() { month = .month(of: now(), calendar: calendar) }

    func archive(_ project: Project) async { await setArchived(project, true) }
    func unarchive(_ project: Project) async { await setArchived(project, false) }

    func delete(_ project: Project) async {
        guard let id = project.id else { return }
        do { try await repository.delete(id: id) } catch { errorMessage = error.localizedDescription }
    }

    /// Observes totals for the current month. Re-run (via `.task(id: month)`) when the month changes.
    func task() async {
        for await totals in repository.observeMonthTotals(in: month) {
            allTotals = totals
        }
    }

    private func setArchived(_ project: Project, _ archived: Bool) async {
        guard let id = project.id else { return }
        do { try await repository.archive(id: id, archived: archived) } catch { errorMessage = error.localizedDescription }
    }
}
