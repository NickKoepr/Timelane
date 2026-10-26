import Foundation
import Testing
@testable import TimeTracker

@MainActor
struct ProjectsViewModelTests {
    let cal = TestCalendar.make()
    let now = TestCalendar.date(2026, 10, 26, 12)

    func makeViewModel() async throws -> (ProjectsViewModel, GRDBProjectRepository, GRDBTimeEntryRepository) {
        let db = try AppDatabase.inMemory()
        let projects = GRDBProjectRepository(database: db)
        let entries = GRDBTimeEntryRepository(database: db)
        let viewModel = ProjectsViewModel(repository: projects, calendar: cal, now: { now })
        return (viewModel, projects, entries)
    }

    func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() { try? await Task.sleep(for: .milliseconds(10)) }
    }

    @Test func sortsByTotalAndHidesEmptyArchived() async throws {
        let (viewModel, projects, entries) = try await makeViewModel()
        let small = try await projects.save(Project(name: "Small", colorHex: "#000000"))
        let big = try await projects.save(Project(name: "Big", colorHex: "#000000"))
        let archivedEmpty = try await projects.save(Project(name: "Old", colorHex: "#000000"))
        try await projects.archive(id: archivedEmpty.id!, archived: true)
        try await entries.save([
            TimeEntry(projectId: small.id!, start: TestCalendar.date(2026, 10, 5, 9), end: TestCalendar.date(2026, 10, 5, 10)),
            TimeEntry(projectId: big.id!, start: TestCalendar.date(2026, 10, 6, 9), end: TestCalendar.date(2026, 10, 6, 12)),
        ], deleting: [])

        let task = Task { await viewModel.task() }
        await waitUntil { viewModel.allTotals.count == 3 }
        task.cancel()

        #expect(viewModel.rows.map(\.project.name) == ["Big", "Small"])
        #expect(viewModel.monthTotal == 4 * 3600)
        viewModel.showArchived = true
        #expect(viewModel.rows.map(\.project.name) == ["Big", "Small", "Old"])
    }

    @Test func monthNavigation() async throws {
        let (viewModel, _, _) = try await makeViewModel()
        #expect(viewModel.isCurrentMonth)
        viewModel.goToPreviousMonth()
        #expect(viewModel.month.start == TestCalendar.date(2026, 9, 1))
        #expect(!viewModel.isCurrentMonth)
        viewModel.goToCurrentMonth()
        #expect(viewModel.isCurrentMonth)
    }

    @Test func deleteWithEntriesSetsErrorMessage() async throws {
        let (viewModel, projects, entries) = try await makeViewModel()
        let project = try await projects.save(Project(name: "Used", colorHex: "#000000"))
        try await entries.save([TimeEntry(projectId: project.id!, start: now, end: now.addingTimeInterval(600))], deleting: [])
        await viewModel.delete(project)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func hasAnyProjectsDistinguishesEmptyStates() async throws {
        let (viewModel, projects, _) = try await makeViewModel()
        let task = Task { await viewModel.task() }
        await waitUntil { viewModel.hasAnyProjects }
        #expect(!viewModel.hasAnyProjects)
        _ = try await projects.save(Project(name: "Idle", colorHex: "#000000"))
        await waitUntil { viewModel.hasAnyProjects }
        task.cancel()
        #expect(viewModel.hasAnyProjects)
        #expect(viewModel.rows.count == 1)
    }
}
