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
