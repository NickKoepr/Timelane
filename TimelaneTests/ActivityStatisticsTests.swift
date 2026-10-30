import Foundation
import Testing
@testable import Timelane

struct ActivityStatisticsTests {
    let cal = TestCalendar.make()
    func d(_ y: Int, _ m: Int, _ day: Int) -> Date { TestCalendar.date(y, m, day, calendar: cal) }
    func stats(_ totals: [Date: TimeInterval]) -> ActivityStatistics { ActivityStatistics(dailyTotals: totals) }

    @Test func emptyYear() {
        let s = stats([:])
        #expect(s.totalSeconds == 0 && s.activeDays == 0 && s.averagePerActiveDay == 0 && s.busiestDay == nil)
    }

    @Test func busiestDayAndAverage() {
        let totals: [Date: TimeInterval] = [d(2026, 3, 1): 2 * 3600, d(2026, 3, 5): 6 * 3600]
        let s = stats(totals)
        #expect(s.busiestDay == .init(day: d(2026, 3, 5), seconds: 6 * 3600))
        #expect(s.averagePerActiveDay == 4 * 3600)
        #expect(s.totalSeconds == 8 * 3600 && s.activeDays == 2)
    }
}
