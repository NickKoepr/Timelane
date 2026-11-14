import Foundation
import Testing
@testable import Timelane

@MainActor
struct SyncOverlapTests {
    private func h(_ hours: Double) -> Date { SyncTestWorld.h(hours) }

    private func sortedEntries(_ device: SyncTestDevice) async throws -> [TimeEntry] {
        try await device.allEntries().sorted { $0.start < $1.start }
    }

    @Test func overlappingEntriesCreatedOfflineSettleIdentically() async throws {        // D1
        let (a, b, _) = try await SyncTestWorld.pair()
        let project = try await a.insertProject("Alpha", created: h(0))
        try await SyncTestDevice.syncAll([a, b])
        let onB = try #require(try await b.allProjects().first)

        try await a.addEntry(project, from: h(9), to: h(11), at: h(100), title: "first")
        try await b.addEntry(onB, from: h(10), to: h(12), at: h(200), title: "second")
        try await SyncTestDevice.syncAll([a, b])

        let entriesA = try await sortedEntries(a)
        let entriesB = try await sortedEntries(b)
        let snapshotA = try await a.snapshot()
        let snapshotB = try await b.snapshot()
        #expect(snapshotA == snapshotB)
        // The newest action wins the overlap; the older entry is trimmed.
        #expect(entriesA.map(\.title) == ["first", "second"] && entriesB.map(\.title) == ["first", "second"])
        #expect(entriesA.map(\.start) == [h(9), h(10)] && entriesA.map(\.end) == [h(10), h(12)])

        // Settled: another round sends nothing.
        let sentBefore = a.engine.sentCount + b.engine.sentCount
        await a.service.syncNow()
        await b.service.syncNow()
        let outboxA = try await a.outbox()
        let outboxB = try await b.outbox()
        #expect(a.engine.sentCount + b.engine.sentCount == sentBefore)
        #expect(outboxA.isEmpty && outboxB.isEmpty)
    }

    @Test func anEntryWithAnotherInItsMiddleIsSplitTheSameWayOnBothDevices() async throws {   // D1 (split)
        let (a, b, _) = try await SyncTestWorld.pair()
        let project = try await a.insertProject("Alpha", created: h(0))
        try await SyncTestDevice.syncAll([a, b])
        let onB = try #require(try await b.allProjects().first)

        try await a.addEntry(project, from: h(9), to: h(13), at: h(100), title: "long")
        try await b.addEntry(onB, from: h(10), to: h(11), at: h(200), title: "short")
        try await SyncTestDevice.syncAll([a, b])

        let entriesA = try await sortedEntries(a)
        let entriesB = try await sortedEntries(b)
        let snapshotA = try await a.snapshot()
        let snapshotB = try await b.snapshot()
        #expect(snapshotA == snapshotB)
        #expect(entriesA.count == 3 && entriesB.count == 3)
        #expect(entriesA.map(\.start) == [h(9), h(10), h(11)] && entriesA.map(\.end) == [h(10), h(11), h(13)])
        #expect(Set(entriesA.map(\.syncId)) == Set(entriesB.map(\.syncId)))
    }

    @Test func remoteChangesDropTheUndoHistory() async throws {                          // E1
        let (a, b, _) = try await SyncTestWorld.pair()
        let project = try await a.insertProject("Alpha", created: h(0))
        try await a.addEntry(project, from: h(9), to: h(10), at: h(1), recordingHistory: true)
        try await SyncTestDevice.syncAll([a, b])
        #expect(a.history.canUndo)

        var onB = try #require(try await b.allEntries().first)
        onB.title = "Edited elsewhere"
        try await b.editor(at: h(50)).update(onB)
        try await SyncTestDevice.syncAll([a, b])

        let onA = try #require(try await a.allEntries().first)
        #expect(onA.title == "Edited elsewhere")
        #expect(!a.history.canUndo)
        #expect(a.remoteChanges.all.contains(onA.id!))
    }

    @Test func remoteChangesToOtherEntriesKeepTheUndoHistory() async throws {            // E1
        let (a, b, _) = try await SyncTestWorld.pair()
        let project = try await a.insertProject("Alpha", created: h(0))
        try await a.addEntry(project, from: h(9), to: h(10), at: h(1), recordingHistory: true)
        try await SyncTestDevice.syncAll([a, b])

        let onB = try #require(try await b.allProjects().first)
        try await b.addEntry(onB, from: h(14), to: h(15), at: h(50))
        try await SyncTestDevice.syncAll([a, b])

        #expect(a.history.canUndo)
    }

    @Test func recordFromANewerAppVersionIsParkedNotApplied() async throws {             // E4
        let (_, b, server) = try await SyncTestWorld.pair()
        var fields = SyncFixtures.project("From the future")
        fields.schemaVersion = SyncFields.currentSchemaVersion + 1
        server.put(SyncRecord(syncId: SyncFixtures.uuid(7), project: fields))

        await b.service.syncNow()

        let parked = try await b.store.parkedRecords()
        let projects = try await b.allProjects()
        #expect(projects.isEmpty)
        #expect(parked.count == 1 && parked[0].reason == SyncParkReason.newerApp)
        #expect(b.service.status == .needsAppUpdate)
    }
}
