import Foundation
import GRDB
import Testing
@testable import Timelane

@MainActor
struct GRDBSyncStoreTests {
    let device: SyncTestDevice

    init() throws { device = try SyncTestDevice(server: InMemorySyncServer()) }

    private func t(_ seconds: Double) -> Date { SyncFixtures.t(seconds) }
    private func hours(_ value: Double) -> Date { SyncFixtures.t(value * 3600) }
    private func batch(saves: [SyncRecord] = [], deletes: [SyncRecordID] = []) -> SyncInboundBatch {
        SyncInboundBatch(saves: saves.map { SyncServerRecord(record: $0, systemFields: Data([1])) }, deletes: deletes)
    }

    private func entryRecord(_ n: Int, project: Project, start: Double, end: Double, at: Double, title: String? = nil) -> SyncRecord {
        var fields = SyncFixtures.entry(start: start, end: end, at: at, title: title)
        fields.projectSyncId = project.syncId
        return SyncRecord(syncId: SyncFixtures.uuid(n), timeEntry: fields)
    }

    private func outboxIds() async throws -> [UUID] {
        try await device.outbox().map(\.id.syncId).sorted { $0.uuidString < $1.uuidString }
    }

    @Test func remoteChangesDoNotEnterTheOutbox() async throws {
        let project = SyncRecord(syncId: SyncFixtures.uuid(1), project: SyncFixtures.project("Alpha"))
        var fields = SyncFixtures.entry(start: 9, end: 10, project: 1)
        fields.projectSyncId = project.syncId
        let entry = SyncRecord(syncId: SyncFixtures.uuid(2), timeEntry: fields)

        _ = try await device.store.applyInbound(batch(saves: [project, entry]))

        let projects = try await device.allProjects()
        let entries = try await device.allEntries()
        let outbox = try await device.outbox()
        #expect(projects.count == 1 && entries.count == 1)
        #expect(outbox.isEmpty)
    }

    @Test func correctionsAfterABatchDoEnterTheOutbox() async throws {
        let project = try await device.insertProject("Alpha", created: t(0))
        try await device.addEntry(project, from: hours(10), to: hours(12), at: t(200))     // newer
        try await device.store.clearOutbox()

        _ = try await device.store.applyInbound(batch(saves: [entryRecord(2, project: project, start: 9, end: 11, at: 100)]))

        let entries = try await device.allEntries().sorted { $0.start < $1.start }
        let outbox = try await outboxIds()
        #expect(entries.map(\.start) == [hours(9), hours(10)] && entries.map(\.end) == [hours(10), hours(12)])
        #expect(outbox == [SyncFixtures.uuid(2)])     // only the trimmed (older) entry changed
    }

    @Test func remoteDeleteRemovesTheRowAndItsPendingSave() async throws {
        let project = try await device.insertProject("Alpha", created: t(0))
        try await device.addEntry(project, from: hours(9), to: hours(10), at: t(1))
        let entry = try #require(try await device.allEntries().first)
        let id = SyncRecordID(recordType: .timeEntry, syncId: entry.syncId)

        let result = try await device.store.applyInbound(batch(deletes: [id]))

        let entries = try await device.allEntries()
        let outbox = try await outboxIds()
        #expect(entries.isEmpty)
        #expect(!outbox.contains(entry.syncId))
        #expect(result.changedEntryIds == [entry.id!])
    }

    @Test func pendingLocalDeleteIgnoresAnIncomingSave() async throws {
        let project = try await device.insertProject("Alpha", created: t(0))
        try await device.addEntry(project, from: hours(9), to: hours(10), at: t(1))
        let entry = try #require(try await device.allEntries().first)
        try await device.editor(at: t(2)).delete(entry)
        var fields = SyncFixtures.entry(start: 9, end: 10, at: 50)
        fields.projectSyncId = project.syncId

        _ = try await device.store.applyInbound(batch(saves: [SyncRecord(syncId: entry.syncId, timeEntry: fields)]))

        let entries = try await device.allEntries()
        let outbox = try await device.outbox()
        #expect(entries.isEmpty)
        #expect(outbox.contains { $0.id.syncId == entry.syncId && $0.kind == .delete })
    }

