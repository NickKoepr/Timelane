import Foundation
import Testing
@testable import Timelane

struct ScreenshotSampleDataTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test func showcaseDayIsTheLastWeekdayBeforeToday() {
        // Monday 2 November 2026 → Friday 30 October.
        let data = ScreenshotSampleData(today: date(2026, 11, 2, hour: 10), calendar: calendar)
        #expect(data.showcaseDay == date(2026, 10, 30))
    }

    @Test func hasDevelopmentProjectsWithOneArchived() {
        let data = ScreenshotSampleData(today: date(2026, 10, 30, hour: 20), calendar: calendar)
        #expect(data.projects.count == 7)
        #expect(data.projects.filter(\.isArchived).count == 1)
        let ids = Set(data.projects.compactMap(\.id))
        #expect(data.entries.allSatisfy { ids.contains($0.projectId) })
        #expect(data.trackedApps.compactMap(\.projectId).allSatisfy { ids.contains($0) })
    }

    @Test func entriesNeverOverlapAndEndBeforeToday() {
        let today = date(2026, 10, 30, hour: 20)
        let data = ScreenshotSampleData(today: today, calendar: calendar)
        let sorted = data.entries.sorted { $0.start < $1.start }
        for (previous, next) in zip(sorted, sorted.dropFirst()) {
            #expect(previous.end <= next.start)
        }
        #expect(sorted.allSatisfy { $0.end > $0.start && $0.end < calendar.startOfDay(for: today) })
    }

    @Test func everyMonthUpToNowHasHours() {
        let data = ScreenshotSampleData(today: date(2026, 10, 30, hour: 20), calendar: calendar)
        let months = Set(data.entries.map { calendar.component(.month, from: $0.start) })
        #expect(months == Set(1...10))
    }

    @Test func theUnloggedSessionHasNoEntry() {
        let data = ScreenshotSampleData(today: date(2026, 10, 30, hour: 20), calendar: calendar)
        #expect(data.sessions.contains { $0.start == data.unloggedRange.start && $0.end == data.unloggedRange.end })
        #expect(!data.entries.contains { $0.range.overlaps(data.unloggedRange) })
    }
}
