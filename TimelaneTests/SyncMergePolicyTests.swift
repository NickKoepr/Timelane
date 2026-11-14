import Foundation
import Testing
@testable import Timelane

struct SyncMergePolicyTests {
    typealias F = SyncFixtures

    // B1 / C5: whole-project last writer wins.
    @Test func newerRemoteProjectWins() {
        let local = F.project("Old", created: 0, updated: 10)
        let remote = F.project("New", created: 0, updated: 20, archived: true)
        #expect(SyncMergePolicy.merge(local: local, remote: remote) == remote)
    }

    @Test func newerLocalProjectWins() {
        let local = F.project("Mine", created: 0, updated: 30)
        let remote = F.project("Theirs", created: 0, updated: 20)
        #expect(SyncMergePolicy.merge(local: local, remote: remote) == local)
    }

    @Test func missingLocalTakesRemote() {
        let remote = F.project("Theirs")
        #expect(SyncMergePolicy.merge(local: nil as ProjectFields?, remote: remote) == remote)
    }

    @Test func equalTimestampsPickTheSameWinnerOnBothSides() {
        let a = F.project("Alpha", created: 0, updated: 10)
        let b = F.project("Bravo", created: 0, updated: 10)
        #expect(SyncMergePolicy.merge(local: a, remote: b) == SyncMergePolicy.merge(local: b, remote: a))
    }

    // C5: archived on one device, renamed on the other: the newer one wins as a whole.
    @Test func archivedVersusRenamedIsNotMixed() {
        let archived = F.project("Same", created: 0, updated: 50, archived: true)
        let renamed = F.project("Renamed", created: 0, updated: 40)
        let merged = SyncMergePolicy.merge(local: renamed, remote: archived)
        #expect(merged.name == "Same")
        #expect(merged.isArchived)
    }

    // D3: title edit on one device, move on the other.
    @Test func fieldGroupsMergeIndependently() {
        var local = F.entry(start: 9, end: 10, at: 0)
        local.title = "Edited"
        local.textUpdatedAt = F.t(100)
        local.updatedAt = F.t(100)
        var remote = F.entry(start: 9, end: 10, at: 0)
        remote.start = F.t(11 * F.hour)
        remote.end = F.t(12 * F.hour)
        remote.timesUpdatedAt = F.t(200)
        remote.updatedAt = F.t(200)

        let merged = SyncMergePolicy.merge(local: local, remote: remote)
        #expect(merged.title == "Edited")
        #expect(merged.start == F.t(11 * F.hour))
        #expect(merged.end == F.t(12 * F.hour))
        #expect(merged.textUpdatedAt == F.t(100))
        #expect(merged.timesUpdatedAt == F.t(200))
        #expect(merged.updatedAt == F.t(200))
        #expect(merged == SyncMergePolicy.merge(local: remote, remote: local))
    }

    // D2: same entry resized on both devices: the newer times win.
    @Test func newerTimesWin() {
        var local = F.entry(start: 9, end: 10, at: 0)
        local.end = F.t(11 * F.hour)
        local.timesUpdatedAt = F.t(300)
        var remote = F.entry(start: 9, end: 10, at: 0)
        remote.end = F.t(12 * F.hour)
        remote.timesUpdatedAt = F.t(400)
        #expect(SyncMergePolicy.merge(local: local, remote: remote).end == F.t(12 * F.hour))
        #expect(SyncMergePolicy.merge(local: remote, remote: local).end == F.t(12 * F.hour))
    }

    @Test func projectGroupMergesSeparately() {
        var local = F.entry(start: 9, end: 10, at: 0, project: 1)
        local.projectSyncId = F.uuid(2)
        local.projectUpdatedAt = F.t(50)
        let remote = F.entry(start: 9, end: 10, at: 10, project: 1)
        let merged = SyncMergePolicy.merge(local: local, remote: remote)
        #expect(merged.projectSyncId == F.uuid(2))
        #expect(merged.timesUpdatedAt == F.t(10))
        #expect(merged.updatedAt == F.t(50))
    }

    @Test func equalGroupTimestampsAreDeterministic() {
        var a = F.entry(start: 9, end: 10, at: 5)
        a.title = "A"
        var b = F.entry(start: 9, end: 10, at: 5)
        b.title = "B"
        #expect(SyncMergePolicy.merge(local: a, remote: b) == SyncMergePolicy.merge(local: b, remote: a))
    }

    @Test func mergeIsIdempotent() {
        var a = F.entry(start: 9, end: 10, at: 0)
        a.title = "A"
        a.textUpdatedAt = F.t(9)
        let b = F.entry(start: 10, end: 11, at: 3)
        let once = SyncMergePolicy.merge(local: a, remote: b)
        #expect(SyncMergePolicy.merge(local: once, remote: b) == once)
        #expect(SyncMergePolicy.merge(local: once, remote: a) == once)
    }
}
