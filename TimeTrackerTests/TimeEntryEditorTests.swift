import Foundation
import Testing
@testable import TimeTracker

struct TimeEntryEditorTests {
    let repo: GRDBTimeEntryRepository
    let editor: TimeEntryEditor
    let projectId: Int64
    let now = TestCalendar.date(2026, 11, 3, 20)

    init() async throws {
        let db = try AppDatabase.inMemory()
        repo = GRDBTimeEntryRepository(database: db)
        let fixed = TestCalendar.date(2026, 11, 3, 20)
        editor = TimeEntryEditor(repository: repo, now: { fixed })
        projectId = try await GRDBProjectRepository(database: db).save(Project(name: "A", colorHex: "#000000")).id!
    }

    func d(_ h: Int, _ m: Int = 0) -> Date { TestCalendar.date(2026, 11, 3, h, m) }
    func all() async throws -> [TimeEntry] { try await repo.entries(in: .day(of: d(12), calendar: TestCalendar.make())) }

    @Test func createPersistsEntryWithTrimmedNote() async throws {
        try await editor.create(projectId: projectId, range: DateRange(start: d(10), end: d(13)), note: "  work  ")
        let entries = try await all()
        #expect(entries.count == 1)
        #expect(entries[0].note == "work")
        #expect(entries[0].createdAt == now)
    }

    @Test func createSplitsExistingEntryInOneStep() async throws {
        try await editor.create(projectId: projectId, range: DateRange(start: d(9), end: d(14)), note: nil)
        try await editor.create(projectId: projectId, range: DateRange(start: d(10), end: d(12)), note: nil)
        let ranges = try await all().map { [$0.start, $0.end] }
        #expect(ranges == [[d(9), d(10)], [d(10), d(12)], [d(12), d(14)]])
    }

    @Test func updateMovesEntryOverNeighbourAndTrimsIt() async throws {
        try await editor.create(projectId: projectId, range: DateRange(start: d(9), end: d(10)), note: nil)
        try await editor.create(projectId: projectId, range: DateRange(start: d(11), end: d(12)), note: nil)
        var first = try await all()[0]
        first.start = d(9, 30); first.end = d(11, 30)
        try await editor.update(first)
        let entries = try await all()
        #expect(entries.count == 2)
        #expect(entries[0].start == d(9, 30) && entries[0].end == d(11, 30))
        #expect(entries[1].start == d(11, 30) && entries[1].end == d(12))
    }

    @Test func tooShortIsRejected() async throws {
        await #expect(throws: TimeEntryEditorError.tooShort) {
            try await editor.create(projectId: projectId, range: DateRange(start: d(10), end: d(10)), note: nil)
        }
    }

    @Test func deleteRemovesEntry() async throws {
        try await editor.create(projectId: projectId, range: DateRange(start: d(9), end: d(10)), note: nil)
        try await editor.delete(try await all()[0])
        #expect(try await all().isEmpty)
    }
}

struct PersistenceTests {
    @Test func entryWithTitleSurvivesReopeningTheDatabaseFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TimeTrackerTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("db.sqlite")
        let day = DateRange.day(of: TestCalendar.date(2026, 11, 3, 12), calendar: TestCalendar.make())

        do {
            let db = try AppDatabase.file(at: url)
            let projectId = try await GRDBProjectRepository(database: db).save(Project(name: "A", colorHex: "#000000")).id!
            let editor = TimeEntryEditor(repository: GRDBTimeEntryRepository(database: db))
            try await editor.create(projectId: projectId,
                                    range: DateRange(start: TestCalendar.date(2026, 11, 3, 9), end: TestCalendar.date(2026, 11, 3, 10)),
                                    title: " Write report ", note: nil)
        }

        let reopened = try AppDatabase.file(at: url)
        let entries = try await GRDBTimeEntryRepository(database: reopened).entries(in: day)
        #expect(entries.count == 1)
        #expect(entries[0].title == "Write report")
    }
}
