import Foundation
import Testing
@testable import Timelane

struct LiveEntryProjectionTests {
    let t0 = TestCalendar.date(2026, 11, 3, 9)
    func entry(_ id: Int64, _ startMin: Double, _ endMin: Double) -> TimeEntry {
        TimeEntry(id: id, projectId: 1, start: t0.addingTimeInterval(startMin * 60), end: t0.addingTimeInterval(endMin * 60))
    }
    func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

    @Test func extendsTheLiveEntryToNow() {
        let result = LiveEntryProjection.displayed([entry(1, 0, 1)], liveEntryId: 1, now: at(23.5))
        #expect(result[0].end == at(23.5) && result[0].start == at(0))
    }

    @Test func leavesItWhenNowIsNotLater() {
        let entries = [entry(1, 0, 10)]
        #expect(LiveEntryProjection.displayed(entries, liveEntryId: 1, now: at(10)) == entries)
        #expect(LiveEntryProjection.displayed(entries, liveEntryId: 1, now: at(5)) == entries)
    }

    @Test func leavesEverythingWithoutAMatchingId() {
        let entries = [entry(1, 0, 1), entry(2, 30, 40)]
        #expect(LiveEntryProjection.displayed(entries, liveEntryId: nil, now: at(60)) == entries)
        #expect(LiveEntryProjection.displayed(entries, liveEntryId: 9, now: at(60)) == entries)
    }

    @Test func stopsAtTheNextEntry() {
        let result = LiveEntryProjection.displayed([entry(1, 0, 1), entry(2, 10, 20)], liveEntryId: 1, now: at(30))
        #expect(result[0].end == at(10))
    }

    @Test func otherEntriesAreUntouched() {
        let others = [entry(2, -30, -20), entry(3, 40, 50)]
        let result = LiveEntryProjection.displayed([others[0], entry(1, 0, 1), others[1]], liveEntryId: 1, now: at(20))
        #expect(result[0] == others[0] && result[2] == others[1] && result[1].end == at(20))
    }
}
