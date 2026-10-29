import Foundation

enum ExportFormats {
    /// The registry: the only place that knows the concrete formats.
    static let all: [any MonthExportFormat] = [ExcelMonthExportFormat(), JSONMonthExportFormat()]

    static func format(id: String) -> (any MonthExportFormat)? {
        all.first { $0.id == id }
    }
}
