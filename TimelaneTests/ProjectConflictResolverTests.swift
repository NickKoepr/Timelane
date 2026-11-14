import Foundation
import Testing
@testable import Timelane

struct ProjectConflictResolverTests {
    typealias F = SyncFixtures

    // C1: same name created separately (within 24 hours): merge into the oldest.
    @Test func sameNameCreatedCloseTogetherIsMerged() {
        let plan = ProjectConflictResolver.resolve([
            F.snapshot(1, F.project("Website", created: 100)),
            F.snapshot(2, F.project("website", created: 100 + 3600)),
        ])
        #expect(plan.merges == [.init(loser: F.uuid(2), survivor: F.uuid(1))])
        #expect(plan.renames.isEmpty)
    }

    @Test func mergeTieBreaksOnSmallerSyncId() {
        let plan = ProjectConflictResolver.resolve([
            F.snapshot(7, F.project("Same", created: 50)),
            F.snapshot(3, F.project("Same", created: 50)),
        ])
        #expect(plan.merges == [.init(loser: F.uuid(7), survivor: F.uuid(3))])
    }

    // C2: an older project renamed onto an existing name is renamed, not merged.
    @Test func sameNameFarApartGetsSuffixOnTheNewerUpdate() {
        let plan = ProjectConflictResolver.resolve([
            F.snapshot(1, F.project("Client", created: 0, updated: 1000)),
            F.snapshot(2, F.project("Client", created: 10 * 24 * 3600, updated: 5000)),
        ])
        #expect(plan.merges.isEmpty)
        #expect(plan.renames == [.init(syncId: F.uuid(2), newName: "Client (2)")])
    }

    @Test func suffixSkipsTakenNames() {
        let plan = ProjectConflictResolver.resolve([
            F.snapshot(1, F.project("Client", created: 0, updated: 10)),
            F.snapshot(2, F.project("Client", created: 9 * 24 * 3600, updated: 20)),
            F.snapshot(3, F.project("client (2)", created: 0, updated: 0)),
            F.snapshot(4, F.project("Client", created: 20 * 24 * 3600, updated: 30)),
        ])
        #expect(plan.renames == [.init(syncId: F.uuid(2), newName: "Client (3)"),
                                 .init(syncId: F.uuid(4), newName: "Client (4)")])
    }

    // C3: duplicate customId.
    @Test func duplicateCustomIdIsClearedOnTheLoser() {
        let plan = ProjectConflictResolver.resolve([
            F.snapshot(1, F.project("A", created: 0, updated: 10, customId: "ACME-1")),
            F.snapshot(2, F.project("B", created: 0, updated: 20, customId: "acme-1")),
            F.snapshot(3, F.project("C", created: 0, updated: 30, customId: nil)),
        ])
        #expect(plan.clearedCustomIds == [F.uuid(2)])
    }

    @Test func customIdOfMergedLoserDoesNotCount() {
        let plan = ProjectConflictResolver.resolve([
            F.snapshot(1, F.project("Same", created: 0, customId: "X")),
            F.snapshot(2, F.project("Same", created: 60, customId: "X")),
        ])
        #expect(plan.merges.count == 1)
        #expect(plan.clearedCustomIds.isEmpty)
    }

    @Test func consistentProjectsNeedNothing() {
        let plan = ProjectConflictResolver.resolve([
            F.snapshot(1, F.project("A", customId: "1")),
            F.snapshot(2, F.project("B", customId: "2")),
        ])
        #expect(plan.isEmpty)
    }

    @Test func orderOfInputDoesNotMatter() {
        let all = [
            F.snapshot(1, F.project("Client", created: 0, updated: 10, customId: "K")),
            F.snapshot(2, F.project("client", created: 100, updated: 20, customId: "K")),
            F.snapshot(3, F.project("Client", created: 9 * 24 * 3600, updated: 30, customId: "k")),
            F.snapshot(4, F.project("Other", created: 5, updated: 1, customId: "K")),
        ]
        let expected = ProjectConflictResolver.resolve(all)
        for seed in 0..<6 {
            var shuffled = all
            var generator = SeededGenerator(seed: UInt64(seed + 1))
            shuffled.shuffle(using: &generator)
            #expect(ProjectConflictResolver.resolve(shuffled) == expected)
        }
    }

    @Test func applyingThePlanLeavesNothingToDo() {
        let all = [
            F.snapshot(1, F.project("Client", created: 0, updated: 10, customId: "K")),
            F.snapshot(2, F.project("client", created: 100, updated: 20, customId: "K")),
            F.snapshot(3, F.project("Client", created: 9 * 24 * 3600, updated: 30, customId: "k")),
            F.snapshot(4, F.project("Client (2)", created: 5, updated: 1, customId: "K")),
        ]
        let plan = ProjectConflictResolver.resolve(all)
        var remaining = all.filter { snapshot in !plan.merges.contains { $0.loser == snapshot.syncId } }
        for index in remaining.indices {
            let id = remaining[index].syncId
            if let rename = plan.renames.first(where: { $0.syncId == id }) { remaining[index].fields.name = rename.newName }
            if plan.clearedCustomIds.contains(id) { remaining[index].fields.customId = nil }
        }
        #expect(!plan.isEmpty)
        #expect(ProjectConflictResolver.resolve(remaining).isEmpty)
    }
}

/// Deterministic shuffling for the order-independence tests.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
