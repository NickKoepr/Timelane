import Foundation
import Testing
@testable import Timelane

/// Passing midnight while the app keeps running (v1.38).
@MainActor
struct TimelineDayChangeTests {
    final class Clock { var now = TestCalendar.date(2026, 11, 3, 23, 58) }

    let cal = TestCalendar.make()
    let clock = Clock()

    func makeViewModel() throws -> TimelineViewModel {
        let db = try AppDatabase.inMemory()
        let clock = clock
        return TimelineViewModel(timeEntries: GRDBTimeEntryRepository(database: db),
                                 appSessions: GRDBAppSessionRepository(database: db),
                                 projects: GRDBProjectRepository(database: db),
                                 trackedApps: GRDBTrackedAppRepository(database: db),
                                 editor: TimeEntryEditor(repository: GRDBTimeEntryRepository(database: db)),
                                 lastProject: LastProjectStore(defaults: UserDefaults(suiteName: "DayChange-\(UUID())")!),
                                 zoomState: TimelineZoomState(defaults: UserDefaults(suiteName: "Zoom-\(UUID())")!),
                                 calendar: cal, clock: { clock.now })
    }

    func passMidnight() { clock.now = TestCalendar.date(2026, 11, 4, 0, 1) }

    @Test func followsToTheNewDayWhenTodayWasShown() throws {
        let vm = try makeViewModel()
        passMidnight()
        vm.refreshToday()
        #expect(vm.day.start == TestCalendar.date(2026, 11, 4))
        #expect(vm.today == vm.day)
        #expect(vm.isToday)
    }

    @Test func staysOnAnotherChosenDayButEnablesToday() throws {
        let vm = try makeViewModel()
        vm.goToPreviousDay()
        passMidnight()
        vm.refreshToday()
        #expect(vm.day.start == TestCalendar.date(2026, 11, 2))
        #expect(vm.today.start == TestCalendar.date(2026, 11, 4))
        #expect(!vm.isToday)
    }

    @Test func keepsAnOpenFormOnTheOldDay() throws {
        let vm = try makeViewModel()
        vm.openNewForm(for: DateRange(start: TestCalendar.date(2026, 11, 3, 22), end: TestCalendar.date(2026, 11, 3, 23)))
        passMidnight()
        vm.refreshToday()
        #expect(vm.day.start == TestCalendar.date(2026, 11, 3))
        #expect(vm.form != nil)
        #expect(!vm.isToday)
        vm.cancelRegistration()
        vm.goToToday()
        #expect(vm.day.start == TestCalendar.date(2026, 11, 4) && vm.isToday)
    }

    @Test func goToTodayReadsTheClock() throws {
        let vm = try makeViewModel()
        vm.goToPreviousDay()
        passMidnight()
        vm.goToToday()
        #expect(vm.day.start == TestCalendar.date(2026, 11, 4))
        #expect(vm.isToday)
    }

    @Test func refreshWithinTheSameDayChangesNothing() throws {
        let vm = try makeViewModel()
        vm.goToPreviousDay()
        clock.now = TestCalendar.date(2026, 11, 3, 23, 59)
        vm.refreshToday()
        #expect(vm.day.start == TestCalendar.date(2026, 11, 2))
        #expect(vm.today.start == TestCalendar.date(2026, 11, 3))
    }
}
