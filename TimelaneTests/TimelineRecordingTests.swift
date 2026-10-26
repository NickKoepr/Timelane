import Foundation
import Testing
@testable import Timelane

@MainActor
struct TimelineRecordingTests {
    let cal = TestCalendar.make()
    final class Clock { var now = TestCalendar.date(2026, 11, 3, 14, 30) }

    func make(_ clock: Clock) throws -> (TimelineViewModel, RecordingTimer) {
        let db = try AppDatabase.inMemory()
        let repo = GRDBTimeEntryRepository(database: db)
        let timer = RecordingTimer(calendar: cal, clock: { clock.now })
        let vm = TimelineViewModel(
            timeEntries: repo, appSessions: GRDBAppSessionRepository(database: db),
            projects: GRDBProjectRepository(database: db), trackedApps: GRDBTrackedAppRepository(database: db),
            editor: TimeEntryEditor(repository: repo),
            lastProject: LastProjectStore(defaults: UserDefaults(suiteName: "TLRec-\(UUID())")!),
            zoomState: TimelineZoomState(defaults: UserDefaults(suiteName: "Zoom-\(UUID())")!),
            recordingTimer: timer, calendar: cal, clock: { clock.now })
        return (vm, timer)
    }

    @Test func registerShowsDaySetsSelectionAndOpensForm() throws {
        let (vm, _) = try make(Clock())
        vm.goToPreviousDay()
        let range = DateRange(start: TestCalendar.date(2026, 11, 3, 10), end: TestCalendar.date(2026, 11, 3, 11, 15))
        vm.register(RecordedPeriod(start: range.start, end: range.end, calendar: cal)!)
        #expect(vm.day.start == TestCalendar.date(2026, 11, 3))
        #expect(vm.selection?.range == range)
        #expect(vm.form?.form.range == range)
        #expect(vm.form?.form.isEditing == false)
        #expect(vm.form?.notice == nil)
    }

    @Test func midnightRecordingSetsNotice() throws {
        let (vm, _) = try make(Clock())
        let start = TestCalendar.date(2026, 11, 3, 23, 0)
        vm.register(RecordedPeriod(start: start, end: start.addingTimeInterval(7200), calendar: cal)!)
        #expect(vm.form?.notice == RecordedPeriod.midnightNotice)
        #expect(vm.form?.form.end == TestCalendar.date(2026, 11, 3, 23, 59))
    }

    @Test func toggleStartsThenStopsIntoTheForm() throws {
        let clock = Clock()
        let (vm, timer) = try make(clock)
        vm.toggleRecording()
        #expect(timer.isRunning && vm.form == nil)
        clock.now = clock.now.addingTimeInterval(600)
        vm.toggleRecording()
        #expect(!timer.isRunning)
        #expect(vm.form?.form.start == TestCalendar.date(2026, 11, 3, 14, 30))
        #expect(vm.form?.form.end == TestCalendar.date(2026, 11, 3, 14, 40))
    }

    @Test func tooShortRecordingShowsError() throws {
        let (vm, timer) = try make(Clock())
        vm.toggleRecording()
        vm.toggleRecording()
        #expect(!timer.isRunning)
        #expect(vm.form == nil)
        #expect(vm.entryEditing.errorMessage == TimelineViewModel.recordingTooShortMessage)
    }

    @Test func recordingRangeOnlyOnTheStartDay() throws {
        let (vm, timer) = try make(Clock())
        #expect(vm.recordingRange == nil)
        timer.start() // started at "now", so nothing to draw yet
        #expect(vm.recordingRange == nil)
    }
}
