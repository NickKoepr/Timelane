import Foundation
import Testing
@testable import Timelane

@MainActor
struct OverviewDayDetailTests {
    let day = TestCalendar.date(2026, 3, 3)

    func projects(_ count: Int, archived: Set<Int64> = []) -> [Project] {
        (1...count).map {
            Project(id: Int64($0), name: "P\($0)", colorHex: "#111111", isArchived: archived.contains(Int64($0)))
        }
    }
    func detail(_ seconds: [Int64: TimeInterval], projects: [Project], highlighted: Int64? = nil) -> OverviewDayDetail {
        OverviewDayDetail(day: day, secondsByProject: seconds, projects: projects, highlightedProjectId: highlighted)
    }

    @Test func emptyDay() {
        let d = detail([:], projects: projects(2))
        #expect(d.rows.isEmpty && d.totalSeconds == 0)
    }

    @Test func sortsBySecondsThenName() {
        let d = detail([1: 3600, 2: 7200, 3: 3600], projects: projects(3))
        #expect(d.rows.map(\.name) == ["P2", "P1", "P3"])
        #expect(d.totalSeconds == 3 * 3600 + 3600)
    }

    @Test func exactlyFiveShowsFiveRows() {
        let d = detail(Dictionary(uniqueKeysWithValues: (1...5).map { (Int64($0), 3600.0) }), projects: projects(5))
        #expect(d.rows.count == 5)
        #expect(d.rows.allSatisfy { $0.projectId != nil })
    }

    @Test func sevenProjectsFoldIntoMore() {
        let d = detail(Dictionary(uniqueKeysWithValues: (1...7).map { (Int64($0), Double(8 - $0) * 3600) }), projects: projects(7))
        #expect(d.rows.count == 5)
        #expect(d.rows.prefix(4).map(\.name) == ["P1", "P2", "P3", "P4"])
        let more = d.rows[4]
        #expect(more.name == "+3 more" && more.projectId == nil && more.colorHex == nil)
        #expect(more.seconds == (3 + 2 + 1) * 3600)
        #expect(d.totalSeconds == 28 * 3600)
    }

    @Test func unknownProject() {
        let d = detail([99: 3600], projects: projects(1))
        #expect(d.rows.first?.name == "Unknown project")
        #expect(d.rows.first?.colorHex == "#8E8E93")
    }

    @Test func highlightAndArchivedFlags() {
        let d = detail([1: 3600, 2: 1800], projects: projects(2, archived: [2]), highlighted: 2)
        #expect(d.rows.map(\.isHighlighted) == [false, true])
        #expect(d.rows.map(\.isArchived) == [false, true])
        #expect(d.totalSeconds == 5400)   // ignores the filter
    }

    @Test func hoverStateLeaveOfOtherDayKeepsCurrent() {
        let state = HeatmapHoverState()
        let other = TestCalendar.date(2026, 3, 4)
        state.enter(day: day)
        state.enter(day: other)
        state.leave(day: day)
        #expect(state.day == other)
        state.update(frame: CGRect(x: 1, y: 2, width: 3, height: 4))
        state.leave(day: other)
        #expect(state.day == nil && state.frame == nil)
    }
}
