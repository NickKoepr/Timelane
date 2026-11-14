import Foundation
import GRDB
@testable import Timelane

@MainActor
final class RemoteChangeLog {
    var batches: [Set<Int64>] = []
    var all: Set<Int64> { batches.reduce(into: Set<Int64>()) { $0.formUnion($1) } }
}

/// One "Mac" in a two-device test: its own in-memory database, sync service and fake engine, all talking
/// to the `InMemorySyncServer` the devices share. Sync never runs by itself; tests call `syncNow()`.
@MainActor
final class SyncTestDevice {
    let database: AppDatabase
    let store: GRDBSyncStore
    let engine: FakeSyncEngine
    let service: SyncService
    let projects: GRDBProjectRepository
    let entries: GRDBTimeEntryRepository
    let history: TimeEntryHistory
    let remoteChanges: RemoteChangeLog

    init(server: InMemorySyncServer) throws {
        let database = try AppDatabase.inMemory()
        let entries = GRDBTimeEntryRepository(database: database)
        let history = TimeEntryHistory(repository: entries)
        let log = RemoteChangeLog()
        let store = GRDBSyncStore(database: database)
        let engine = FakeSyncEngine(server: server)
        self.database = database
        self.store = store
        self.engine = engine
        self.entries = entries
        self.history = history
        self.remoteChanges = log
        self.projects = GRDBProjectRepository(database: database)
        self.service = SyncService(store: store, engine: engine, isolated: false, forwardDelay: .zero,
                                   onRemoteEntryChanges: { ids in
                                       log.batches.append(ids)
                                       history.invalidate(touching: ids)
                                   })
    }

    // MARK: Writing (the way the app does it, with chosen timestamps)

    @discardableResult
    func insertProject(_ name: String, created: Date, updated: Date? = nil, customId: String? = nil) async throws -> Project {
        try await database.writer.write { db in
            var project = Project(name: name, colorHex: "#4F8EF7", createdAt: created, customId: customId, updatedAt: updated ?? created)
            try project.insert(db)
            return project
        }
    }

    func updateProject(_ project: Project, name: String? = nil, colorHex: String? = nil, updatedAt: Date) async throws {
        let name = name ?? project.name
        let color = colorHex ?? project.colorHex
        try await database.writer.write { db in
            try db.execute(sql: "UPDATE project SET name = ?, colorHex = ?, updatedAt = ? WHERE syncId = ?",
                           arguments: [name, color, updatedAt.timeIntervalSince1970, project.syncId.uuidString])
        }
    }

    func editor(at now: Date, recordingHistory: Bool = false) -> TimeEntryEditor {
        let history = self.history
        if recordingHistory {
            return TimeEntryEditor(repository: entries, now: { now }, onChange: { await history.record($0) })
        }
        return TimeEntryEditor(repository: entries, now: { now })
    }

    func addEntry(_ project: Project, from start: Date, to end: Date, at now: Date, title: String? = nil,
                  recordingHistory: Bool = false) async throws {
        try await editor(at: now, recordingHistory: recordingHistory)
            .create(projectId: project.id!, range: DateRange(start: start, end: end), title: title, note: nil)
    }

    // MARK: Reading

    func allProjects() async throws -> [Project] {
        try await projects.projects(includeArchived: true)
    }

    func allEntries() async throws -> [TimeEntry] {
        try await entries.entries(in: DateRange(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 4_000_000_000)))
    }

    /// Every synced record, ordered by `syncId`: two converged devices have equal snapshots.
    func snapshot() async throws -> [SyncRecord] {
        try await store.allRecords().sorted { $0.syncId.uuidString < $1.syncId.uuidString }
    }

    func outbox() async throws -> [SyncOutboxItem] {
        try await store.pendingOutbox()
    }

    /// Sends the pending changes right now, without fetching first (simulates another device writing in between).
    func sendWithoutFetching() async throws {
        let pending = try await store.pendingOutbox()
        await service.forward(pending)
        try await engine.sendChanges()
    }

    /// Runs `syncNow` on all devices until a whole round sends nothing and every outbox is empty.
    static func syncAll(_ devices: [SyncTestDevice]) async throws {
        for _ in 0..<10 {
            let before = devices.map(\.engine.sentCount)
            for device in devices { await device.service.syncNow() }
            var quiet = before == devices.map(\.engine.sentCount)
            for device in devices {
                let pending = try await device.store.pendingOutbox()
                if !pending.isEmpty { quiet = false }
            }
            if quiet { return }
        }
    }
}

/// Shared setup for the two-device tests.
@MainActor
enum SyncTestWorld {
    /// `hours` after the fixture epoch.
    static func h(_ hours: Double) -> Date { SyncFixtures.t(hours * 3600) }

    /// Two devices with sync on and nothing stored anywhere yet.
    static func pair() async throws -> (a: SyncTestDevice, b: SyncTestDevice, server: InMemorySyncServer) {
        let server = InMemorySyncServer()
        let a = try SyncTestDevice(server: server)
        let b = try SyncTestDevice(server: server)
        try await a.service.enable(.replaceICloud)
        try await b.service.enable(.replaceLocal)
        return (a, b, server)
    }
}
