import Foundation
import os

/// A fake iCloud zone for tests and previews, shared by one or more `FakeSyncEngine`s.
///
/// Every record carries a change tag that grows with each change. Saving with a missing or stale tag for a
/// record that exists is a conflict (`serverRecordChanged`), like CloudKit.
final class InMemorySyncServer: @unchecked Sendable {
    enum SaveOutcome: Equatable {
        case saved(tag: Int)
        case conflict(server: SyncRecord, tag: Int)
        case unknownItem
        case zoneNotFound
    }

    struct Changes {
        var saves: [SyncServerRecord] = []
        var deletes: [SyncRecordID] = []
        var token: Int
        var epoch: Int
    }

    private struct Stored {
        var record: SyncRecord
        var tag: Int
        var writer: UUID
    }

    private struct Deletion {
        var version: Int
        var id: SyncRecordID
        var writer: UUID
    }

    private struct State {
        var records: [SyncRecordID: Stored] = [:]
        var deletions: [Deletion] = []
        var version = 0
        var epoch = 0
        var zoneExists = true
        var isOnline = true
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    init() {}

    /// When false, every engine call throws `SyncEngineError.offline`.
    var isOnline: Bool {
        get { state.withLock { $0.isOnline } }
        set { state.withLock { $0.isOnline = newValue } }
    }

    var records: [SyncRecord] {
        state.withLock { $0.records.values.map(\.record).sorted { $0.syncId.uuidString < $1.syncId.uuidString } }
    }

    var epoch: Int { state.withLock { $0.epoch } }
    var zoneExists: Bool { state.withLock { $0.zoneExists } }

    func record(_ id: SyncRecordID) -> SyncRecord? { state.withLock { $0.records[id]?.record } }

    /// Puts a record on the server as if another client had saved it (tests).
    func put(_ record: SyncRecord) {
        _ = save(record, tag: state.withLock { $0.records[record.id]?.tag }, client: UUID())
    }

    func save(_ record: SyncRecord, tag: Int?, client: UUID) -> SaveOutcome {
        state.withLock { state in
            guard state.zoneExists else { return .zoneNotFound }
            if let existing = state.records[record.id] {
                guard tag == existing.tag else { return .conflict(server: existing.record, tag: existing.tag) }
            } else if tag != nil {
                return .unknownItem
            }
            state.version += 1
            state.records[record.id] = Stored(record: record, tag: state.version, writer: client)
            return .saved(tag: state.version)
        }
    }

    /// Returns false when the record does not exist (CloudKit: `unknownItem`).
    @discardableResult
    func delete(_ id: SyncRecordID, client: UUID) -> Bool {
        state.withLock { state in
            guard state.records.removeValue(forKey: id) != nil else { return false }
            state.version += 1
            state.deletions.append(Deletion(version: state.version, id: id, writer: client))
            return true
        }
    }

    func serverRecord(_ id: SyncRecordID) -> (record: SyncRecord, tag: Int)? {
        state.withLock { state in state.records[id].map { ($0.record, $0.tag) } }
    }

    /// What changed after `token`, except the client's own writes.
    func changes(since token: Int, excluding client: UUID) -> Changes {
        state.withLock { state in
            var changes = Changes(token: state.version, epoch: state.epoch)
            for stored in state.records.values where stored.tag > token && stored.writer != client {
                changes.saves.append(SyncServerRecord(record: stored.record, systemFields: FakeSystemFields(tag: stored.tag).encoded))
            }
            changes.saves.sort { $0.record.syncId.uuidString < $1.record.syncId.uuidString }
            changes.deletes = state.deletions
                .filter { $0.version > token && $0.writer != client && state.records[$0.id] == nil }.map(\.id)
            return changes
        }
    }

    func deleteZone() {
        state.withLock { state in
            state.records = [:]
            state.deletions = []
            state.zoneExists = false
            state.epoch += 1
        }
    }

    func createZone() { state.withLock { $0.zoneExists = true } }
}

/// The fake's stand-in for the opaque CloudKit system fields: just the change tag.
struct FakeSystemFields: Codable, Equatable {
    var tag: Int

    var encoded: Data { (try? JSONEncoder().encode(self)) ?? Data() }

    static func decode(_ data: Data) -> FakeSystemFields? { try? JSONDecoder().decode(FakeSystemFields.self, from: data) }
}
