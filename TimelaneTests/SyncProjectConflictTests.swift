import Foundation
import Testing
@testable import Timelane

@MainActor
struct SyncProjectConflictTests {
    private func h(_ hours: Double) -> Date { SyncTestWorld.h(hours) }

    @Test func sameNameCreatedOnTwoDevicesIsMerged() async throws {              // C1
        let (a, b, _) = try await SyncTestWorld.pair()
        let onA = try await a.insertProject("Foo", created: h(0))
        let onB = try await b.insertProject("foo", created: h(0.5))
        try await a.addEntry(onA, from: h(9), to: h(10), at: h(1))
        try await b.addEntry(onB, from: h(11), to: h(12), at: h(1))
        try await b.database.writer.write { db in
            try db.execute(sql: "INSERT INTO trackedApp (bundleIdentifier, name, addedAt, projectId) VALUES ('x', 'X', 0, ?)",
                           arguments: [onB.id])
        }

        try await SyncTestDevice.syncAll([a, b])

        let projectsA = try await a.allProjects()
        let projectsB = try await b.allProjects()
        let entriesA = try await a.allEntries()
        let entriesB = try await b.allEntries()
        let snapshotA = try await a.snapshot()
        let snapshotB = try await b.snapshot()
        #expect(snapshotA == snapshotB)
        #expect(projectsA.map(\.name) == ["Foo"] && projectsB.map(\.name) == ["Foo"])
        #expect(projectsA[0].syncId == onA.syncId)                 // the oldest project survives
        #expect(entriesA.count == 2 && entriesA.allSatisfy { $0.projectId == projectsA[0].id })
        #expect(entriesB.count == 2 && entriesB.allSatisfy { $0.projectId == projectsB[0].id })

        // Tracked-app links of the merged-away project follow the survivor.
        let linked = try await b.database.writer.read { db in
            try Int64.fetchOne(db, sql: "SELECT projectId FROM trackedApp WHERE bundleIdentifier = 'x'")
        }
        #expect(linked == projectsB[0].id)
    }

    @Test func convergedDevicesProduceNoFurtherUploads() async throws {          // C1 + "no endless re-upload"
        let (a, b, server) = try await SyncTestWorld.pair()
        let onA = try await a.insertProject("Foo", created: h(0))
        let onB = try await b.insertProject("Foo", created: h(0.5))
        try await a.addEntry(onA, from: h(9), to: h(10), at: h(1))
        try await b.addEntry(onB, from: h(11), to: h(12), at: h(1))
        try await SyncTestDevice.syncAll([a, b])

        let sentBefore = a.engine.sentCount + b.engine.sentCount
        await a.service.syncNow()
        await b.service.syncNow()
        let outboxA = try await a.outbox()
        let outboxB = try await b.outbox()
        #expect(a.engine.sentCount + b.engine.sentCount == sentBefore)
        #expect(outboxA.isEmpty && outboxB.isEmpty)
        #expect(server.records.count == 3)                         // one project, two entries
    }

    @Test func projectDeletedHereWhileOtherDeviceAddedAnEntryComesBack() async throws {   // C4, delete synced first
        let (a, b, _) = try await SyncTestWorld.pair()
        let onA = try await a.insertProject("Alpha", created: h(0))
        try await SyncTestDevice.syncAll([a, b])
        let onB = try #require(try await b.allProjects().first)

        try await a.projects.delete(id: onA.id!)
        try await b.addEntry(onB, from: h(9), to: h(10), at: h(1))
        await a.service.syncNow()                    // the delete reaches the server
        try await SyncTestDevice.syncAll([a, b])     // b keeps its project (an entry uses it) and uploads it again

        let projectsA = try await a.allProjects()
        let entriesA = try await a.allEntries()
        let snapshotA = try await a.snapshot()
        let snapshotB = try await b.snapshot()
        #expect(projectsA.map(\.syncId) == [onA.syncId])
        #expect(entriesA.count == 1)
        #expect(snapshotA == snapshotB)
    }

    @Test func projectDeletedHereIsRestoredFromItsTombstone() async throws {     // C4, entry synced first
        let (a, b, _) = try await SyncTestWorld.pair()
        let onA = try await a.insertProject("Alpha", created: h(0), customId: "ACME")
        try await SyncTestDevice.syncAll([a, b])
        let onB = try #require(try await b.allProjects().first)

        try await a.projects.delete(id: onA.id!)
        try await b.addEntry(onB, from: h(9), to: h(10), at: h(1))
        await b.service.syncNow()                    // the entry reaches the server before a's delete does
        try await SyncTestDevice.syncAll([a, b])

        let projectsA = try await a.allProjects()
        let entriesA = try await a.allEntries()
        let snapshotA = try await a.snapshot()
        let snapshotB = try await b.snapshot()
        #expect(projectsA.map(\.syncId) == [onA.syncId])
        #expect(projectsA.first?.customId == "ACME")  // restored from the tombstone copy
        #expect(entriesA.count == 1)
        #expect(snapshotA == snapshotB)
    }

    @Test func entryBeforeItsProjectWaitsInTheParkedTable() async throws {       // D4
        let (a, b, server) = try await SyncTestWorld.pair()
        let project = SyncRecord(syncId: SyncFixtures.uuid(1), project: SyncFixtures.project("Alpha"))
        let entry = SyncRecord(syncId: SyncFixtures.uuid(2), timeEntry: SyncFixtures.entry(start: 9, end: 10, project: 1))
        server.put(entry)
        await b.service.syncNow()

        let parked = try await b.store.parkedRecords()
        let entriesBefore = try await b.allEntries()
        #expect(parked.count == 1 && parked[0].reason == SyncParkReason.missingProject)
        #expect(entriesBefore.isEmpty)

        server.put(project)
        await b.service.syncNow()

        let parkedAfter = try await b.store.parkedRecords()
        let entriesAfter = try await b.allEntries()
        let outbox = try await b.outbox()
        #expect(parkedAfter.isEmpty && entriesAfter.count == 1)
        #expect(outbox.isEmpty)
        _ = a
    }
}
