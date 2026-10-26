import Foundation
import Testing
@testable import TimeTracker

struct ProjectRepositoryTests {
    let db: AppDatabase
    let projects: GRDBProjectRepository
    let entries: GRDBTimeEntryRepository
    let cal = TestCalendar.make()

    init() throws {
        db = try AppDatabase.inMemory()
        projects = GRDBProjectRepository(database: db)
        entries = GRDBTimeEntryRepository(database: db)
    }

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        TestCalendar.date(y, m, d, h, min, calendar: cal)
    }

    @Test func saveAssignsIdAndUpdates() async throws {
        var project = try await projects.save(Project(name: "Alpha", colorHex: "#4F8EF7"))
        #expect(project.id != nil)
        project.name = "Alpha 2"
        let updated = try await projects.save(project)
        #expect(updated.id == project.id)
        let all = try await projects.monthTotals(in: .month(of: .now))
        #expect(all.map(\.project.name) == ["Alpha 2"])
    }

    @Test func duplicateNameIsRejectedCaseInsensitively() async throws {
        _ = try await projects.save(Project(name: "Alpha", colorHex: "#4F8EF7"))
        await #expect(throws: RepositoryError.duplicateName) {
            _ = try await projects.save(Project(name: "ALPHA", colorHex: "#4F8EF7"))
        }
    }

    @Test func archiveHidesFromObservation() async throws {
        let project = try await projects.save(Project(name: "Alpha", colorHex: "#4F8EF7"))
        try await projects.archive(id: project.id!, archived: true)
        var active = projects.observeProjects(includeArchived: false).makeAsyncIterator()
        #expect(await active.next() == [])
        var all = projects.observeProjects(includeArchived: true).makeAsyncIterator()
        #expect(await all.next()?.first?.isArchived == true)
    }

    @Test func monthTotalsClipEntriesToRange() async throws {
        let project = try await projects.save(Project(name: "Alpha", colorHex: "#4F8EF7"))
        let empty = try await projects.save(Project(name: "Beta", colorHex: "#34C759"))
        let id = project.id!
        try await entries.save([
            TimeEntry(projectId: id, start: date(2026, 10, 31, 23), end: date(2026, 11, 1, 1)),
            TimeEntry(projectId: id, start: date(2026, 11, 3, 9), end: date(2026, 11, 3, 10, 30)),
            TimeEntry(projectId: id, start: date(2026, 12, 1, 9), end: date(2026, 12, 1, 10)),
        ], deleting: [])

        let november = try await projects.monthTotals(in: .month(of: date(2026, 11, 15), calendar: cal))
        #expect(november.first?.project.id == id)
        #expect(november.first?.totalSeconds == 9000.0)
        #expect(november.last?.project.id == empty.id)
        #expect(november.last?.totalSeconds == 0)

        let october = try await projects.monthTotals(in: .month(of: date(2026, 10, 15), calendar: cal))
        #expect(october.first?.totalSeconds == 3600)
    }

    @Test func deleteRefusedWhenEntriesExist() async throws {
        let project = try await projects.save(Project(name: "Alpha", colorHex: "#4F8EF7"))
        try await entries.save([TimeEntry(projectId: project.id!, start: date(2026, 11, 3, 9), end: date(2026, 11, 3, 10))],
                               deleting: [])
        await #expect(throws: RepositoryError.projectHasEntries) {
            try await projects.delete(id: project.id!)
        }
        let other = try await projects.save(Project(name: "Beta", colorHex: "#34C759"))
        try await projects.delete(id: other.id!)
        let remaining = try await projects.monthTotals(in: .month(of: date(2026, 11, 3), calendar: cal))
        #expect(remaining.count == 1)
    }
}
