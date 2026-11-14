import Foundation
import Testing
@testable import Timelane

@MainActor
struct SyncTwoDeviceTests {
    private func h(_ hours: Double) -> Date { SyncTestWorld.h(hours) }

    @Test func initialUploadSendsEverything() async throws {                    // A2
        let server = InMemorySyncServer()
        let a = try SyncTestDevice(server: server)
        let project = try await a.insertProject("Alpha", created: h(0))
        try await a.addEntry(project, from: h(9), to: h(10), at: h(0))
        try await a.service.enable(.replaceICloud)

        let outbox = try await a.outbox()
        #expect(a.service.isEnabled)
        #expect(server.records.count == 2)
        #expect(outbox.isEmpty)
        if case .idle = a.service.status {} else { Issue.record("expected idle, got \(a.service.status)") }
    }

    @Test func secondDeviceDownloadsEverything() async throws {                 // A1 "replace this device"
        let server = InMemorySyncServer()
        let a = try SyncTestDevice(server: server)
        let project = try await a.insertProject("Alpha", created: h(0))
        try await a.addEntry(project, from: h(9), to: h(10), at: h(0))
        try await a.service.enable(.replaceICloud)

        let b = try SyncTestDevice(server: server)
        try await b.insertProject("Local only", created: h(1))
        let remoteHasData = try await b.service.remoteHasData()
        #expect(remoteHasData)
        try await b.service.enable(.replaceLocal)

        let names = try await b.allProjects().map(\.name)
        let snapshotA = try await a.snapshot()
        let snapshotB = try await b.snapshot()
        let outbox = try await b.outbox()
        #expect(names == ["Alpha"])
        #expect(snapshotA == snapshotB)
        #expect(outbox.isEmpty)
        #expect(server.records.count == 2)      // "Local only" was never uploaded
    }

    @Test func newerLocalEditWinsAConflictOnSend() async throws {               // B1 (detected via serverRecordChanged)
        let (a, b, _) = try await SyncTestWorld.pair()
        let project = try await a.insertProject("Alpha", created: h(0))
        try await SyncTestDevice.syncAll([a, b])
        let remote = try #require(try await b.allProjects().first)

        try await a.updateProject(project, name: "Alpha A", updatedAt: h(300))
        try await b.updateProject(remote, colorHex: "#FF0000", updatedAt: h(200))
        await b.service.syncNow()
        try await a.sendWithoutFetching()               // conflicts with b's version, a's is newer
        try await SyncTestDevice.syncAll([a, b])

        let snapshotA = try await a.snapshot()
        let snapshotB = try await b.snapshot()
        let winner = try await b.allProjects()
        #expect(snapshotA == snapshotB)
        #expect(winner.map(\.name) == ["Alpha A"])
        #expect(winner.map(\.colorHex) == ["#4F8EF7"])  // the whole record comes from the newest writer (C5)
    }

    @Test func olderLocalEditLosesAConflictOnSend() async throws {              // B1
        let (a, b, _) = try await SyncTestWorld.pair()
        let project = try await a.insertProject("Alpha", created: h(0))
        try await SyncTestDevice.syncAll([a, b])
        let remote = try #require(try await b.allProjects().first)

        try await a.updateProject(project, name: "Alpha A", updatedAt: h(100))
        try await b.updateProject(remote, colorHex: "#FF0000", updatedAt: h(200))
        await b.service.syncNow()
        try await a.sendWithoutFetching()

        let outbox = try await a.outbox()
        let local = try await a.allProjects()
        #expect(outbox.isEmpty)                         // a adopted b's version, nothing left to send
        #expect(local.map(\.name) == ["Alpha"] && local.map(\.colorHex) == ["#FF0000"])
    }

    @Test func deleteWinsOverARemoteEdit() async throws {                       // B3
        let (a, b, _) = try await SyncTestWorld.pair()
        let project = try await a.insertProject("Alpha", created: h(0))
        try await a.addEntry(project, from: h(9), to: h(10), at: h(0))
        try await SyncTestDevice.syncAll([a, b])
        let onA = try #require(try await a.allEntries().first)
        var onB = try #require(try await b.allEntries().first)

        try await a.editor(at: h(10)).delete(onA)
        onB.title = "Edited"
        try await b.editor(at: h(11)).update(onB)
        try await SyncTestDevice.syncAll([a, b])

        let remaining = try await b.allEntries()
        let outbox = try await b.outbox()
        #expect(remaining.isEmpty)
        #expect(outbox.isEmpty)
        #expect(b.remoteChanges.all.contains(onB.id!))
    }

