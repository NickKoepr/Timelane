import Foundation
import Testing
@testable import TimeTracker

@MainActor
struct MenuBarViewModelTests {
    let cal = TestCalendar.make()
    let now = TestCalendar.date(2026, 11, 3, 14, 30)

    func makeViewModel(defaults: UserDefaults = UserDefaults(suiteName: "MenuBar-\(UUID())")!) throws -> MenuBarViewModel {
        let db = try AppDatabase.inMemory()
        let timeline = TimelineViewModel(
            timeEntries: GRDBTimeEntryRepository(database: db), appSessions: GRDBAppSessionRepository(database: db),
            projects: GRDBProjectRepository(database: db), trackedApps: GRDBTrackedAppRepository(database: db),
            editor: TimeEntryEditor(repository: GRDBTimeEntryRepository(database: db)),
            lastProject: LastProjectStore(defaults: defaults),
            zoomState: TimelineZoomState(defaults: defaults, key: MenuBarViewModel.zoomKey, defaultLevel: .halfHour),
            allowsCreatingProjects: false, calendar: cal, clock: { now })
        return MenuBarViewModel(timeline: timeline)
    }

    @Test func openingResetsToTodayAndAsksToScroll() throws {
        let vm = try makeViewModel()
        vm.timeline.goToPreviousDay()
        #expect(!vm.timeline.isToday)
        vm.panelDidOpen()
        #expect(vm.timeline.isToday)
        #expect(vm.scrollTrigger == 1)
        vm.panelDidOpen()
        #expect(vm.scrollTrigger == 2)
    }

    @Test func openingKeepsAnUnfinishedForm() throws {
        let vm = try makeViewModel()
        vm.timeline.assign(AppSessionBlockModel(bundleIdentifier: "x", appName: "X",
                                                start: TestCalendar.date(2026, 11, 3, 9), end: TestCalendar.date(2026, 11, 3, 10)))
        vm.panelDidOpen()
        #expect(vm.timeline.form != nil)
        #expect(vm.scrollTrigger == 0)
    }

    @Test func usesItsOwnZoomState() throws {
        let defaults = UserDefaults(suiteName: "MenuBar-\(UUID())")!
        let vm = MenuBarViewModel.make(environment: .inMemory(), defaults: defaults)
        #expect(vm.timeline.zoomState.zoom == .halfHour)
        vm.timeline.zoomState.set(.tenMinutes)
        #expect(defaults.integer(forKey: MenuBarViewModel.zoomKey) == TimelineZoom.tenMinutes.rawValue)
        #expect(defaults.object(forKey: TimelineZoomState.defaultKey) == nil)
    }
}
