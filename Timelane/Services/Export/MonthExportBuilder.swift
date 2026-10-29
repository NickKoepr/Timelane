import Foundation

/// Turns projects and raw entries into a `MonthExport`: clipping, totals, sorting. Pure.
enum MonthExportBuilder {
    static let unknownProjectName = "Unknown project"

    static func build(month: DateRange, projects: [Project], entries: [TimeEntry],
                      generatedAt: Date, calendar: Calendar) -> MonthExport {
        let byId = Dictionary(projects.compactMap { project in project.id.map { ($0, project) } },
                              uniquingKeysWith: { first, _ in first })
        var exported: [MonthExport.Entry] = []
        for entry in entries {
            guard let clipped = entry.range.intersection(with: month) else { continue }
            exported.append(MonthExport.Entry(
                projectName: byId[entry.projectId]?.name ?? unknownProjectName,
                start: clipped.start, end: clipped.end,
                title: clean(entry.title), note: clean(entry.note)
            ))
        }
        exported.sort { ($0.start, $0.end, $0.projectName) < ($1.start, $1.end, $1.projectName) }

        var seconds: [String: TimeInterval] = [:]
        for entry in exported { seconds[entry.projectName, default: 0] += entry.duration }
        var totals = seconds.map { name, total -> MonthExport.ProjectTotal in
            let project = projects.first { $0.name == name }
            return MonthExport.ProjectTotal(name: name, colorHex: project?.colorHex ?? "#8E8E93",
                                            isArchived: project?.isArchived ?? false, totalSeconds: total)
        }
        totals.sort {
            if $0.totalSeconds != $1.totalSeconds { return $0.totalSeconds > $1.totalSeconds }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return MonthExport(month: month, generatedAt: generatedAt, timeZone: calendar.timeZone,
                           projects: totals, entries: exported)
    }

    private static func clean(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
