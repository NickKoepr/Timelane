import Foundation
import Testing
@testable import Timelane

struct MonthExportBuilderTests {
    let cal = MonthExportFixtures.cal
    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date { MonthExportFixtures.date(y, m, d, h) }

    func build(_ projects: [Project], _ entries: [TimeEntry]) -> MonthExport {
        MonthExportBuilder.build(month: MonthExportFixtures.october, projects: projects, entries: entries,
                                 generatedAt: date(2026, 10, 29), calendar: cal)
    }

    let alpha = Project(id: 1, name: "Alpha", colorHex: "#111111")
    let beta = Project(id: 2, name: "Beta", colorHex: "#222222")
    let old = Project(id: 3, name: "Old", colorHex: "#333333", isArchived: true)
    let idle = Project(id: 4, name: "Idle", colorHex: "#444444")

    @Test func clipsToMonthAndDropsOutsideEntries() {
        let export = build([alpha], [
            TimeEntry(projectId: 1, start: date(2026, 9, 30, 23), end: date(2026, 10, 1, 2)),
            TimeEntry(projectId: 1, start: date(2026, 10, 31, 23), end: date(2026, 11, 1, 3)),
            TimeEntry(projectId: 1, start: date(2026, 11, 5, 9), end: date(2026, 11, 5, 10)),
        ])
        #expect(export.entries.count == 2)
        #expect(export.entries[0].start == date(2026, 10, 1))
        #expect(export.entries[0].duration == 7200)
        #expect(export.entries[1].end == date(2026, 11, 1))
        #expect(export.entries[1].duration == 3600)
        #expect(export.totalSeconds == 10_800)
    }

    @Test func totalsArchivedUnusedAndSorting() {
        let export = build([alpha, beta, old, idle], [
            TimeEntry(projectId: 2, start: date(2026, 10, 6, 9), end: date(2026, 10, 6, 12)),
            TimeEntry(projectId: 1, start: date(2026, 10, 5, 9), end: date(2026, 10, 5, 10)),
            TimeEntry(projectId: 1, start: date(2026, 10, 7, 9), end: date(2026, 10, 7, 11)),
            TimeEntry(projectId: 3, start: date(2026, 10, 8, 9), end: date(2026, 10, 8, 12)),
        ])
        #expect(export.projects.map(\.name) == ["Alpha", "Beta", "Old"])   // 3h each → name order
        #expect(export.projects.map(\.totalSeconds) == [10_800, 10_800, 10_800])
        #expect(export.projects.first { $0.name == "Old" }?.isArchived == true)
        #expect(export.entries.map(\.start) == [date(2026, 10, 5, 9), date(2026, 10, 6, 9),
                                               date(2026, 10, 7, 9), date(2026, 10, 8, 9)])
    }

    @Test func unknownProjectAndTextCleanup() {
        let export = build([alpha], [
            TimeEntry(projectId: 99, start: date(2026, 10, 5, 9), end: date(2026, 10, 5, 10), title: "  ", note: " hi \n"),
        ])
        #expect(export.entries[0].projectName == "Unknown project")
        #expect(export.entries[0].title == nil)
        #expect(export.entries[0].note == "hi")
        #expect(export.projects.map(\.name) == ["Unknown project"])
    }

    @Test func emptyMonth() {
        let export = build([alpha], [])
        #expect(export.projects.isEmpty && export.entries.isEmpty)
        #expect(export.totalSeconds == 0)
    }

    @Test func fileName() {
        let month = MonthExportFixtures.october
        #expect(MonthExportFileName.make(for: month, fileExtension: "json", calendar: cal) == "Timelane 2026-10.json")
        #expect(MonthExportFileName.make(for: month, fileExtension: "xlsx", calendar: cal) == "Timelane 2026-10.xlsx")
    }
}
