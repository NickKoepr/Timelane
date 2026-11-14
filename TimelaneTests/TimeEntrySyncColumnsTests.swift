import Foundation
import GRDB
import Testing
@testable import Timelane

struct TimeEntrySyncColumnsTests {
    let db: AppDatabase
    let repo: GRDBTimeEntryRepository
    let projectId: Int64
    let otherProjectId: Int64

    init() async throws {
        db = try AppDatabase.inMemory()
        repo = GRDBTimeEntryRepository(database: db)
        let projects = GRDBProjectRepository(database: db)
        projectId = try await projects.save(Project(name: "Alpha", colorHex: "#4F8EF7")).id!
        otherProjectId = try await projects.save(Project(name: "Beta", colorHex: "#34C759")).id!
    }

    func d(_ h: Int) -> Date { TestCalendar.date(2026, 11, 3, h) }
    func t(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

    func row(_ id: Int64) async throws -> SyncTimeEntryRow {
        try await db.writer.read { db in try #require(try SyncTimeEntryRow.fetch(db, id: id)) }
    }

    @Test func insertSetsAllGroupsToUpdatedAt() async throws {
        let entry = TimeEntry(projectId: projectId, start: d(9), end: d(10), updatedAt: t(5000))
        let saved = try await repo.save([entry], deleting: []).first!
        let stored = try await row(saved.id!)
        #expect(stored.timesUpdatedAt == t(5000))
        #expect(stored.textUpdatedAt == t(5000))
        #expect(stored.projectUpdatedAt == t(5000))
    }

    @Test func onlyChangedGroupsAreBumped() async throws {
        var saved = try await repo.save([TimeEntry(projectId: projectId, start: d(9), end: d(10), updatedAt: t(5000))],
                                        deleting: []).first!
        saved.title = "New title"
        saved.updatedAt = t(6000)
        saved = try await repo.save([saved], deleting: []).first!
        var stored = try await row(saved.id!)
        #expect(stored.textUpdatedAt == t(6000))
        #expect(stored.timesUpdatedAt == t(5000))
        #expect(stored.projectUpdatedAt == t(5000))

        saved.end = d(11)
        saved.updatedAt = t(7000)
        saved = try await repo.save([saved], deleting: []).first!
        stored = try await row(saved.id!)
        #expect(stored.timesUpdatedAt == t(7000))
        #expect(stored.textUpdatedAt == t(6000))
        #expect(stored.projectUpdatedAt == t(5000))

        saved.projectId = otherProjectId
        saved.updatedAt = t(8000)
        saved = try await repo.save([saved], deleting: []).first!
        stored = try await row(saved.id!)
        #expect(stored.projectUpdatedAt == t(8000))
        #expect(stored.timesUpdatedAt == t(7000))
        #expect(stored.textUpdatedAt == t(6000))
    }

    @Test func resavingUnchangedEntryBumpsNothing() async throws {
        var saved = try await repo.save([TimeEntry(projectId: projectId, start: d(9), end: d(10), updatedAt: t(5000))],
                                        deleting: []).first!
        saved.updatedAt = t(9000)
        saved = try await repo.save([saved], deleting: []).first!
        let stored = try await row(saved.id!)
        #expect(stored.timesUpdatedAt == t(5000))
        #expect(stored.textUpdatedAt == t(5000))
        #expect(stored.projectUpdatedAt == t(5000))
    }

    @Test func splitTailGetsNewSyncIdAndHeadKeepsOne() async throws {
        let original = try await repo.save([TimeEntry(projectId: projectId, start: d(9), end: d(14))], deleting: []).first!
        let incoming = TimeEntry(projectId: projectId, start: d(10), end: d(12))
        let resolution = TimeEntryOverlapResolver.resolve(existing: [original], applying: incoming, now: .now)
        try await repo.save(resolution.toSave, deleting: resolution.toDelete)
        let all = try await repo.entries(in: DateRange(start: d(0), end: d(23)))
        #expect(all.count == 3)
        #expect(Set(all.map(\.syncId)).count == 3)
        #expect(all.contains { $0.syncId == original.syncId && $0.end == d(10) })
    }

    @Test func undoKeepsSyncId() async throws {
        let history = TimeEntryHistory(repository: repo)
        let editor = TimeEntryEditor(repository: repo, onChange: { await history.record($0) })
        try await editor.create(projectId: projectId, range: DateRange(start: d(9), end: d(10)), title: "T", note: nil)
        let range = DateRange(start: d(0), end: d(23))
        let original = try await repo.entries(in: range)
        await history.undo()
        #expect(try await repo.entries(in: range).isEmpty)
        await history.redo()
        #expect(try await repo.entries(in: range).map(\.syncId) == original.map(\.syncId))
    }
}
