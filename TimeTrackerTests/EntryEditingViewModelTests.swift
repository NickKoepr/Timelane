import Foundation
import Testing
@testable import TimeTracker

@MainActor
struct EntryEditingViewModelTests {
    let cal = TestCalendar.make()
    func d(_ h: Int, _ m: Int = 0) -> Date { TestCalendar.date(2026, 11, 3, h, m, calendar: cal) }

    struct Fixture {
        let vm: EntryEditingViewModel
        let repo: GRDBTimeEntryRepository
        let project: Project
        let geometry: TimelineGeometry
    }

    func makeFixture() async throws -> Fixture {
        let db = try AppDatabase.inMemory()
        let repo = GRDBTimeEntryRepository(database: db)
        let project = try await GRDBProjectRepository(database: db).save(Project(name: "A", colorHex: "#000000"))
        let vm = EntryEditingViewModel(editor: TimeEntryEditor(repository: repo))
        return Fixture(vm: vm, repo: repo, project: project, geometry: TimelineGeometry(day: .day(of: d(12), calendar: cal)))
    }

    func entry(_ f: Fixture, _ start: Date, _ end: Date) async throws -> TimeEntry {
        try await f.repo.save([TimeEntry(projectId: f.project.id!, start: start, end: end)], deleting: [])
        return try await f.repo.entries(in: f.geometry.day).first { $0.start == start }!
    }

    @Test func movingCommitsSnappedRangeAndResolvesOverlap() async throws {
        let f = try await makeFixture()
        let moving = try await entry(f, d(9), d(10))
        _ = try await entry(f, d(11), d(12))
        f.vm.dragChanged(moving, mode: .move, translationY: 80 * 2 + 1, geometry: f.geometry)   // +2h → 11:00–12:00
        #expect(f.vm.displayRange(for: moving) == DateRange(start: d(11), end: d(12)))
        await f.vm.dragEnded(moving)
        #expect(f.vm.preview == nil)
        let saved = try await f.repo.entries(in: f.geometry.day)
        #expect(saved.count == 1)
        #expect(saved[0].id == moving.id && saved[0].start == d(11))
    }

    @Test func unchangedDragDoesNotWrite() async throws {
        let f = try await makeFixture()
        let item = try await entry(f, d(9), d(10))
        f.vm.dragChanged(item, mode: .resizeBottom, translationY: 1, geometry: f.geometry)
        await f.vm.dragEnded(item)
        let saved = try await f.repo.entries(in: f.geometry.day)
        #expect(saved[0].updatedAt == item.updatedAt)
    }

    @Test func entriesCrossingMidnightCannotBeDragged() async throws {
        let f = try await makeFixture()
        let crossing = TimeEntry(id: 1, projectId: f.project.id!, start: d(23), end: d(23).addingTimeInterval(7200))
        #expect(!f.vm.canDrag(crossing, in: f.geometry))
        f.vm.dragChanged(crossing, mode: .move, translationY: 50, geometry: f.geometry)
        #expect(f.vm.preview == nil)
    }

    @Test func detailSavesChangesAndCloses() async throws {
        let f = try await makeFixture()
        let item = try await entry(f, d(9), d(10))
        f.vm.select(item, projects: [f.project])
        let detail = try #require(f.vm.detail)
        detail.note = "  fixed bug "
        detail.end = d(10, 30)
        await detail.save()
        #expect(f.vm.detail == nil)
        let saved = try await f.repo.entries(in: f.geometry.day)
        #expect(saved[0].note == "fixed bug")
        #expect(saved[0].end == d(10, 30))
    }

    @Test func detailRejectsEmptyRange() async throws {
        let f = try await makeFixture()
        let item = try await entry(f, d(9), d(10))
        f.vm.select(item, projects: [f.project])
        let detail = try #require(f.vm.detail)
        detail.end = d(9)
        #expect(!detail.canSave)
        await detail.save()
        #expect(detail.errorMessage != nil)
    }

    @Test func deleteRemovesAndDeselects() async throws {
        let f = try await makeFixture()
        let item = try await entry(f, d(9), d(10))
        f.vm.select(item, projects: [f.project])
        await f.vm.delete(item)
        #expect(try await f.repo.entries(in: f.geometry.day).isEmpty)
        #expect(f.vm.selectedEntryId == nil)
    }
}
