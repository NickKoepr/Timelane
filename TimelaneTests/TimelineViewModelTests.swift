import Foundation
import Testing
@testable import Timelane

@MainActor
struct TimelineViewModelTests {
    let cal = TestCalendar.make()
    let now = TestCalendar.date(2026, 11, 3, 14, 30)

    func makeViewModel() throws -> (TimelineViewModel, AppDatabase) {
        let db = try AppDatabase.inMemory()
        let vm = TimelineViewModel(timeEntries: GRDBTimeEntryRepository(database: db),
                                   appSessions: GRDBAppSessionRepository(database: db),
                                   projects: GRDBProjectRepository(database: db),
                                   trackedApps: GRDBTrackedAppRepository(database: db),
                                   editor: TimeEntryEditor(repository: GRDBTimeEntryRepository(database: db)),
                                   lastProject: LastProjectStore(defaults: UserDefaults(suiteName: "TimelineVMTests-\(UUID())")!),
                                   zoomState: TimelineZoomState(defaults: UserDefaults(suiteName: "Zoom-\(UUID())")!),
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
        try await GRDBTrackedAppRepository(database: db).add([TrackedApp(bundleIdentifier: "x", name: "X")])
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
struct TimelineTrackedAppsTests {
    @Test func sessionsStayVisibleWhenAppIsNotOrNoLongerTracked() async throws {
        let db = try AppDatabase.inMemory()
        let now = TestCalendar.date(2026, 11, 3, 14, 30)
        let repo = GRDBTimeEntryRepository(database: db)
        let tracked = GRDBTrackedAppRepository(database: db)
        let vm = TimelineViewModel(timeEntries: repo, appSessions: GRDBAppSessionRepository(database: db),
                                   projects: GRDBProjectRepository(database: db), trackedApps: tracked,
                                   editor: TimeEntryEditor(repository: repo),
                                   lastProject: LastProjectStore(defaults: UserDefaults(suiteName: "TLTA-\(UUID())")!),
                                   zoomState: TimelineZoomState(defaults: UserDefaults(suiteName: "Zoom-\(UUID())")!),
                                   calendar: TestCalendar.make(), clock: { now })
        let sessions = GRDBAppSessionRepository(database: db)
        for (id, hour) in [("x", 9), ("y", 11)] {
            _ = try await sessions.start(AppSession(bundleIdentifier: id, appName: id, start: TestCalendar.date(2026, 11, 3, hour),
                                                    end: TestCalendar.date(2026, 11, 3, hour + 1)))
        }
        let task = Task { await vm.task() }
        defer { task.cancel() }
        for _ in 0..<300 where !vm.hasNoTrackedApps || vm.sessionBlocks.count < 2 { try? await Task.sleep(for: .milliseconds(10)) }
        // Neither app is on the list, both sessions are shown.
        #expect(vm.hasNoTrackedApps)
        #expect(vm.sessionBlocks.map(\.bundleIdentifier) == ["x", "y"])
        #expect(vm.trackedTotal == 7200)

        try await tracked.add([TrackedApp(bundleIdentifier: "x", name: "X")])
        for _ in 0..<300 where vm.hasNoTrackedApps { try? await Task.sleep(for: .milliseconds(10)) }
        #expect(vm.sessionBlocks.count == 2)

        let id = try #require(try await tracked.trackedApps().first?.id)
        try await tracked.remove(id: id)
        for _ in 0..<300 where !vm.hasNoTrackedApps { try? await Task.sleep(for: .milliseconds(10)) }
        #expect(vm.hasNoTrackedApps)
        #expect(vm.sessionBlocks.map(\.bundleIdentifier) == ["x", "y"])
        #expect(vm.trackedTotal == 7200)
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
                                   projects: projects, trackedApps: GRDBTrackedAppRepository(database: db), editor: TimeEntryEditor(repository: entries),
                                   lastProject: LastProjectStore(defaults: UserDefaults(suiteName: "TimelineRegTests-\(UUID())")!),
                                   zoomState: TimelineZoomState(defaults: UserDefaults(suiteName: "Zoom-\(UUID())")!),
                                   calendar: cal, clock: { now })
        let task = Task { await vm.task() }
        for _ in 0..<200 where vm.projects.isEmpty { try? await Task.sleep(for: .milliseconds(10)) }
        task.cancel()
        return (vm, entries, project)
    }

    func waitForEntries(_ vm: TimelineViewModel, count: Int) async {
        for _ in 0..<300 where vm.entries.count != count { try? await Task.sleep(for: .milliseconds(10)) }
    }

    @Test func dragSelectsSnappedRangeAndOpensForm() async throws {
        let (vm, entries, project) = try await makeViewModel()
        let g = vm.geometry
        vm.updateSelection(startY: g.y(for: TestCalendar.date(2026, 11, 3, 13, 2)),
                           currentY: g.y(for: TestCalendar.date(2026, 11, 3, 10, 1)))
        #expect(vm.selection?.start == TestCalendar.date(2026, 11, 3, 10))
        #expect(vm.selection?.end == TestCalendar.date(2026, 11, 3, 13))
        vm.finishSelection()
        let form = try #require(vm.form)
        #expect(form.form.projectId == project.id)
        #expect(form.heading == "New time entry")

        form.form.title = "Deep work"
        await form.save()
        #expect(vm.form == nil && vm.selection == nil)
        let saved = try await entries.entries(in: vm.day)
        #expect(saved.count == 1)
        #expect(saved[0].duration == 3 * 3600)
        #expect(saved[0].title == "Deep work")
    }

    @Test func selectionBeforeNowIsAccepted() async throws {
        let (vm, _, _) = try await makeViewModel()
        let g = vm.geometry
        // "now" is 14:30; select 08:00-09:00, well before it.
        vm.updateSelection(startY: g.y(for: TestCalendar.date(2026, 11, 3, 8)), currentY: g.y(for: TestCalendar.date(2026, 11, 3, 9)))
        vm.finishSelection()
        #expect(vm.form?.form.range == DateRange(start: TestCalendar.date(2026, 11, 3, 8), end: TestCalendar.date(2026, 11, 3, 9)))
    }

    @Test func savedEntryAppearsOnTheTimeline() async throws {
        let (vm, _, _) = try await makeViewModel()
        let observing = Task { await vm.task() }
        defer { observing.cancel() }
        let g = vm.geometry
        vm.updateSelection(startY: g.y(for: TestCalendar.date(2026, 11, 3, 9)), currentY: g.y(for: TestCalendar.date(2026, 11, 3, 10)))
        vm.finishSelection()
        let form = try #require(vm.form)
        form.form.title = "Standup"
        await form.save()
        await waitForEntries(vm, count: 1)
        #expect(vm.entries.count == 1)
        #expect(vm.entries.first?.title == "Standup")
    }

    @Test func tinySelectionIsDiscarded() async throws {
        let (vm, _, _) = try await makeViewModel()
        let g = vm.geometry
        vm.updateSelection(startY: g.y(for: TestCalendar.date(2026, 11, 3, 10)), currentY: g.y(for: TestCalendar.date(2026, 11, 3, 10, 1)))
        vm.finishSelection()
        #expect(vm.form == nil && vm.selection == nil)
    }

    @Test func assigningSessionUsesItsRange() async throws {
        let (vm, entries, _) = try await makeViewModel()
        let block = AppSessionBlockModel(bundleIdentifier: "x", appName: "X",
                                         start: TestCalendar.date(2026, 11, 3, 9), end: TestCalendar.date(2026, 11, 3, 9, 45))
        vm.assign(block)
        let form = try #require(vm.form)
        await form.save()
        let saved = try await entries.entries(in: vm.day)
        #expect(saved.first?.start == block.start && saved.first?.end == block.end)
    }

    @Test func selectingAnEntryOpensEditFormAndSaveUpdatesIt() async throws {
        let (vm, entries, project) = try await makeViewModel()
        try await entries.save([TimeEntry(projectId: project.id!, start: TestCalendar.date(2026, 11, 3, 9),
                                          end: TestCalendar.date(2026, 11, 3, 10))], deleting: [])
        let entry = try #require(try await entries.entries(in: vm.day).first)
        vm.select(entry)
        let form = try #require(vm.form)
        #expect(form.heading == "Edit time entry")
        form.form.title = "Renamed"
        form.form.end = TestCalendar.date(2026, 11, 3, 10, 30)
        await form.save()
        let saved = try await entries.entries(in: vm.day)
        #expect(saved.count == 1 && saved[0].id == entry.id)
        #expect(saved[0].title == "Renamed" && saved[0].end == TestCalendar.date(2026, 11, 3, 10, 30))
        #expect(vm.form == nil)

        vm.select(saved[0])
        await vm.form?.delete()
        #expect(try await entries.entries(in: vm.day).isEmpty)
    }

    @Test func contextMenuDeleteRemovesTheEntryAndClearsSelection() async throws {
        let (vm, entries, project) = try await makeViewModel()
        try await entries.save([TimeEntry(projectId: project.id!, start: TestCalendar.date(2026, 11, 3, 9),
                                          end: TestCalendar.date(2026, 11, 3, 10))], deleting: [])
        let entry = try #require(try await entries.entries(in: vm.day).first)
        vm.entryEditing.select(entry)
        vm.delete(entry)
        for _ in 0..<100 {
            if try await entries.entries(in: vm.day).isEmpty { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(try await entries.entries(in: vm.day).isEmpty)
        #expect(vm.entryEditing.selectedEntryId == nil)
    }

    @Test func inlineProjectCreationSelectsTheNewProject() async throws {
        let (vm, entries, _) = try await makeViewModel()
        vm.assign(AppSessionBlockModel(bundleIdentifier: "x", appName: "X",
                                       start: TestCalendar.date(2026, 11, 3, 9), end: TestCalendar.date(2026, 11, 3, 10)))
        let form = try #require(vm.form)
        form.search.query = "Brand New"
        #expect(form.search.newProjectName == "Brand New")
        await form.confirmSearch()
        #expect(form.search.projects.map(\.name).contains("Brand New"))
        await form.save()
        let saved = try await entries.entries(in: vm.day)
        #expect(saved.count == 1)
        #expect(saved[0].projectId == form.form.projectId)
    }

    @Test func formCannotSaveWithoutProjectOrWithBadTimes() async throws {
        let (vm, entries, _) = try await makeViewModel()
        vm.assign(AppSessionBlockModel(bundleIdentifier: "x", appName: "X",
                                       start: TestCalendar.date(2026, 11, 3, 9), end: TestCalendar.date(2026, 11, 3, 10)))
        let form = try #require(vm.form)
        form.form.end = form.form.start
        #expect(!form.canSave)
        await form.save()
        #expect(try await entries.entries(in: vm.day).isEmpty)
        form.form.end = form.form.start.addingTimeInterval(3600)
        form.form.projectId = nil
        #expect(!form.canSave)
    }

    @Test func runningAutomaticEntryEndsAtTheSameNowAsTheOpenSession() async throws {
        let db = try AppDatabase.inMemory()
        let entriesRepo = GRDBTimeEntryRepository(database: db)
        let project = try await GRDBProjectRepository(database: db).save(Project(name: "A", colorHex: "#000000"))
        let start = TestCalendar.date(2026, 11, 3, 14)
        let saved = try await entriesRepo.save([TimeEntry(projectId: project.id!, start: start, end: start.addingTimeInterval(60))], deleting: [])
        try await GRDBTrackedAppRepository(database: db).add([TrackedApp(bundleIdentifier: "x", name: "X")])
        _ = try await GRDBAppSessionRepository(database: db).start(AppSession(bundleIdentifier: "x", appName: "X", start: start))
        let live = LiveAutoEntry()
        let at = start.addingTimeInterval(23 * 60 + 40)
        let vm = TimelineViewModel(timeEntries: entriesRepo, appSessions: GRDBAppSessionRepository(database: db),
                                   projects: GRDBProjectRepository(database: db), trackedApps: GRDBTrackedAppRepository(database: db),
                                   editor: TimeEntryEditor(repository: entriesRepo),
                                   lastProject: LastProjectStore(defaults: UserDefaults(suiteName: "LiveVM-\(UUID())")!),
                                   zoomState: TimelineZoomState(defaults: UserDefaults(suiteName: "LiveZoom-\(UUID())")!),
                                   liveAutoEntry: live, calendar: cal, clock: { at })
        let id = try #require(saved.first?.id)
        live.set(id)
        let task = Task { await vm.task() }
        for _ in 0..<300 where vm.entries.isEmpty || vm.sessionBlocks.isEmpty { try? await Task.sleep(for: .milliseconds(10)) }
        task.cancel()

        let block = try #require(vm.sessionBlocks.first), shown = try #require(vm.entries.first)
        #expect(block.duration == 23 * 60 + 40 && shown.end.timeIntervalSince(shown.start) == block.duration)
        #expect(DurationFormatter.short(block.duration) == DurationFormatter.short(shown.end.timeIntervalSince(shown.start)))
        #expect(vm.stored(shown).end == start.addingTimeInterval(60))

        vm.goToPreviousDay()
        #expect(vm.entries == vm.storedEntries)
    }
}
