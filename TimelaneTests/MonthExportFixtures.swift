import Foundation
@testable import Timelane

enum MonthExportFixtures {
    static let cal = TestCalendar.make()
    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        TestCalendar.date(y, m, d, h, min, calendar: cal)
    }

    static var october: DateRange { .month(of: date(2026, 10, 15), calendar: cal) }

    static func sample() -> MonthExport {
        MonthExport(
            month: october, generatedAt: date(2026, 10, 29, 14, 3), timeZone: cal.timeZone,
            projects: [
                .init(name: "Acme & Co", colorHex: "#4F8EF7", isArchived: false, totalSeconds: 4800 + 12_600),
                .init(name: "Old", colorHex: "#34C759", isArchived: true, totalSeconds: 3600),
            ],
            entries: [
                .init(projectName: "Acme & Co", start: date(2026, 10, 3, 9), end: date(2026, 10, 3, 12, 30),
                      title: "A & B <c>", note: nil),
                .init(projectName: "Acme & Co", start: date(2026, 10, 24, 9), end: date(2026, 10, 24, 10, 20),
                      title: nil, note: "n"),
                .init(projectName: "Old", start: date(2026, 10, 26, 9), end: date(2026, 10, 26, 10), title: nil, note: nil),
            ])
    }
}
