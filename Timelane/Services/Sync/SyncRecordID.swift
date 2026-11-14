import Foundation

/// Identifies one synced record: its type plus the global `syncId`. The CloudKit record name is `syncId.uuidString`.
struct SyncRecordID: Hashable, Codable, Sendable {
    var recordType: SyncRecordType
    var syncId: UUID

    var recordName: String { syncId.uuidString }
}

extension SyncRecord {
    var id: SyncRecordID { SyncRecordID(recordType: recordType, syncId: syncId) }

    /// Records with a higher `schemaVersion` come from a newer app and are parked, not applied (E4).
    var isSupported: Bool { schemaVersion <= SyncFields.currentSchemaVersion }

    var schemaVersion: Int {
        switch fields {
        case .project(let project): project.schemaVersion
        case .timeEntry(let entry): entry.schemaVersion
        }
    }
}
