import Foundation
import Testing
@testable import TimeTracker

@MainActor
struct TimelineViewModelTests {
    let cal = TestCalendar.make()
    let now = TestCalendar.date(2026, 11, 3, 14, 30)

    func makeViewModel() throws -> (TimelineViewModel, AppDatabase) {
        let db = try AppDatabase.inMemory()
        let vm = TimelineViewModel(timeEntries: GRDBTimeEntryRepository(database: db),
                                   appSessions: GRDBAppSessionRepository(database: db),
                                   projects: GRDBProjectRepository(database: db),
                                   editor: TimeEntryEditor(repository: GRDBTimeEntryRepository(database: db)),
                                   lastProject: LastProjectStore(defaults: UserDefaults(suiteName: "TimelineVMTests-\(UUID())")!),
                                   calendar: cal, clock: { now })
        return (vm, db)
    }

    @Test func navigation() throws {
        let (vm, _) = try makeViewModel()
        #expect(vm.isToday)
        vm.goToPreviousDay()
        #expect(vm.day.start == TestCalendar.date(2026, 11, 2))
        #expect(!vm.isToday)
        vm.goToNextDay(); vm.goToNextDay()
        #expect(vm.day.start == TestCalendar.date(2026, 11, 4))
        vm.goToToday()
        #expect(vm.isToday)
        vm.go(to: TestCalendar.date(2026, 5, 17, 13))
        #expect(vm.day.start == TestCalendar.date(2026, 5, 17))
    }

    @Test func initialScrollDate() throws {
        let (vm, _) = try makeViewModel()
        #expect(vm.initialScrollDate == TestCalendar.date(2026, 11, 3, 13, 30))
        vm.goToPreviousDay()
        #expect(vm.initialScrollDate == TestCalendar.date(2026, 11, 2, 8))
    }

    @Test func loadsTotalsForTheDay() async throws {
        let (vm, db) = try makeViewModel()
        let project = try await GRDBProjectRepository(database: db).save(Project(name: "A", colorHex: "#000000"))
        try await GRDBTimeEntryRepository(database: db).save([
            TimeEntry(projectId: project.id!, start: TestCalendar.date(2026, 11, 3, 9), end: TestCalendar.date(2026, 11, 3, 11)),
        ], deleting: [])
        _ = try await GRDBAppSessionRepository(database: db).start(
            AppSession(bundleIdentifier: "x", appName: "X", start: TestCalendar.date(2026, 11, 3, 14)))

        let task = Task { await vm.task() }
        for _ in 0..<200 where vm.entries.isEmpty || vm.sessionBlocks.isEmpty || vm.projects.isEmpty {
            try? await Task.sleep(for: .milliseconds(10))
        }
        task.cancel()

        #expect(vm.registeredTotal == 7200)
        #expect(vm.trackedTotal == 30 * 60)
        #expect(vm.project(id: project.id!)?.name == "A")
        #expect(vm.hasActivity)
    }
}

@MainActor
struct TimelineRegistrationTests {
    let cal = TestCalendar.make()
    let now = TestCalendar.date(2026, 11, 3, 14, 30)

    func makeViewModel() async throws -> (TimelineViewModel, GRDBTimeEntryRepository, Project) {
        let db = try AppDatabase.inMemory()
        let entries = GRDBTimeEntryRepository(database: db)
        let projects = GRDBProjectRepository(database: db)
        let project = try await projects.save(Project(name: "A", colorHex: "#000000"))
        let vm = TimelineViewModel(timeEntries: entries, appSessions: GRDBAppSessionRepository(database: db),
                                   projects: projects, editor: TimeEntryEditor(repository: entries),
                                   lastProject: LastProjectStore(defaults: UserDefaults(suiteName: "TimelineRegTests-\(UUID())")!),
                                   calendar: cal, clock: { now })
        let task = Task { await vm.task() }
        for _ in 0..<200 where vm.projects.isEmpty { try? await Task.sleep(for: .milliseconds(10)) }
        task.cancel()
        return (vm, entries, project)
    }

    @Test func dragSelectsSnappedRangeAndOpensPicker() async throws {
        let (vm, entries, project) = try await makeViewModel()
        let g = vm.geometry
        vm.updateSelection(startY: g.y(for: TestCalendar.date(2026, 11, 3, 13, 2)),
                           currentY: g.y(for: TestCalendar.date(2026, 11, 3, 10, 1)))
        #expect(vm.selection?.start == TestCalendar.date(2026, 11, 3, 10))
        #expect(vm.selection?.end == TestCalendar.date(2026, 11, 3, 13))
        vm.finishSelection()
        let picker = try #require(vm.picker)
        #expect(picker.highlightedId == project.id)

        await picker.confirm()
        #expect(vm.picker == nil && vm.selection == nil)
        let saved = try await entries.entries(in: vm.day)
        #expect(saved.count == 1)
        #expect(saved[0].duration == 3 * 3600)
    }

    @Test func tinySelectionIsDiscarded() async throws {
        let (vm, _, _) = try await makeViewModel()
        let g = vm.geometry
        vm.updateSelection(startY: g.y(for: TestCalendar.date(2026, 11, 3, 10)), currentY: g.y(for: TestCalendar.date(2026, 11, 3, 10, 1)))
        vm.finishSelection()
        #expect(vm.picker == nil && vm.selection == nil)
    }

    @Test func assigningSessionUsesItsRange() async throws {
        let (vm, entries, project) = try await makeViewModel()
        let block = AppSessionBlockModel(bundleIdentifier: "x", appName: "X",
                                         start: TestCalendar.date(2026, 11, 3, 9), end: TestCalendar.date(2026, 11, 3, 9, 45))
        vm.assign(block)
        let picker = try #require(vm.picker)
        await picker.select(project)
        let saved = try await entries.entries(in: vm.day)
        #expect(saved.first?.start == block.start && saved.first?.end == block.end)
    }

    @Test func pickerCreatesProjectInline() async throws {
        let (vm, entries, _) = try await makeViewModel()
        vm.assign(AppSessionBlockModel(bundleIdentifier: "x", appName: "X",
                                       start: TestCalendar.date(2026, 11, 3, 9), end: TestCalendar.date(2026, 11, 3, 10)))
        let picker = try #require(vm.picker)
        picker.searchText = "Brand New"
        #expect(picker.newProjectName == "Brand New")
        #expect(picker.filtered.isEmpty)
        await picker.confirm()
        #expect(try await entries.entries(in: vm.day).count == 1)
    }

    @Test func pickerFiltersAndMovesHighlight() async throws {
        let (vm, _, _) = try await makeViewModel()
        vm.assign(AppSessionBlockModel(bundleIdentifier: "x", appName: "X",
                                       start: TestCalendar.date(2026, 11, 3, 9), end: TestCalendar.date(2026, 11, 3, 10)))
        let picker = try #require(vm.picker)
        picker.searchText = "a"
        #expect(picker.filtered.map(\.name) == ["A"])
        picker.moveHighlight(by: 1)
        #expect(picker.highlightedId == picker.filtered[0].id)
    }
}