    @Test func markSentKeepsAnEditMadeWhileSending() async throws {
        let project = try await device.insertProject("Alpha", created: t(0))
        let id = SyncRecordID(recordType: .project, syncId: project.syncId)
        let sent = try #require(try await device.store.uploadRecord(for: id))

        try await device.updateProject(project, name: "Alpha 2", updatedAt: t(5))
        let changedMeanwhile = try await device.store.markSent(SyncServerRecord(record: sent.record, systemFields: Data([9])))
        let stillQueued = try await device.outbox()
        #expect(changedMeanwhile)
        #expect(stillQueued.count == 1)

        let current = try #require(try await device.store.uploadRecord(for: id))
        let changedAgain = try await device.store.markSent(SyncServerRecord(record: current.record, systemFields: Data([10])))
        let queuedAfter = try await device.outbox()
        let stored = try await device.store.uploadRecord(for: id)
        #expect(!changedAgain)
        #expect(queuedAfter.isEmpty)
        #expect(stored == nil)                      // nothing pending any more
    }

    @Test func nothingIsUploadedForARecordWithAPendingDelete() async throws {
        let project = try await device.insertProject("Alpha", created: t(0))
        try await device.projects.delete(id: project.id!)
        let upload = try await device.store.uploadRecord(for: SyncRecordID(recordType: .project, syncId: project.syncId))
        #expect(upload == nil)
    }

    @Test func deletingAProjectLeavesATombstone() async throws {
        let project = try await device.insertProject("Alpha", created: t(0))
        try await device.projects.delete(id: project.id!)
        let count = try await device.database.writer.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM syncTombstone WHERE syncId = ?", arguments: [project.syncId.uuidString])
        }
        #expect(count == 1)
    }

    @Test func sameCustomIdKeepsItOnTheOlderProjectOnly() async throws {              // C3
        try await device.insertProject("One", created: t(0), customId: "X")
        let incoming = SyncRecord(syncId: SyncFixtures.uuid(5), project: SyncFixtures.project("Two", created: 10, customId: "X"))

        let result = try await device.store.applyInbound(batch(saves: [incoming]))

        let projects = try await device.allProjects()
        let outbox = try await outboxIds()
        #expect(projects.first { $0.name == "One" }?.customId == "X")
        #expect(projects.first { $0.name == "Two" }?.customId == nil)
        #expect(result.clearedCustomIdProjects == ["Two"])
        #expect(outbox.contains(SyncFixtures.uuid(5)))
    }

    @Test func sameNameFarApartGetsASuffix() async throws {                            // C2
        try await device.insertProject("Foo", created: t(0))
        let incoming = SyncRecord(syncId: SyncFixtures.uuid(5), project: SyncFixtures.project("Foo", created: 3 * 86_400))

        _ = try await device.store.applyInbound(batch(saves: [incoming]))

        let projects = try await device.allProjects()
        let renamed = projects.first { $0.syncId == SyncFixtures.uuid(5) }
        let outbox = try await outboxIds()
        #expect(Set(projects.map(\.name)) == ["Foo", "Foo (2)"])
        #expect(renamed?.name == "Foo (2)")
        #expect(outbox.contains(SyncFixtures.uuid(5)))
    }

    @Test func sameNameCloseTogetherIsMergedIntoTheOlderProject() async throws {        // C1
        let local = try await device.insertProject("Foo", created: t(0))
        let incoming = SyncRecord(syncId: SyncFixtures.uuid(5), project: SyncFixtures.project("foo", created: 60))
        var fields = SyncFixtures.entry(start: 9, end: 10)
        fields.projectSyncId = incoming.syncId
        let entry = SyncRecord(syncId: SyncFixtures.uuid(6), timeEntry: fields)

        _ = try await device.store.applyInbound(batch(saves: [incoming, entry]))

        let projects = try await device.allProjects()
        let entries = try await device.allEntries()
        #expect(projects.map(\.syncId) == [local.syncId])
        #expect(entries.count == 1 && entries[0].projectId == local.id)
    }

    @Test func wipingLocalDataKeepsTrackedAppsAndQueuesNothing() async throws {          // A1 "replace this device"
        let project = try await device.insertProject("Alpha", created: t(0))
        try await device.addEntry(project, from: hours(9), to: hours(10), at: t(1))
        try await device.database.writer.write { db in
            try db.execute(sql: "INSERT INTO trackedApp (bundleIdentifier, name, addedAt, projectId) VALUES ('x', 'X', 0, ?)",
                           arguments: [project.id])
        }

        let links = try await device.store.wipeLocalSyncedData()

        let projects = try await device.allProjects()
        let outbox = try await device.outbox()
        #expect(links == [SyncTrackedAppLink(bundleIdentifier: "x", projectName: "Alpha")])
        #expect(projects.isEmpty && outbox.isEmpty)

        let renamed = try await device.insertProject("alpha", created: t(5))
        try await device.store.relinkTrackedApps(links)
        let linked = try await device.database.writer.read { db in
            try Int64.fetchOne(db, sql: "SELECT projectId FROM trackedApp WHERE bundleIdentifier = 'x'")
        }
        #expect(linked == renamed.id)
    }
}
