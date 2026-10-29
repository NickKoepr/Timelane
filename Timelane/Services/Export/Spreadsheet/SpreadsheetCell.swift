import Foundation

enum SpreadsheetCell: Sendable, Hashable {
    enum NumberStyle: Sendable, Hashable { case general, hours }

    case empty
    case text(String)
    case number(Double, NumberStyle = .general)
    /// Calendar date (time of day dropped), shown as `yyyy-mm-dd`.
    case date(Date)
    /// Time of day, shown as `hh:mm`.
    case time(Date)
}
