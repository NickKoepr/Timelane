import Foundation
import Testing
@testable import Timelane

@MainActor
struct OverviewViewModelTests {
    let cal = TestCalendar.make()
    let now = TestCalendar.date(2026, 10, 26, 12)

    func makeViewModel() throws -> (OverviewViewModel, GRDBProjectRepository, GRDBTimeEntryRepository) {
        let db = try AppDatabase.inMemory()
        let projects = GRDBProjectRepository(database: db)
        let entries = GRDBTimeEntryRepository(database: db)
        let viewModel = OverviewViewModel(timeEntries: entries, projects: projects, calendar: cal, now: { now })
        return (viewModel, projects, entries)
    }

    func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() { try? await Task.sleep(for: .milliseconds(10)) }
    }

    func seed(_ projects: GRDBProjectRepository, _ entries: GRDBTimeEntryRepository) async throws -> (Project, Project) {
        let a = try await projects.save(Project(name: "Alpha", colorHex: "#111111"))
        let b = try await projects.save(Project(name: "Beta", colorHex: "#222222"))
        try await entries.save([
            TimeEntry(projectId: a.id!, start: TestCalendar.date(2026, 3, 2, 9), end: TestCalendar.date(2026, 3, 2, 12)),
            TimeEntry(projectId: b.id!, start: TestCalendar.date(2026, 3, 3, 9), end: TestCalendar.date(2026, 3, 3, 10)),
        ], deleting: [])
        return (a, b)
    }

    @Test func notLoadedBeforeFirstEmission() throws {
        let (viewModel, _, _) = try makeViewModel()
        #expect(!viewModel.isLoaded)
        #expect(viewModel.yearTitle == "2026")
        #expect(viewModel.isCurrentYear)
    }

    @Test func loadsEntriesOfTheYear() async throws {
        let (viewModel, projects, entries) = try makeViewModel()
        _ = try await seed(projects, entries)
        let task = Task { await viewModel.task() }
        await waitUntil { viewModel.isLoaded && viewModel.projects.count == 2 }
        task.cancel()

        #expect(viewModel.totalSeconds == 4 * 3600)
        #expect(viewModel.heading == "4 h registered in 2026")
        #expect(viewModel.projectRows.map(\.project.name) == ["Alpha", "Beta"])
        #expect(viewModel.projectRows.first?.share == 0.75)
        #expect(viewModel.monthlyBars.count == 2)
        #expect(viewModel.monthlyBars.allSatisfy { $0.monthStart == TestCalendar.date(2026, 3, 1) })
        #expect(viewModel.statistics.activeDays == 2)
    }

    @Test func filterChangesTotals() async throws {
        let (viewModel, projects, entries) = try makeViewModel()
        let (_, b) = try await seed(projects, entries)
        let task = Task { await viewModel.task() }
        await waitUntil { viewModel.isLoaded && viewModel.projects.count == 2 }
        task.cancel()

        viewModel.selectedProjectId = b.id
        #expect(viewModel.totalSeconds == 3600)
        #expect(viewModel.heading == "1 h registered in 2026 on Beta")
        #expect(viewModel.projectRows.map(\.project.name) == ["Beta"])
        #expect(viewModel.monthlyBars.map(\.projectName) == ["Beta"])
    }

    @Test func unknownProjectBehavesAsAll() async throws {
        let (viewModel, projects, entries) = try makeViewModel()
        _ = try await seed(projects, entries)
        let task = Task { await viewModel.task() }
        await waitUntil { viewModel.isLoaded && viewModel.projects.count == 2 }
        task.cancel()

        viewModel.selectedProjectId = 9_999
        #expect(viewModel.effectiveProjectId == nil)
        #expect(viewModel.totalSeconds == 4 * 3600)
    }

    @Test func yearNavigation() throws {
        let (viewModel, _, _) = try makeViewModel()
        viewModel.goToPreviousYear()
        #expect(viewModel.yearTitle == "2025")
        #expect(!viewModel.isCurrentYear)
        viewModel.goToNextYear()
        viewModel.goToNextYear()
        #expect(viewModel.yearTitle == "2027")
        viewModel.goToCurrentYear()
        #expect(viewModel.isCurrentYear)
    }

    @Test func dayDetailShowsFullBreakdownWithHighlight() async throws {
        let (viewModel, projects, entries) = try makeViewModel()
        let (a, b) = try await seed(projects, entries)
        try await entries.save([
            TimeEntry(projectId: b.id!, start: TestCalendar.date(2026, 3, 2, 13), end: TestCalendar.date(2026, 3, 2, 15)),
        ], deleting: [])
        let task = Task { await viewModel.task() }
        await waitUntil { viewModel.isLoaded && viewModel.projects.count == 2 && viewModel.totalSeconds == 6 * 3600 }
        task.cancel()

        let day = TestCalendar.date(2026, 3, 2)
        var detail = viewModel.dayDetail(for: day)
        #expect(detail.rows.map(\.name) == ["Alpha", "Beta"])
        #expect(detail.rows.map(\.seconds) == [3 * 3600, 2 * 3600])
        #expect(detail.rows.allSatisfy { !$0.isHighlighted })

        viewModel.selectedProjectId = b.id
        detail = viewModel.dayDetail(for: day)
        #expect(detail.totalSeconds == 5 * 3600)
        #expect(detail.rows.map(\.isHighlighted) == [false, true])
        #expect(a.id != nil)
    }
}
