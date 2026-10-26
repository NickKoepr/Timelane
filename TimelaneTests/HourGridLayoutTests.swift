import CoreGraphics
import Foundation
import Testing
@testable import Timelane

struct HourGridLayoutTests {
    let cal = TestCalendar.make()
    func geometry(_ zoom: TimelineZoom, _ day: Int = 3, _ month: Int = 11) -> TimelineGeometry {
        TimelineGeometry(day: .day(of: TestCalendar.date(2026, month, day, 12, calendar: cal), calendar: cal),
                         pointsPerHour: zoom.pointsPerHour)
    }

    @Test func overviewLabelsEveryHourWithQuarterLines() {
        let layout = HourGridLayout(geometry: geometry(.hour), zoom: .hour)
        #expect(layout.labels.count == 24)
        #expect(layout.labels.allSatisfy { $0.isHour })
        #expect(layout.lines.count == 24 * 4 + 1)
        #expect(layout.lines.filter { $0.kind == .minor }.count == 24 * 3)
    }

    @Test func detailedLevelLabelsEveryTenMinutes() {
        let g = geometry(.tenMinutes)
        let layout = HourGridLayout(geometry: g, zoom: .tenMinutes)
        #expect(layout.labels.count == 24 * 6)
        #expect(layout.labels.filter(\.isHour).count == 24)
        let second = layout.labels[1]
        #expect(second.date == g.day.start.addingTimeInterval(600) && second.y == 80 && !second.isHour)
        #expect(layout.lines.filter { $0.kind == .hour }.count == 25)
        #expect(layout.lines.filter { $0.kind == .minor }.count == 24 * 6)   // 5-minute lines between labels
    }

    @Test func halfHourLevel() {
        let layout = HourGridLayout(geometry: geometry(.halfHour), zoom: .halfHour)
        #expect(layout.labels.count == 48)
        #expect(layout.labels[1].y == 80)
    }

    @Test func shortDayHasFewerLabels() {
        let layout = HourGridLayout(geometry: geometry(.hour, 29, 3), zoom: .hour)   // DST start: 23 hours
        #expect(layout.labels.count == 23)
    }
}
