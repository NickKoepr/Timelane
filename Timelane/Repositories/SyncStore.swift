import Foundation

/// Everything `SyncService` needs from the local database: the outbox, the stored system fields, the
/// engine state, parked records, and the transaction that applies server changes. GRDB stays behind it.
protocol SyncStore: Sendable {
    // MARK: Small state
    func state(_ key: SyncStateKey) async throws -> Data?
    func setState(_ key: SyncStateKey, _ value: Data?) async throws

    // MARK: Outbox
    func pendingOutbox() async throws -> [SyncOutboxItem]
    /// Emits the whole outbox after every change of it.
    func observeOutbox() -> AsyncStream<[SyncOutboxItem]>
    func clearOutbox() async throws
    /// Marks these records as changed locally (used for the full upload).
    func queueSaves(_ ids: [SyncRecordID]) async throws

    // MARK: Uploading
    /// The current local version of a record with a pending save, plus its stored system fields.
    /// Nil when there is nothing to send (row gone, or a delete is pending).
    func uploadRecord(for id: SyncRecordID) async throws -> SyncUploadRecord?
    /// Stores the new system fields. Returns true when the record changed locally after it was sent (send it again).
    func markSent(_ sent: SyncServerRecord) async throws -> Bool
    /// The server confirmed a delete. Returns true when a newer local save for the same record is pending.
    func markDeleted(_ id: SyncRecordID) async throws -> Bool
    func clearSystemFields(for id: SyncRecordID) async throws
    func clearAllSystemFields() async throws

    // MARK: Downloading
    func applyInbound(_ batch: SyncInboundBatch) async throws -> SyncApplyResult

    // MARK: Whole-database operations
    /// Every local project and time entry (projects first).
    func allRecords() async throws -> [SyncRecord]
    func hasSyncedData() async throws -> Bool
    func parkedRecords() async throws -> [SyncParkedRecord]
    /// Engine state, system fields, outbox, parked records, tombstones. Local data stays.
    func wipeSyncMetadata() async throws
    /// Deletes every project and time entry without queueing deletes. Returns the tracked-app links by project name.
    func wipeLocalSyncedData() async throws -> [SyncTrackedAppLink]
    func relinkTrackedApps(_ links: [SyncTrackedAppLink]) async throws
}
