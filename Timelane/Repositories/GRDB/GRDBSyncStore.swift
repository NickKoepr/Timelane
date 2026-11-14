import Foundation
import GRDB

/// The SQLite side of iCloud sync (see `SyncStore`).
///
/// Local changes are captured by triggers into `syncOutbox` (schema v5). A project delete additionally
/// leaves a tombstone copy, written by `GRDBProjectRepository.delete` (the only local project delete
/// path), so a project that another device still adds entries to can be brought back (C4).
struct GRDBSyncStore: SyncStore {
    let database: AppDatabase

    // MARK: Small state

    func state(_ key: SyncStateKey) async throws -> Data? {
        try await database.writer.read { db in
            try Data.fetchOne(db, sql: "SELECT value FROM syncState WHERE key = ?", arguments: [key.rawValue])
        }
    }

    func setState(_ key: SyncStateKey, _ value: Data?) async throws {
        try await database.writer.write { db in
            if let value {
                try db.execute(sql: "INSERT OR REPLACE INTO syncState (key, value) VALUES (?, ?)", arguments: [key.rawValue, value])
            } else {
                try db.execute(sql: "DELETE FROM syncState WHERE key = ?", arguments: [key.rawValue])
            }
        }
    }

    // MARK: Outbox

    func pendingOutbox() async throws -> [SyncOutboxItem] {
        try await database.writer.read { db in try SyncRows.outbox(db) }
    }

    func observeOutbox() -> AsyncStream<[SyncOutboxItem]> {
        database.stream { db in try SyncRows.outbox(db) }
    }

    func clearOutbox() async throws {
        try await database.writer.write { db in try db.execute(sql: "DELETE FROM syncOutbox") }
    }

    func queueSaves(_ ids: [SyncRecordID]) async throws {
        try await database.writer.write { db in
            for id in ids { try SyncRows.queueSave(db, id) }
        }
    }

    // MARK: Uploading

    func uploadRecord(for id: SyncRecordID) async throws -> SyncUploadRecord? {
        try await database.writer.read { db -> SyncUploadRecord? in
            guard try SyncRows.outboxKind(db, id) == .save, let record = try SyncRows.record(db, id: id) else { return nil }
            return SyncUploadRecord(record: record, systemFields: try SyncRows.systemFields(db, id))
        }
    }

    func markSent(_ sent: SyncServerRecord) async throws -> Bool {
        try await database.writer.write { db in
            let id = sent.record.id
            try SyncRows.setSystemFields(db, id, sent.systemFields)
            // Only a record that still equals what was sent is clean; an edit made meanwhile stays queued.
            if let current = try SyncRows.record(db, id: id), current != sent.record { return true }
            try SyncRows.removeOutbox(db, id, kind: .save)
            return false
        }
    }

    func markDeleted(_ id: SyncRecordID) async throws -> Bool {
        try await database.writer.write { db in
            try SyncRows.removeOutbox(db, id, kind: .delete)
            try SyncRows.setSystemFields(db, id, nil)
            try SyncRows.removeTombstone(db, id)
            return try SyncRows.outboxKind(db, id) == .save
        }
    }

    func clearSystemFields(for id: SyncRecordID) async throws {
        try await database.writer.write { db in try SyncRows.setSystemFields(db, id, nil) }
    }

    func clearAllSystemFields() async throws {
        try await database.writer.write { db in try db.execute(sql: "DELETE FROM syncRecordMeta") }
    }

    // MARK: Downloading

    func applyInbound(_ batch: SyncInboundBatch) async throws -> SyncApplyResult {
        try await database.writer.write { db in
            try SyncInboundApplier(db: db).run(batch)
        }
    }
}
