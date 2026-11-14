import Foundation

/// One synced record as a plain value: what is uploaded, downloaded and parked.
struct SyncRecord: Codable, Equatable, Sendable {
    var syncId: UUID
    var fields: SyncFields

    var recordType: SyncRecordType { fields.recordType }

    init(syncId: UUID, fields: SyncFields) {
        self.syncId = syncId
        self.fields = fields
    }

    init(syncId: UUID, project: ProjectFields) {
        self.init(syncId: syncId, fields: .project(project))
    }

    init(syncId: UUID, timeEntry: TimeEntryFields) {
        self.init(syncId: syncId, fields: .timeEntry(timeEntry))
    }
}
