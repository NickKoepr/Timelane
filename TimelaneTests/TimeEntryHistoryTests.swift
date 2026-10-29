import Foundation
import Testing
@testable import Timelane

@MainActor
struct TimeEntryHistoryTests {
    let repo: GRDBTimeEntryRepository
    let history: TimeEntryHistory
    let editor: TimeEntryEditor
    let projectId: Int64

    init() async throws {
        let db = try AppDatabase.inMemory()
        repo = GRDBTimeEntryRepository(database: db)
        let history = TimeEntryHistory(repository: repo)
        self.history = history
        let fixed = TestCalendar.date(2026, 11, 3, 20)
        editor = TimeEntryEditor(repository: repo, now: { fixed }, onChange: { await history.record($0) })
        projectId = try await GRDBProjectRepository(database: db).save(Project(name: "A", colorHex: "#000000")).id!
    }

    func d(_ h: Int, _ m: Int = 0) -> Date { TestCalendar.date(2026, 11, 3, h, m) }
    func all() async throws -> [TimeEntry] { try await repo.entries(in: .day(of: d(12), calendar: TestCalendar.make())) }
    func create(_ from: Int, _ to: Int, note: String? = nil) async throws {
        try await editor.create(projectId: projectId, range: DateRange(start: d(from), end: d(to)), title: "T", note: note)
    }

    @Test func createUndoRedoKeepsId() async throws {
        try await create(9, 10)
        let original = try await all()
        await history.undo()
        #expect(try await all().isEmpty)
        await history.redo()
        #expect(try await all() == original)
    }

    @Test func undoOfSplitRestoresOriginalEntry() async throws {
        try await create(9, 14, note: "keep")
        let original = try await all()
        try await create(10, 12)
        #expect(try await all().count == 3)
        await history.undo()
        #expect(try await all() == original)
        await history.redo()
        #expect(try await all().map { [$0.start, $0.end] } == [[d(9), d(10)], [d(10), d(12)], [d(12), d(14)]])
        await history.undo()
        #expect(try await all() == original)
    }

    @Test func undoOfUpdateMovingFarAway() async throws {
        try await create(9, 10)
        var entry = try await all()[0]
        let original = entry
        entry.start = d(15); entry.end = d(16)
        try await editor.update(entry)
        await history.undo()
        #expect(try await all() == [original])
    }

    @Test func undoOfDeleteRestoresEntryWithSameId() async throws {
        try await create(9, 10, note: "x")
        let original = try await all()
        try await editor.delete(original[0])
        #expect(try await all().isEmpty)
        await history.undo()
        #expect(try await all() == original)
        await history.redo()
        #expect(try await all().isEmpty)
    }

    @Test func multipleUndosRunInReverseAndNewActionClearsRedo() async throws {
        try await create(9, 10)
        try await create(11, 12)
        try await create(13, 14)
        await history.undo()
        await history.undo()
        #expect(try await all().count == 1)
        #expect(history.canRedo)
        try await create(15, 16)
        #expect(!history.canRedo)
        #expect(try await all().count == 2)
    }

    @Test func editorWithoutOnChangeAddsNoHistory() async throws {
        let plain = TimeEntryEditor(repository: repo)
        try await plain.create(projectId: projectId, range: DateRange(start: d(9), end: d(10)), note: nil)
        #expect(!history.canUndo)
    }
}
