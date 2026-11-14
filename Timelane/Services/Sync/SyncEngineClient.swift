import Foundation

/// What `SyncService` needs from the sync engine. Implemented by `CloudKitSyncEngine` (live) and
/// `FakeSyncEngine` (tests, previews). Events arrive through an async handler that the engine awaits,
/// so when `fetchChanges()`/`sendChanges()` return, every event has been processed.
protocol SyncEngineClient: AnyObject, Sendable {
    func setEventHandler(_ handler: @escaping @Sendable (SyncEngineEvent) async -> Void) async
    /// Called when the engine is about to upload a record: the current local version, or nil if there is nothing to send.
    func setRecordProvider(_ provider: @escaping @Sendable (SyncRecordID) async -> SyncUploadRecord?) async

    func start(stateSerialization: Data?) async throws
    func stop() async
    func accountStatus() async throws -> CloudAccountStatus

    func addPendingSaves(_ ids: [SyncRecordID]) async
    func addPendingDeletes(_ ids: [SyncRecordID]) async
    func fetchChanges() async throws
    func sendChanges() async throws

    /// Deletes the zone with everything in it and creates it again (A1 "replace iCloud").
    func deleteZoneAndRecreate() async throws
    /// Whether iCloud holds any synced record.
    func zoneHasRecords() async throws -> Bool
}
