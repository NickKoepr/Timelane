import Foundation
import Testing
@testable import Timelane

struct ActivityStatisticsTests {
    let cal = TestCalendar.make()
    func d(_ y: Int, _ m: Int, _ day: Int) -> Date { TestCalendar.date(y, m, day, calendar: cal) }
    var year: DateRange { .year(of: d(2026, 6, 1), calendar: cal) }
    func stats(_ totals: [Date: TimeInterval], today: Date) -> ActivityStatistics {
        ActivityStatistics(dailyTotals: totals, year: year, today: today, calendar: cal)
    }

    @Test func emptyYear() {
        let s = stats([:], today: d(2026, 5, 5))
        #expect(s.totalSeconds == 0 && s.activeDays == 0 && s.averagePerActiveDay == 0)
        #expect(s.longestStreak == 0 && s.currentStreak == 0 && s.busiestDay == nil)
    }

    @Test func longestStreakAcrossMonthBoundary() {
        let totals: [Date: TimeInterval] = [
            d(2026, 1, 30): 3600, d(2026, 1, 31): 3600, d(2026, 2, 1): 3600, d(2026, 2, 2): 3600,
            d(2026, 2, 10): 3600, d(2026, 2, 11): 3600,
        ]
        #expect(stats(totals, today: d(2026, 6, 1)).longestStreak == 4)
    }

    @Test func currentStreak() {
        let totals: [Date: TimeInterval] = [d(2026, 5, 3): 3600, d(2026, 5, 4): 3600]
        #expect(stats(totals, today: d(2026, 5, 5)).currentStreak == 2)   // ends yesterday
        #expect(stats(totals, today: d(2026, 5, 4)).currentStreak == 2)   // ends today
        #expect(stats(totals, today: d(2026, 5, 6)).currentStreak == 0)   // ended two days ago
        #expect(stats(totals, today: d(2027, 5, 6)).currentStreak == 0)   // today outside the year
    }

    @Test func busiestDayAndAverage() {
        let totals: [Date: TimeInterval] = [d(2026, 3, 1): 2 * 3600, d(2026, 3, 5): 6 * 3600]
        let s = stats(totals, today: d(2026, 6, 1))
        #expect(s.busiestDay == .init(day: d(2026, 3, 5), seconds: 6 * 3600))
        #expect(s.averagePerActiveDay == 4 * 3600)
        #expect(s.totalSeconds == 8 * 3600 && s.activeDays == 2)
    }
}
