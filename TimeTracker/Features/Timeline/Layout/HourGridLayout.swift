import CoreGraphics
import Foundation

/// Which grid lines and time labels to draw for a day at a zoom level. Pure; the view only draws it.
struct HourGridLayout: Equatable {
    enum LineKind: Equatable { case hour, label, minor }

    struct Line: Equatable {
        let date: Date
        let y: CGFloat
        let kind: LineKind
    }

    struct Label: Equatable {
        let date: Date
        let y: CGFloat
        let isHour: Bool
    }

    let lines: [Line]
    let labels: [Label]

    init(geometry: TimelineGeometry, zoom: TimelineZoom) {
        let totalMinutes = Int((geometry.day.duration / 60).rounded())
        var lines: [Line] = []
        var labels: [Label] = []
        for minute in stride(from: 0, through: totalMinutes, by: zoom.minorLineMinutes) {
            let date = geometry.day.start.addingTimeInterval(Double(minute) * 60)
            let y = geometry.y(for: date)
            let isHour = minute % 60 == 0
            let isLabel = minute % zoom.labelIntervalMinutes == 0
            lines.append(Line(date: date, y: y, kind: isHour ? .hour : (isLabel ? .label : .minor)))
            if isLabel && minute < totalMinutes { labels.append(Label(date: date, y: y, isHour: isHour)) }
        }
        self.lines = lines
        self.labels = labels
    }
}
