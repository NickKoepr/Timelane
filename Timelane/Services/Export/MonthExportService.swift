import Foundation

/// Fetches the data of a month and builds the format-independent `MonthExport`.
struct MonthExportService: Sendable {
    let projects: any ProjectRepository
    let timeEntries: any TimeEntryRepository
    var calendar: Calendar = .current
    var now: @Sendable () -> Date = { .now }

    func makeExport(for month: DateRange) async throws -> MonthExport {
        let allProjects = try await projects.projects(includeArchived: true)
        let entries = try await timeEntries.entries(in: month)
        return MonthExportBuilder.build(month: month, projects: allProjects, entries: entries,
                                        generatedAt: now(), calendar: calendar)
    }
}
