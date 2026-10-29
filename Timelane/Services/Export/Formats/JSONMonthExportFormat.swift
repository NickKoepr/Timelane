import Foundation
import UniformTypeIdentifiers

struct JSONMonthExportFormat: MonthExportFormat {
    let id = "json"
    let displayName = "JSON"
    let summary = "Structured data for scripts and other tools."
    let contentType = UTType.json
    let fileExtension = "json"

    func data(for export: MonthExport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Document(export))
    }

    // MARK: DTOs

    private struct Document: Encodable {
        let schemaVersion = 1
        let app = "Timelane"
        let month: String
        let generatedAt: String
        let timeZone: String
        let totalMinutes: Int
        let total: String
        let projects: [ProjectDTO]
        let entries: [EntryDTO]

        init(_ export: MonthExport) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = export.timeZone
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = export.timeZone
            formatter.formatOptions = [.withInternetDateTime]
            month = MonthExportFileName.monthKey(export.month, calendar: calendar)
            generatedAt = formatter.string(from: export.generatedAt)
            timeZone = export.timeZone.identifier
            totalMinutes = DurationFormatter.minutes(export.totalSeconds)
            total = DurationFormatter.hoursMinutes(export.totalSeconds)
            projects = export.projects.map(ProjectDTO.init)
            entries = export.entries.map { EntryDTO($0, formatter: formatter, calendar: calendar) }
        }
    }

    private struct ProjectDTO: Encodable {
        let name: String
        let color: String
        let archived: Bool
        let totalMinutes: Int
        let total: String

        init(_ total: MonthExport.ProjectTotal) {
            name = total.name
            color = total.colorHex
            archived = total.isArchived
            totalMinutes = DurationFormatter.minutes(total.totalSeconds)
            self.total = DurationFormatter.hoursMinutes(total.totalSeconds)
        }
    }

    private struct EntryDTO: Encodable {
        let project: String
        let date: String
        let start: String
        let end: String
        let durationMinutes: Int
        let duration: String
        let title: String?
        let note: String?

        init(_ entry: MonthExport.Entry, formatter: ISO8601DateFormatter, calendar: Calendar) {
            let parts = calendar.dateComponents([.year, .month, .day], from: entry.start)
            project = entry.projectName
            date = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            start = formatter.string(from: entry.start)
            end = formatter.string(from: entry.end)
            durationMinutes = DurationFormatter.minutes(entry.duration)
            duration = DurationFormatter.hoursMinutes(entry.duration)
            title = entry.title
            note = entry.note
        }

        // Encode nil explicitly so every entry has the same keys.
        enum CodingKeys: String, CodingKey {
            case project, date, start, end, durationMinutes, duration, title, note
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(project, forKey: .project)
            try c.encode(date, forKey: .date)
            try c.encode(start, forKey: .start)
            try c.encode(end, forKey: .end)
            try c.encode(durationMinutes, forKey: .durationMinutes)
            try c.encode(duration, forKey: .duration)
            try c.encode(title, forKey: .title)
            try c.encode(note, forKey: .note)
        }
    }
}
