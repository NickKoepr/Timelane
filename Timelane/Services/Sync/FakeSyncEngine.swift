import Foundation
import os

/// An engine that talks to an `InMemorySyncServer` instead of CloudKit (tests, previews, screenshots).
/// Nothing happens in the background: changes are sent and fetched only when `sendChanges()` /
/// `fetchChanges()` are called, and the event handler is awaited, so tests are deterministic.
final class FakeSyncEngine: SyncEngineClient, @unchecked Sendable {
    typealias Handler = @Sendable (SyncEngineEvent) async -> Void
    typealias Provider = @Sendable (SyncRecordID) async -> SyncUploadRecord?

    private struct State {
        var handler: Handler?
        var provider: Provider?
        var started = false
        var token = 0
        var epoch = 0
        var pendingSaves: [SyncRecordID] = []
        var pendingDeletes: [SyncRecordID] = []
        var sentCount = 0
        var account = CloudAccountStatus.available
    }

    private struct Persisted: Codable {
        var token: Int
        var epoch: Int
    }

    let server: InMemorySyncServer
    private let clientID = UUID()
    private let state = OSAllocatedUnfairLock(initialState: State())

    init(server: InMemorySyncServer = InMemorySyncServer()) { self.server = server }

    // MARK: Test helpers

    var pendingSaveCount: Int { state.withLock { $0.pendingSaves.count } }
    var pendingDeleteCount: Int { state.withLock { $0.pendingDeletes.count } }
    /// Number of records and deletes sent to the server so far.
    var sentCount: Int { state.withLock { $0.sentCount } }
    var account: CloudAccountStatus {
        get { state.withLock { $0.account } }
        set { state.withLock { $0.account = newValue } }
    }

    /// Delivers an event as if the engine had produced it (account changes in tests).
    func emit(_ event: SyncEngineEvent) async {
        if let handler = state.withLock({ $0.handler }) { await handler(event) }
    }

    // MARK: SyncEngineClient

    func setEventHandler(_ handler: @escaping Handler) async { state.withLock { $0.handler = handler } }
    func setRecordProvider(_ provider: @escaping Provider) async { state.withLock { $0.provider = provider } }

    func start(stateSerialization: Data?) async throws {
        let persisted = stateSerialization.flatMap { try? JSONDecoder().decode(Persisted.self, from: $0) }
        state.withLock { state in
            state.started = true
            state.token = persisted?.token ?? 0
            state.epoch = persisted?.epoch ?? server.epoch
        }
    }

    func stop() async {
        state.withLock { state in
            state.started = false
            state.pendingSaves = []
            state.pendingDeletes = []
        }
    }

    func accountStatus() async throws -> CloudAccountStatus { account }

    func addPendingSaves(_ ids: [SyncRecordID]) async {
        state.withLock { state in
            for id in ids {
                state.pendingDeletes.removeAll { $0 == id }
                if !state.pendingSaves.contains(id) { state.pendingSaves.append(id) }
            }
        }
    }

    func addPendingDeletes(_ ids: [SyncRecordID]) async {
        state.withLock { state in
            for id in ids {
                state.pendingSaves.removeAll { $0 == id }
                if !state.pendingDeletes.contains(id) { state.pendingDeletes.append(id) }
            }
        }
    }

    func zoneHasRecords() async throws -> Bool {
        guard server.isOnline else { throw SyncEngineError.offline }
        return !server.records.isEmpty
    }

    func deleteZoneAndRecreate() async throws {
        guard server.isOnline else { throw SyncEngineError.offline }
        server.deleteZone()
        server.createZone()
        state.withLock { state in
            state.token = 0
            state.epoch = server.epoch
            state.pendingSaves = []
            state.pendingDeletes = []
        }
    }

    func fetchChanges() async throws {
        guard server.isOnline else { throw SyncEngineError.offline }
        let (token, epoch, handler) = state.withLock { ($0.token, $0.epoch, $0.handler) }
        guard let handler else { throw SyncEngineError.notStarted }
        if epoch != server.epoch {
            state.withLock { $0.epoch = server.epoch; $0.token = 0 }
            await handler(.zoneDeleted)
            return
        }
        let changes = server.changes(since: token, excluding: clientID)
        if !changes.saves.isEmpty || !changes.deletes.isEmpty {
            await handler(.fetched(saves: changes.saves, deletes: changes.deletes))
        }
        state.withLock { $0.token = changes.token }
        let persisted = Persisted(token: changes.token, epoch: changes.epoch)
        if let data = try? JSONEncoder().encode(persisted) { await handler(.stateUpdate(data)) }
    }

    func sendChanges() async throws {
        guard server.isOnline else { throw SyncEngineError.offline }
        let (saves, deletes, handler, provider) = state.withLock { ($0.pendingSaves, $0.pendingDeletes, $0.handler, $0.provider) }
        guard let handler, let provider else { throw SyncEngineError.notStarted }

        var saved: [SyncServerRecord] = []
        var deleted: [SyncRecordID] = []
        var failed: [SyncFailedSend] = []
        for id in saves {
            guard let upload = await provider(id) else {
                state.withLock { $0.pendingSaves.removeAll { $0 == id } }
                continue
            }
            let tag = upload.systemFields.flatMap(FakeSystemFields.decode)?.tag
            switch server.save(upload.record, tag: tag, client: clientID) {
            case .saved(let newTag):
                saved.append(SyncServerRecord(record: upload.record, systemFields: FakeSystemFields(tag: newTag).encoded))
            case .conflict(let serverRecord, let serverTag):
                let failure = SyncSendFailure.serverRecordChanged(server: serverRecord, systemFields: FakeSystemFields(tag: serverTag).encoded)
                failed.append(SyncFailedSend(id: id, isDelete: false, failure: failure))
            case .unknownItem:
                failed.append(SyncFailedSend(id: id, isDelete: false, failure: .unknownItem))
            case .zoneNotFound:
                failed.append(SyncFailedSend(id: id, isDelete: false, failure: .zoneNotFound))
            }
        }
        for id in deletes {
            if server.delete(id, client: clientID) {
                deleted.append(id)
            } else {
                failed.append(SyncFailedSend(id: id, isDelete: true, failure: .unknownItem))
            }
        }
        let sentNow = saved.count + deleted.count
        state.withLock { state in
            state.pendingSaves.removeAll { saves.contains($0) }
            state.pendingDeletes.removeAll { deletes.contains($0) }
            state.sentCount += sentNow
        }
        if !saved.isEmpty || !deleted.isEmpty || !failed.isEmpty {
            await handler(.sent(saved: saved, deleted: deleted, failed: failed))
        }
    }
}
