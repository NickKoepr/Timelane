import Foundation
import Testing
@testable import Timelane

struct AutoLogPlannerTests {
    let start = TestCalendar.date(2026, 11, 3, 9)
    func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }
    var run: AutoLogRun { AutoLogRun(projectId: 1, start: start) }

    @Test func lessThanAMinuteCreatesNothing() {
        #expect(AutoLogPlanner.plan(run: run, entry: nil, entryIsIntact: false, now: at(59)) == .nothing)
    }

    @Test func afterAMinuteCreatesEntryFromRunStart() {
        #expect(AutoLogPlanner.plan(run: run, entry: nil, entryIsIntact: false, now: at(60))
                == .create(DateRange(start: start, end: at(60))))
    }

    @Test func laterTickExtendsOwnEntry() {
        let entry = AutoLogEntry(id: 1, projectId: 1, start: start, lastEnd: at(60))
        #expect(AutoLogPlanner.plan(run: run, entry: entry, entryIsIntact: true, now: at(90)) == .setEnd(at(90)))
    }

    @Test func tickWithoutProgressDoesNothing() {
        let entry = AutoLogEntry(id: 1, projectId: 1, start: start, lastEnd: at(90))
        #expect(AutoLogPlanner.plan(run: run, entry: entry, entryIsIntact: true, now: at(90)) == .nothing)
    }

    @Test func entryChangedByUserRestarts() {
        let entry = AutoLogEntry(id: 1, projectId: 1, start: start, lastEnd: at(60))
        #expect(AutoLogPlanner.plan(run: run, entry: entry, entryIsIntact: false, now: at(90)) == .restart)
    }

    @Test func mergesWithinGapOfSameProject() {
        let previous = AutoLogEntry(id: 1, projectId: 1, start: at(-600), lastEnd: at(-120))
        #expect(AutoLogPlanner.plan(run: run, entry: previous, entryIsIntact: true, now: at(60)) == .setEnd(at(60)))
    }

    @Test func doesNotMergeOtherProjectOrLargerGapOrChangedEntry() {
        let late = AutoLogEntry(id: 1, projectId: 1, start: at(-600), lastEnd: at(-121))
        let other = AutoLogEntry(id: 1, projectId: 2, start: at(-600), lastEnd: at(-30))
        let touched = AutoLogEntry(id: 1, projectId: 1, start: at(-600), lastEnd: at(-30))
        let create = AutoLogAction.create(DateRange(start: start, end: at(60)))
        #expect(AutoLogPlanner.plan(run: run, entry: late, entryIsIntact: true, now: at(60)) == create)
        #expect(AutoLogPlanner.plan(run: run, entry: other, entryIsIntact: true, now: at(60)) == create)
        #expect(AutoLogPlanner.plan(run: run, entry: touched, entryIsIntact: false, now: at(60)) == create)
    }
}
