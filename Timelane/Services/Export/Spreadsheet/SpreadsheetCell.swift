import Foundation

enum SpreadsheetCell: Sendable, Hashable {
    /// `duration`: a fraction of a day shown as `[h]:mm` (hours may exceed 24).
    enum NumberStyle: Sendable, Hashable { case general, duration }

    case empty
    case text(String)
    case number(Double, NumberStyle = .general)
    /// Calendar date (time of day dropped), shown as `yyyy-mm-dd`.
    case date(Date)
    /// Time of day, shown as `hh:mm`.
    case time(Date)
}
