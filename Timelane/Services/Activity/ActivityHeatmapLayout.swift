import Foundation

/// Positions of the day squares: column = week, row = weekday, honoring `calendar.firstWeekday`.
/// Column 0 is the week containing the first day of the year; row = days since that week's start.
struct ActivityHeatmapLayout: Sendable {
    struct Cell: Hashable, Sendable { let day: Date; let column: Int; let row: Int }
    struct MonthLabel: Hashable, Sendable { let title: String; let column: Int }
    struct WeekdayLabel: Hashable, Sendable { let row: Int; let title: String }

    let columnCount: Int
    /// Only days inside the year (no padding cells).
    let cells: [Cell]
    /// Short month symbol at the column containing the 1st of the month; a label less than
    /// `minimumLabelSpacing` columns after the previous one is dropped (like GitHub).
    let monthLabels: [MonthLabel]
    /// Rows 0, 2 and 4, e.g. Mon, Wed, Fri when Monday-first.
    let weekdayLabels: [WeekdayLabel]

    static let minimumLabelSpacing = 3

    init(year: DateRange, calendar: Calendar) {
        let firstWeekStart = Self.weekStart(of: year.start, calendar: calendar)
        var cells: [Cell] = []
        var labels: [MonthLabel] = []
        var day = year.start
        while day < year.end {
            let offset = calendar.dateComponents([.day], from: firstWeekStart, to: day).day ?? 0
            let cell = Cell(day: day, column: offset / 7, row: offset % 7)
            cells.append(cell)
            if calendar.component(.day, from: day) == 1 {
                let month = calendar.component(.month, from: day)
                let title = calendar.shortMonthSymbols[month - 1]
                if labels.last.map({ cell.column - $0.column >= Self.minimumLabelSpacing }) ?? true {
                    labels.append(MonthLabel(title: title, column: cell.column))
                }
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        }
        self.cells = cells
        self.columnCount = (cells.last?.column ?? -1) + 1
        self.monthLabels = labels

        let symbols = calendar.shortWeekdaySymbols   // Sunday first
        self.weekdayLabels = [0, 2, 4].map { row in
            WeekdayLabel(row: row, title: symbols[(calendar.firstWeekday - 1 + row) % 7])
        }
    }

    private static func weekStart(of date: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let back = (weekday - calendar.firstWeekday + 7) % 7
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -back, to: start) ?? start
    }
}
