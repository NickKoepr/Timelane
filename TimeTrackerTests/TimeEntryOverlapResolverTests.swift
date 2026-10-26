import Foundation
import Testing
@testable import TimeTracker

struct TimeEntryOverlapResolverTests {
    let now = TestCalendar.date(2026, 11, 3, 20)
    func d(_ h: Int, _ m: Int = 0) -> Date { TestCalendar.date(2026, 11, 3, h, m) }
    func entry(_ id: Int64?, _ project: Int64, _ start: Date, _ end: Date, note: String? = nil) -> TimeEntry {
        TimeEntry(id: id, projectId: project, start: start, end: end, note: note, createdAt: d(8), updatedAt: d(8))
    }

    @Test func noOverlapLeavesOthersAlone() {
        let existing = [entry(1, 1, d(8), d(9)), entry(2, 1, d(14), d(15))]
        let new = entry(nil, 2, d(10), d(12))
        let result = TimeEntryOverlapResolver.resolve(existing: existing, applying: new, now: now)
        #expect(result.toSave == [new])
        #expect(result.toDelete.isEmpty)
    }

    @Test func adjacentEntriesDoNotOverlap() {
        let existing = [entry(1, 1, d(8), d(10))]
        let new = entry(nil, 2, d(10), d(12))
        let result = TimeEntryOverlapResolver.resolve(existing: existing, applying: new, now: now)
        #expect(result.toSave == [new])
        #expect(result.toDelete.isEmpty)
    }

    @Test func fullyCoveredEntryIsDeleted() {
        let existing = [entry(1, 1, d(10), d(11))]
        let result = TimeEntryOverlapResolver.resolve(existing: existing, applying: entry(nil, 2, d(9), d(12)), now: now)
        #expect(result.toDelete == [1])
        #expect(result.toSave.count == 1)
    }

    @Test func exactSameRangeIsReplaced() {
        let existing = [entry(1, 1, d(10), d(11))]
        let result = TimeEntryOverlapResolver.resolve(existing: existing, applying: entry(nil, 2, d(10), d(11)), now: now)
        #expect(result.toDelete == [1])
    }

    @Test func trimsEndOfEarlierEntry() {
        let existing = [entry(1, 1, d(9), d(11))]
        let result = TimeEntryOverlapResolver.resolve(existing: existing, applying: entry(nil, 2, d(10), d(12)), now: now)
        #expect(result.toDelete.isEmpty)
        #expect(result.toSave.count == 2)
        let trimmed = result.toSave[1]
        #expect(trimmed.id == 1)
        #expect(trimmed.start == d(9))
        #expect(trimmed.end == d(10))
        #expect(trimmed.updatedAt == now)
    }

    @Test func trimsStartOfLaterEntry() {
        let existing = [entry(1, 1, d(11), d(13))]
        let result = TimeEntryOverlapResolver.resolve(existing: existing, applying: entry(nil, 2, d(10), d(12)), now: now)
        let trimmed = result.toSave[1]
        #expect(trimmed.id == 1)
        #expect(trimmed.start == d(12))
        #expect(trimmed.end == d(13))
    }

    @Test func splitsEntryContainingTheNewOne() {
        let existing = [entry(1, 1, d(9), d(14), note: "long")]
        let result = TimeEntryOverlapResolver.resolve(existing: existing, applying: entry(nil, 2, d(10), d(12)), now: now)
        #expect(result.toDelete.isEmpty)
        #expect(result.toSave.count == 3)
        let head = result.toSave[1], tail = result.toSave[2]
        #expect(head.id == 1 && head.start == d(9) && head.end == d(10))
        #expect(tail.id == nil && tail.start == d(12) && tail.end == d(14))
        #expect(tail.projectId == 1 && tail.note == "long")
    }

    @Test func handlesMultipleOverlapsAtOnce() {
        let existing = [
            entry(1, 1, d(8), d(10, 30)),   // trimmed at end
            entry(2, 1, d(11), d(11, 30)),  // covered
            entry(3, 1, d(12, 30), d(15)),  // trimmed at start
            entry(4, 1, d(16), d(17)),      // untouched
        ]
        let result = TimeEntryOverlapResolver.resolve(existing: existing, applying: entry(nil, 2, d(10), d(13)), now: now)
        #expect(result.toDelete == [2])
        #expect(result.toSave.map(\.id) == [nil, 1, 3])
        #expect(result.toSave[1].end == d(10))
        #expect(result.toSave[2].start == d(13))
    }

    @Test func movedEntryDoesNotOverlapItself() {
        let original = entry(1, 1, d(9), d(11))
        var moved = original
        moved.start = d(10); moved.end = d(12)
        let result = TimeEntryOverlapResolver.resolve(existing: [original], applying: moved, now: now)
        #expect(result.toSave == [moved])
        #expect(result.toDelete.isEmpty)
    }
}
