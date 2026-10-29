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
        let previous = AutoLogEntry(id: 1, projectId: 1, start: at(-600), lastEnd: at(-TrackingSettings.mergeGap))
        #expect(AutoLogPlanner.plan(run: run, entry: previous, entryIsIntact: true, now: at(60)) == .setEnd(at(60)))
    }

    @Test func doesNotMergeOtherProjectOrLargerGapOrChangedEntry() {
        let late = AutoLogEntry(id: 1, projectId: 1, start: at(-600), lastEnd: at(-TrackingSettings.mergeGap - 1))
        let other = AutoLogEntry(id: 1, projectId: 2, start: at(-600), lastEnd: at(-30))
        let touched = AutoLogEntry(id: 1, projectId: 1, start: at(-600), lastEnd: at(-30))
        let create = AutoLogAction.create(DateRange(start: start, end: at(60)))
        #expect(AutoLogPlanner.plan(run: run, entry: late, entryIsIntact: true, now: at(60)) == create)
        #expect(AutoLogPlanner.plan(run: run, entry: other, entryIsIntact: true, now: at(60)) == create)
        #expect(AutoLogPlanner.plan(run: run, entry: touched, entryIsIntact: false, now: at(60)) == create)
    }

    @Test func continuationExtendsWithinFirstMinute() {
        let previous = AutoLogEntry(id: 1, projectId: 1, start: at(-600), lastEnd: at(-30))
        #expect(AutoLogPlanner.plan(run: run, entry: previous, entryIsIntact: true, now: at(5)) == .setEnd(at(5)))
    }

    @Test func continuationOfChangedEntryWaitsForTheMinute() {
        let previous = AutoLogEntry(id: 1, projectId: 1, start: at(-600), lastEnd: at(-30))
        #expect(AutoLogPlanner.plan(run: run, entry: previous, entryIsIntact: false, now: at(5)) == .nothing)
    }

    @Test func continuationKeepsExtendingWithinFirstMinute() {
        let grown = AutoLogEntry(id: 1, projectId: 1, start: at(-600), lastEnd: at(5))
        #expect(AutoLogPlanner.plan(run: run, entry: grown, entryIsIntact: true, now: at(10)) == .setEnd(at(10)))
    }

    // MARK: Final step (session ended, possibly in the past)

    @Test func finalStepWithinFirstMinuteDeletesGrownEntry() {
        let entry = AutoLogEntry(id: 1, projectId: 1, start: start, lastEnd: at(300))
        #expect(AutoLogPlanner.plan(run: run, entry: entry, entryIsIntact: true, now: at(30), isFinal: true) == .delete)
    }

    @Test func finalStepInThePastShrinksEntry() {
        let entry = AutoLogEntry(id: 1, projectId: 1, start: start, lastEnd: at(300))
        #expect(AutoLogPlanner.plan(run: run, entry: entry, entryIsIntact: true, now: at(180), isFinal: true) == .setEnd(at(180)))
    }

    @Test func finalStepOfMergedEntryNeverEndsBeforeRunStart() {
        let runStart = at(600)
        let merged = AutoLogEntry(id: 1, projectId: 1, start: start, lastEnd: at(900))
        let action = AutoLogPlanner.plan(run: AutoLogRun(projectId: 1, start: runStart), entry: merged, entryIsIntact: true,
                                         now: at(620), isFinal: true)
        #expect(action == .setEnd(at(620)))
    }

    @Test func nonFinalTickWithinFirstMinuteStillDoesNothing() {
        let entry = AutoLogEntry(id: 1, projectId: 1, start: start, lastEnd: at(300))
        #expect(AutoLogPlanner.plan(run: run, entry: entry, entryIsIntact: true, now: at(30)) == .nothing)
    }

    @Test func runStartingBeforeRestoredEntryEndExtendsIt() {
        let entry = AutoLogEntry(id: 1, projectId: 1, start: at(-300), lastEnd: at(20))
        #expect(AutoLogPlanner.plan(run: run, entry: entry, entryIsIntact: true, now: at(60)) == .setEnd(at(60)))
    }
}
