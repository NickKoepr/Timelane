import CloudKit
import Foundation
import os

/// The live engine: wraps `CKSyncEngine` on the private database, zone `Timelane`.
///
/// This is the only sync file that imports CloudKit. The `CKContainer` is created on first use, never at
/// init: without the iCloud entitlement (unit tests, ad-hoc CI builds) creating one crashes.
/// `CKSyncEngine` schedules its own fetches and sends (push notifications, network changes); the
/// service additionally calls `fetchChanges`/`sendChanges` for "Sync now" and when the app becomes active.
final class CloudKitSyncEngine: SyncEngineClient, CKSyncEngineDelegate, @unchecked Sendable {
    typealias Handler = @Sendable (SyncEngineEvent) async -> Void
    typealias Provider = @Sendable (SyncRecordID) async -> SyncUploadRecord?

    nonisolated(unsafe) static let zoneID = CKRecordZone.ID(zoneName: "Timelane")
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Timelane", category: "sync-engine")

    struct Storage {
        var container: CKContainer?
        var engine: CKSyncEngine?
        var handler: Handler?
        var provider: Provider?
        /// The values handed to CloudKit, so `.sent` reports exactly what was sent (not CloudKit's re-rounded copy).
        var inFlight: [CKRecord.ID: SyncRecord] = [:]
        /// Record types of queued deletes (a `CKRecord.ID` carries no type).
        var deleteTypes: [UUID: SyncRecordType] = [:]
    }

    private let lock = NSLock()
    private var storage = Storage()

    init() {}

    func locked<T>(_ body: (inout Storage) -> T) -> T {
        lock.withLock { body(&storage) }
    }

    var container: CKContainer {
        locked { storage in
            if let existing = storage.container { return existing }
            let created = CKContainer(identifier: CloudKitBackupStore.containerIdentifier)
            storage.container = created
            return created
        }
    }

    // MARK: SyncEngineClient

    func setEventHandler(_ handler: @escaping Handler) async { locked { $0.handler = handler } }
    func setRecordProvider(_ provider: @escaping Provider) async { locked { $0.provider = provider } }

    func start(stateSerialization: Data?) async throws {
        let serialization = stateSerialization.flatMap { try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0) }
        makeEngine(serialization)
    }

    func stop() async {
        locked { storage in
            storage.engine = nil
            storage.inFlight = [:]
            storage.deleteTypes = [:]
        }
    }

    func accountStatus() async throws -> CloudAccountStatus {
        switch try await container.accountStatus() {
        case .available: .available
        case .noAccount: .noAccount
        case .restricted: .restricted
        case .temporarilyUnavailable: .temporarilyUnavailable
        case .couldNotDetermine: .couldNotDetermine
        @unknown default: .couldNotDetermine
        }
    }

    func addPendingSaves(_ ids: [SyncRecordID]) async {
        guard let engine = locked({ $0.engine }) else { return }
        engine.state.add(pendingRecordZoneChanges: ids.map { .saveRecord(Self.recordID(for: $0)) })
    }

    func addPendingDeletes(_ ids: [SyncRecordID]) async {
        guard let engine = locked({ $0.engine }) else { return }
        locked { storage in for id in ids { storage.deleteTypes[id.syncId] = id.recordType } }
        engine.state.add(pendingRecordZoneChanges: ids.map { .deleteRecord(Self.recordID(for: $0)) })
    }

    func fetchChanges() async throws {
        guard let engine = locked({ $0.engine }) else { throw SyncEngineError.notStarted }
        do { try await engine.fetchChanges() } catch { throw Self.mapped(error) }
    }

    func sendChanges() async throws {
        guard let engine = locked({ $0.engine }) else { throw SyncEngineError.notStarted }
        do { try await engine.sendChanges() } catch { throw Self.mapped(error) }
    }

    func deleteZoneAndRecreate() async throws {
        do {
            _ = try await container.privateCloudDatabase.deleteRecordZone(withID: Self.zoneID)
        } catch let error as CKError where error.code == .zoneNotFound {
            // Nothing to delete.
        } catch {
            throw Self.mapped(error)
        }
        locked { storage in
            storage.inFlight = [:]
            storage.deleteTypes = [:]
        }
        // A fresh engine without state: its pending zone save re-creates the zone on the next send.
        makeEngine(nil)
    }

    func zoneHasRecords() async throws -> Bool {
        do {
            let result = try await container.privateCloudDatabase.recordZoneChanges(
                inZoneWith: Self.zoneID, since: nil, desiredKeys: [], resultsLimit: 1)
            return !result.modificationResultsByID.isEmpty
        } catch let error as CKError where error.code == .zoneNotFound {
            return false
        } catch {
            throw Self.mapped(error)
        }
    }

    // MARK: Engine

    private func makeEngine(_ serialization: CKSyncEngine.State.Serialization?) {
        var configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase, stateSerialization: serialization, delegate: self)
        configuration.automaticallySync = true
        let engine = CKSyncEngine(configuration)
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
        locked { $0.engine = engine }
    }

    static func mapped(_ error: Error) -> SyncEngineError {
        guard let ckError = error as? CKError else { return .other(error.localizedDescription) }
        switch ckError.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return .offline
        case .quotaExceeded:
            return .quotaExceeded
        case .notAuthenticated:
            return .other("Sign in to iCloud to sync.")
        default:
            return .other(ckError.localizedDescription)
        }
    }
}
