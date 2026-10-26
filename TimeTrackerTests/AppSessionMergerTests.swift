import Foundation
import Testing
@testable import TimeTracker

struct AppSessionMergerTests {
    let cal = TestCalendar.make()
    var day: DateRange { .day(of: d(12), calendar: cal) }
    func d(_ h: Int, _ m: Int = 0, _ s: Int = 0, day: Int = 3) -> Date {
        TestCalendar.date(2026, 11, day, h, m, calendar: cal).addingTimeInterval(TimeInterval(s))
    }
    func session(_ id: String, _ start: Date, _ end: Date?) -> AppSession {
        AppSession(bundleIdentifier: id, appName: id, start: start, end: end)
    }

    @Test func mergesSameAppWithSmallGap() {
        let blocks = AppSessionMerger.blocks(from: [
            session("xcode", d(9), d(9, 10)),
            session("xcode", d(9, 10, 30), d(9, 20)),
        ], in: day, now: d(12))
        #expect(blocks.count == 1)
        #expect(blocks[0].start == d(9))
        #expect(blocks[0].end == d(9, 20))
    }

    @Test func keepsSameAppApartWhenGapIsLarge() {
        let blocks = AppSessionMerger.blocks(from: [
            session("xcode", d(9), d(9, 10)),
            session("xcode", d(9, 15), d(9, 20)),
        ], in: day, now: d(12))
        #expect(blocks.count == 2)
    }

    @Test func dropsShortSessionsAndThenMergesNeighbours() {
        let blocks = AppSessionMerger.blocks(from: [
            session("xcode", d(9), d(9, 10)),
            session("slack", d(9, 10), d(9, 10, 20)),
            session("xcode", d(9, 10, 20), d(9, 30)),
        ], in: day, now: d(12))
        #expect(blocks.map(\.bundleIdentifier) == ["xcode"])
        #expect(blocks[0].end == d(9, 30))
    }

    @Test func openSessionRunsUntilNow() {
        let blocks = AppSessionMerger.blocks(from: [session("xcode", d(11), nil)], in: day, now: d(11, 45))
        #expect(blocks.count == 1)
        #expect(blocks[0].duration == 45 * 60)
    }

    @Test func clipsToDayAndIgnoresOutsideSessions() {
        let blocks = AppSessionMerger.blocks(from: [
            session("night", d(23, day: 2), d(1)),
            session("other", d(10, day: 4), d(11, day: 4)),
        ], in: day, now: d(12))
        #expect(blocks.count == 1)
        #expect(blocks[0].start == day.start)
        #expect(blocks[0].end == d(1))
    }

    @Test func preservesDifferentAppsInOrder() {
        let blocks = AppSessionMerger.blocks(from: [
            session("b", d(10), d(11)),
            session("a", d(9), d(10)),
        ], in: day, now: d(12))
        #expect(blocks.map(\.bundleIdentifier) == ["a", "b"])
    }
}
