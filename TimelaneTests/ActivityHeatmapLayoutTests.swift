import Foundation
import Testing
@testable import Timelane

struct ActivityHeatmapLayoutTests {
    func calendar(firstWeekday: Int) -> Calendar {
        var cal = TestCalendar.make()
        cal.firstWeekday = firstWeekday
        cal.locale = Locale(identifier: "en_US")
        return cal
    }
    func layout(_ y: Int, firstWeekday: Int) -> ActivityHeatmapLayout {
        let cal = calendar(firstWeekday: firstWeekday)
        return ActivityHeatmapLayout(year: .year(of: TestCalendar.date(y, 6, 1, calendar: cal), calendar: cal), calendar: cal)
    }

    @Test func mondayFirst2026() {
        let l = layout(2026, firstWeekday: 2)
        let first = l.cells.first!
        #expect(first.column == 0 && first.row == 3)   // Thursday
        #expect(l.cells.count == 365)
        #expect(l.cells.last!.column == l.columnCount - 1)   // Dec 31 (Thursday) is in the last column
        #expect(l.cells.last!.row == 3)
        #expect(l.columnCount == 53)
    }

    @Test func sundayFirst() {
        let l = layout(2026, firstWeekday: 1)
        #expect(l.cells.first!.row == 4)
        #expect(l.weekdayLabels.map(\.row) == [0, 2, 4])
        #expect(l.weekdayLabels.map(\.title) == ["Sun", "Tue", "Thu"])
    }

    @Test func weekdayLabelsMondayFirst() {
        #expect(layout(2026, firstWeekday: 2).weekdayLabels.map(\.title) == ["Mon", "Wed", "Fri"])
    }

    @Test func leapYearHas366Cells() {
        #expect(layout(2028, firstWeekday: 2).cells.count == 366)
    }

    @Test func monthLabelsAreSpacedAndSkipCrowdedOnes() {
        let l = layout(2026, firstWeekday: 2)
        #expect(l.monthLabels.first == .init(title: "Jan", column: 0))
        #expect(l.monthLabels.count == 12)
        let columns = l.monthLabels.map(\.column)
        #expect(zip(columns, columns.dropFirst()).allSatisfy { $1 - $0 >= ActivityHeatmapLayout.minimumLabelSpacing })
        // Feb 1 2026 is a Sunday: column 4 (Jan 1 is Thursday in column 0 → Feb 1 is day 31 → offset 34).
        #expect(l.monthLabels[1] == .init(title: "Feb", column: 4))
    }

    @Test func crowdedMonthLabelIsDropped() {
        // Whatever the year, every kept label is at least `minimumLabelSpacing` columns after the previous.
        for y in 2020...2030 {
            let columns = layout(y, firstWeekday: 1).monthLabels.map(\.column)
            #expect(zip(columns, columns.dropFirst()).allSatisfy { $1 - $0 >= 3 })
        }
    }
}