    @Test func pendingLocalDeleteIgnoresAnIncomingEdit() async throws {         // B3, other direction
        let (a, b, server) = try await SyncTestWorld.pair()
        let project = try await a.insertProject("Alpha", created: h(0))
        try await a.addEntry(project, from: h(9), to: h(10), at: h(0))
        try await SyncTestDevice.syncAll([a, b])
        let onA = try #require(try await a.allEntries().first)
        var onB = try #require(try await b.allEntries().first)

        try await a.editor(at: h(10)).delete(onA)
        onB.title = "Edited"
        try await b.editor(at: h(11)).update(onB)
        await b.service.syncNow()                        // the edit reaches the server first
        try await SyncTestDevice.syncAll([a, b])

        let entriesA = try await a.allEntries()
        let entriesB = try await b.allEntries()
        #expect(entriesA.isEmpty && entriesB.isEmpty)
        #expect(server.records.count == 1)               // only the project is left
    }

    @Test func deletedOnBothDevicesIsNotAConflict() async throws {              // B4
        let (a, b, _) = try await SyncTestWorld.pair()
        let project = try await a.insertProject("Alpha", created: h(0))
        try await a.addEntry(project, from: h(9), to: h(10), at: h(0))
        try await SyncTestDevice.syncAll([a, b])
        let onA = try #require(try await a.allEntries().first)
        let onB = try #require(try await b.allEntries().first)

        try await a.editor(at: h(10)).delete(onA)
        try await b.editor(at: h(10)).delete(onB)
        await a.service.syncNow()
        try await b.sendWithoutFetching()                // the server answers unknownItem: success

        let outbox = try await b.outbox()
        #expect(outbox.isEmpty)
        if case .error = b.service.status { Issue.record("unknownItem on a delete must not be an error") }
    }

    @Test func titleAndTimesEditedOnDifferentDevicesMerge() async throws {      // D3
        let (a, b, _) = try await SyncTestWorld.pair()
        let project = try await a.insertProject("Alpha", created: h(0))
        try await a.addEntry(project, from: h(9), to: h(10), at: h(0))
        try await SyncTestDevice.syncAll([a, b])
        var onA = try #require(try await a.allEntries().first)
        var onB = try #require(try await b.allEntries().first)

        onA.title = "Planning"
        try await a.editor(at: h(200)).update(onA)
        onB.end = h(10.5)
        try await b.editor(at: h(300)).update(onB)
        try await SyncTestDevice.syncAll([a, b])

        let finalA = try #require(try await a.allEntries().first)
        let finalB = try #require(try await b.allEntries().first)
        let snapshotA = try await a.snapshot()
        let snapshotB = try await b.snapshot()
        #expect(snapshotA == snapshotB)
        #expect(finalA.title == "Planning" && finalB.title == "Planning")
        #expect(finalA.end == h(10.5) && finalB.end == h(10.5))
    }

    @Test func signingOutTurnsSyncOffButKeepsLocalData() async throws {          // A5
        let (a, b, _) = try await SyncTestWorld.pair()
        try await a.insertProject("Alpha", created: h(0))
        try await SyncTestDevice.syncAll([a, b])

        await a.engine.emit(.accountChange(.signOut))

        let projects = try await a.allProjects()
        let enabled = try await a.store.state(.enabled)
        let outbox = try await a.outbox()
        #expect(!a.service.isEnabled && a.service.status == .off)
        #expect(a.service.notice != nil)
        #expect(projects.count == 1)
        #expect(enabled == nil && outbox.isEmpty)
    }

    @Test func turningSyncOffForgetsMetadataAndKeepsICloud() async throws {     // A4
        let (a, b, server) = try await SyncTestWorld.pair()
        try await a.insertProject("Alpha", created: h(0))
        try await SyncTestDevice.syncAll([a, b])

        await a.service.disable()

        let projects = try await a.allProjects()
        #expect(!a.service.isEnabled && a.service.notice == nil)
        #expect(projects.count == 1)
        #expect(server.records.count == 1)
    }

    @Test func offlineKeepsLocalWorkAndPausesTheStatus() async throws {         // E5
        let (a, b, server) = try await SyncTestWorld.pair()
        try await a.insertProject("Alpha", created: h(0))
        server.isOnline = false
        await a.service.syncNow()
        #expect(a.service.status == .paused(reason: "Waiting for network"))

        server.isOnline = true
        try await SyncTestDevice.syncAll([a, b])
        let names = try await b.allProjects().map(\.name)
        #expect(names == ["Alpha"])
        if case .idle = a.service.status {} else { Issue.record("expected idle after coming back online") }
    }
}
