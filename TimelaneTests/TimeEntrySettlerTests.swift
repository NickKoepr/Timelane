import Foundation
import Testing
@testable import Timelane

struct TimeEntrySettlerTests {
    typealias F = SyncFixtures

    func tailId(of parent: Int, at hour: Double) -> UUID {
        DeterministicUUID.make(from: "\(F.uuid(parent).uuidString):split:\(F.t(hour * F.hour).timeIntervalSince1970)")
    }

    @Test func nonOverlappingEntriesNeedNothing() {
        let entries = [F.settler(1, F.entry(start: 9, end: 10)), F.settler(2, F.entry(start: 10, end: 11))]
        #expect(TimeEntrySettler.settle(entries).isEmpty)
    }

    // D1: the entry with the newest action wins; the older one is trimmed.
    @Test func olderEntryIsTrimmed() {
        let older = F.settler(1, F.entry(start: 9, end: 11, at: 10))
        let newer = F.settler(2, F.entry(start: 10, end: 12, at: 20))
        let result = TimeEntrySettler.settle([older, newer])
        #expect(result.deletes.isEmpty)
        #expect(result.saves.count == 1)
        #expect(result.saves[0].syncId == F.uuid(1))
        #expect(result.saves[0].fields.end == F.t(10 * F.hour))
        // Corrections keep the loser's timestamps.
        #expect(result.saves[0].fields.updatedAt == older.fields.updatedAt)
        #expect(result.saves[0].fields.timesUpdatedAt == older.fields.timesUpdatedAt)
    }

    @Test func trimsTheStartWhenCoveredAtTheStart() {
        let older = F.settler(1, F.entry(start: 10, end: 12, at: 10))
        let newer = F.settler(2, F.entry(start: 9, end: 11, at: 20))
        let result = TimeEntrySettler.settle([older, newer])
        #expect(result.saves.map(\.fields.start) == [F.t(11 * F.hour)])
        #expect(result.saves.map(\.fields.end) == [F.t(12 * F.hour)])
    }

    @Test func fullyCoveredEntryIsDeleted() {
        let older = F.settler(1, F.entry(start: 9, end: 10, at: 10))
        let newer = F.settler(2, F.entry(start: 8, end: 12, at: 20))
        let result = TimeEntrySettler.settle([older, newer])
        #expect(result.deletes == [F.uuid(1)])
        #expect(result.saves.isEmpty)
    }

    @Test func entryIsSplitWithDeterministicTail() {
        let older = F.settler(1, F.entry(start: 8, end: 12, at: 10, title: "Long"))
        let newer = F.settler(2, F.entry(start: 9, end: 10, at: 20))
        let result = TimeEntrySettler.settle([older, newer])
        #expect(result.deletes.isEmpty)
        let head = result.saves.first { $0.syncId == F.uuid(1) }
        let tail = result.saves.first { $0.syncId == tailId(of: 1, at: 10) }
        #expect(result.saves.count == 2)
        #expect(head?.fields.end == F.t(9 * F.hour))
        #expect(tail?.fields.start == F.t(10 * F.hour))
        #expect(tail?.fields.end == F.t(12 * F.hour))
        #expect(tail?.fields.title == "Long")
        #expect(tail?.fields.updatedAt == older.fields.updatedAt)
    }

    // D1: equal action times: the larger syncId is placed first.
    @Test func equalActionTimeFavoursLargerSyncId() {
        let a = F.settler(1, F.entry(start: 9, end: 11, at: 10))
        let b = F.settler(2, F.entry(start: 10, end: 12, at: 10))
        let result = TimeEntrySettler.settle([a, b])
        #expect(result.saves.map(\.syncId) == [F.uuid(1)])
        #expect(result.saves[0].fields.end == F.t(10 * F.hour))
    }

    // D2: action time is the max over the three groups.
    @Test func textEditCountsAsAction() {
        var edited = F.entry(start: 9, end: 11, at: 10)
        edited.textUpdatedAt = F.t(500)
        let other = F.entry(start: 10, end: 12, at: 100)
        let result = TimeEntrySettler.settle([F.settler(1, edited), F.settler(2, other)])
        #expect(result.saves.map(\.syncId) == [F.uuid(2)])
    }

    // D8: an entry across midnight is just an interval.
    @Test func entryAcrossMidnightIsTrimmedOnTheNextDay() {
        let late = F.settler(1, F.entry(start: 23, end: 25, at: 10))
        let early = F.settler(2, F.entry(start: 24.5, end: 26, at: 20))
        let result = TimeEntrySettler.settle([late, early])
        #expect(result.saves.map(\.syncId) == [F.uuid(1)])
        #expect(result.saves[0].fields.end == F.t(24.5 * F.hour))
    }

    @Test func manyOverlapsBecomeDisjoint() {
        let entries = [
            F.settler(1, F.entry(start: 8, end: 14, at: 1)),
            F.settler(2, F.entry(start: 9, end: 10, at: 2)),
            F.settler(3, F.entry(start: 11, end: 12, at: 3)),
            F.settler(4, F.entry(start: 9.5, end: 11.5, at: 4)),
        ]
        let settled = F.apply(TimeEntrySettler.settle(entries), to: entries).sorted { $0.fields.start < $1.fields.start }
        for (lhs, rhs) in zip(settled, settled.dropFirst()) {
            #expect(lhs.fields.end <= rhs.fields.start)
        }
    }

    @Test func settlingTwiceChangesNothing() {
        let entries = [
            F.settler(1, F.entry(start: 8, end: 14, at: 1)),
            F.settler(2, F.entry(start: 9, end: 10, at: 2)),
            F.settler(3, F.entry(start: 11, end: 12, at: 3)),
            F.settler(4, F.entry(start: 9.5, end: 11.5, at: 4)),
        ]
        let once = F.apply(TimeEntrySettler.settle(entries), to: entries)
        #expect(TimeEntrySettler.settle(once).isEmpty)
    }

    @Test func existingTailFromAnotherDeviceIsNotDuplicated() {
        let parent = F.entry(start: 8, end: 12, at: 10)
        var tail = parent
        tail.start = F.t(10 * F.hour)
        let entries = [
            F.settler(1, parent),
            F.settler(2, F.entry(start: 9, end: 10, at: 20)),
            SyncSettlerEntry(syncId: tailId(of: 1, at: 10), fields: tail),
        ]
        let once = F.apply(TimeEntrySettler.settle(entries), to: entries)
        #expect(once.count == 3)
        #expect(TimeEntrySettler.settle(once).isEmpty)
    }

    @Test func inputOrderDoesNotMatter() {
        let entries = [
            F.settler(1, F.entry(start: 8, end: 14, at: 1)),
            F.settler(2, F.entry(start: 9, end: 10, at: 2)),
            F.settler(3, F.entry(start: 11, end: 12, at: 3)),
            F.settler(4, F.entry(start: 9.5, end: 11.5, at: 3)),
            F.settler(5, F.entry(start: 13, end: 15, at: 3)),
        ]
        let expected = TimeEntrySettler.settle(entries)
        for seed in 0..<8 {
            var shuffled = entries
            var generator = SeededGenerator(seed: UInt64(seed + 1))
            shuffled.shuffle(using: &generator)
            #expect(TimeEntrySettler.settle(shuffled) == expected)
        }
    }
}
