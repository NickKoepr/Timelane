import Foundation
import UniformTypeIdentifiers

struct ExcelMonthExportFormat: MonthExportFormat {
    let id = "xlsx"
    let displayName = "Excel (.xlsx)"
    let summary = "A workbook with a summary per project and every entry, ready for Excel or Numbers."
    let contentType = UTType(filenameExtension: "xlsx") ?? .data
    let fileExtension = "xlsx"

    func data(for export: MonthExport) throws -> Data {
        try XLSXWriter.data(for: workbook(for: export))
    }

    func workbook(for export: MonthExport) -> SpreadsheetWorkbook {
        SpreadsheetWorkbook(sheets: [summarySheet(export), entriesSheet(export)], timeZone: export.timeZone)
    }

    /// Duration as an Excel time value shown as `[h]:mm` (e.g. 1:30), whole minutes like in the app, so it sums.
    private func duration(_ seconds: TimeInterval) -> SpreadsheetCell {
        .number(Double(DurationFormatter.minutes(seconds)) / 1440, .duration)
    }

    private func minutes(_ seconds: TimeInterval) -> SpreadsheetCell { .number(Double(DurationFormatter.minutes(seconds))) }

    private func summarySheet(_ export: MonthExport) -> SpreadsheetWorkbook.Sheet {
        let title = export.month.start.formatted(
            Date.FormatStyle(timeZone: export.timeZone).month(.wide).year())
        typealias Row = SpreadsheetWorkbook.Row
        var rows: [Row] = [
            Row(cells: [.text("Timelane — \(title)")], bold: true),
            Row(cells: []),
            Row(cells: [.text("Project"), .text("Time"), .text("Minutes"), .text("Archived")], bold: true),
        ]
        if export.projects.isEmpty {
            rows.append(Row(cells: [.text("No hours registered in \(title).")]))
        }
        for project in export.projects {
            rows.append(Row(cells: [.text(project.name), duration(project.totalSeconds), minutes(project.totalSeconds),
                                    .text(project.isArchived ? "Yes" : "No")]))
        }
        rows.append(Row(cells: [.text("Total"), duration(export.totalSeconds), minutes(export.totalSeconds)], bold: true))
        return .init(name: "Summary", rows: rows, columnWidths: [32, 10, 10, 12], frozenRows: 3)
    }

    private func entriesSheet(_ export: MonthExport) -> SpreadsheetWorkbook.Sheet {
        var rows = [SpreadsheetWorkbook.Row(
            cells: ["Date", "Start", "End", "Duration", "Minutes", "Project", "Title", "Note"].map { .text($0) }, bold: true)]
        for entry in export.entries {
            rows.append(.init(cells: [
                .date(entry.start), .time(entry.start), .time(entry.end), duration(entry.duration), minutes(entry.duration),
                .text(entry.projectName), entry.title.map { .text($0) } ?? .empty, entry.note.map { .text($0) } ?? .empty,
            ]))
        }
        return .init(name: "Entries", rows: rows, columnWidths: [12, 8, 8, 10, 10, 28, 32, 48], frozenRows: 1)
    }
}
