import CloudKit
import Foundation

/// A fetch that always asks the server.
///
/// `CKSyncEngine.fetchChanges()` only goes to the server when the engine believes something changed, which it
/// learns from pushes (or the app coming to the foreground). Pushes are best effort and proved to arrive rarely,
/// so "Sync Now" and polling returned in milliseconds without any request. This reads the database and zone
/// changes with its own change tokens (kept in UserDefaults, dropped whenever the engine starts without state) and delivers them as
/// ordinary `.fetched` events. Records the engine also delivers later are applied twice, which is harmless:
/// applying the same server record again changes nothing.
extension CloudKitSyncEngine {
    static let directTokenKey = "syncDirectZoneChangeToken"
    static let directDatabaseTokenKey = "syncDirectDatabaseChangeToken"

    func fetchZoneChangesDirectly() async throws {
        guard let engine = locked({ $0.engine }) else { throw SyncEngineError.notStarted }
        let zoneToken = Self.loadToken(Self.directTokenKey)
        // First the database feed, like the engine: it reports a deleted zone (another device's "Replace iCloud
        // data") and tells whether the zone changed at all, so an idle check is a single small request.
        guard let zoneChanged = try await zoneChangedSinceLastCheck(engine: engine) else { return }
        guard zoneChanged || zoneToken == nil else { return }

        var token = zoneToken
        var saves: [SyncServerRecord] = []
        var deletes: [SyncRecordID] = []
        var moreComing = true
        while moreComing {
            let result: (modificationResultsByID: [CKRecord.ID: Result<CKDatabase.RecordZoneChange.Modification, Error>],
                         deletions: [CKDatabase.RecordZoneChange.Deletion], changeToken: CKServerChangeToken, moreComing: Bool)
            do {
                result = try await container.privateCloudDatabase.recordZoneChanges(inZoneWith: Self.zoneID, since: token)
            } catch let error as CKError where error.code == .changeTokenExpired && token != nil {
                token = nil         // same zone (the database feed reported no deletion): read it from the start
                saves = []
                deletes = []
                continue
            } catch let error as CKError where error.code == .zoneNotFound {
                await deliver(.zoneDeleted, from: engine)
                return
            } catch {
                throw Self.mapped(error)
            }
            for case .success(let modification) in result.modificationResultsByID.values {
                if let record = Self.serverRecord(from: modification.record) { saves.append(record) }
            }
            for deletion in result.deletions {
                if let type = SyncRecordType(rawValue: deletion.recordType),
                   let syncId = UUID(uuidString: deletion.recordID.recordName) {
                    deletes.append(SyncRecordID(recordType: type, syncId: syncId))
                }
            }
            token = result.changeToken
            moreComing = result.moreComing
        }
        if !saves.isEmpty || !deletes.isEmpty { await deliver(.fetched(saves: saves, deletes: deletes), from: engine) }
        // Only remember the token when the engine was not replaced meanwhile (a reset drops it).
        if locked({ $0.engine === engine }) { Self.saveToken(token, Self.directTokenKey) }
    }

    /// Whether the zone changed since the last direct check; nil when it was deleted (the event is delivered).
    private func zoneChangedSinceLastCheck(engine: CKSyncEngine) async throws -> Bool? {
        var token = Self.loadToken(Self.directDatabaseTokenKey)
        let isFirstCheck = token == nil
        var changed = false
        var deleted = false
        var moreComing = true
        while moreComing {
            let result: (modifications: [CKDatabase.DatabaseChange.Modification], deletions: [CKDatabase.DatabaseChange.Deletion],
                         changeToken: CKServerChangeToken, moreComing: Bool)
            do {
                result = try await container.privateCloudDatabase.databaseChanges(since: token)
            } catch let error as CKError where error.code == .changeTokenExpired && token != nil {
                token = nil
                changed = true      // unknown: read the zone
                continue
            } catch {
                throw Self.mapped(error)
            }
            if result.modifications.contains(where: { $0.zoneID == Self.zoneID }) { changed = true }
            // A first check (no token) sees history, not news (for example this device's own reset).
            if !isFirstCheck && result.deletions.contains(where: { $0.zoneID == Self.zoneID }) { deleted = true }
            token = result.changeToken
            moreComing = result.moreComing
        }
        if deleted {
            await deliver(.zoneDeleted, from: engine)
            return nil      // the token is not saved: the reset that follows starts the direct fetch over
        }
        if locked({ $0.engine === engine }) { Self.saveToken(token, Self.directDatabaseTokenKey) }
        return changed
    }

    private func deliver(_ event: SyncEngineEvent, from engine: CKSyncEngine) async {
        let handler = locked { storage -> Handler? in
            guard storage.engine === engine else { return nil }
            if case .zoneDeleted = event, storage.ignoresZoneDeletions { return nil }
            return storage.handler
        }
        await handler?(event)
    }

    static func loadToken(_ key: String) -> CKServerChangeToken? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    static func saveToken(_ token: CKServerChangeToken?, _ key: String) {
        guard let token, let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Forgets both direct-fetch tokens (an engine that starts without state reads everything again).
    static func clearDirectTokens() {
        saveToken(nil, directTokenKey)
        saveToken(nil, directDatabaseTokenKey)
    }
}
