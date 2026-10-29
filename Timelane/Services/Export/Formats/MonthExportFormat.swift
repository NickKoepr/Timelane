import Foundation
import UniformTypeIdentifiers

/// One export file format. To add a format: implement this protocol and add it to `ExportFormats.all`.
protocol MonthExportFormat: Sendable {
    var id: String { get }                // stable, e.g. "json", "xlsx" (used for the last-used choice)
    var displayName: String { get }       // "JSON", "Excel (.xlsx)"
    var summary: String { get }           // one line shown under the option in the format sheet
    var contentType: UTType { get }
    var fileExtension: String { get }
    func data(for export: MonthExport) throws -> Data
}
