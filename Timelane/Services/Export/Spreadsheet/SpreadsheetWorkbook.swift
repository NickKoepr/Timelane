import Foundation

/// Format-neutral spreadsheet model; `XLSXWriter` turns it into a file.
struct SpreadsheetWorkbook: Sendable {
    struct Row: Sendable {
        var cells: [SpreadsheetCell]
        var bold = false
    }

    struct Sheet: Sendable {
        var name: String
        var rows: [Row]
        var columnWidths: [Double] = []
        /// Number of rows from the top that stay visible while scrolling.
        var frozenRows = 0
    }

    var sheets: [Sheet]
    /// Dates and times are shown in this zone.
    var timeZone: TimeZone
}
