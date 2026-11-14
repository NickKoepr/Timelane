import CloudKit
import Foundation

/// `CKRecord` <-> `SyncRecord`. Fields are plain values; references use the `projectSyncId` string, not `CKRecord.Reference`.
extension CloudKitSyncEngine {
    static func recordID(for id: SyncRecordID) -> CKRecord.ID {
        CKRecord.ID(recordName: id.recordName, zoneID: zoneID)
    }

    /// The record to upload. Starting from the stored system fields keeps the change tag; only our own keys are
    /// written, so keys a newer app version added stay untouched on the server.
    static func makeRecord(from upload: SyncUploadRecord) -> CKRecord {
        let id = upload.record.id
        var record = CKRecord(recordType: id.recordType.rawValue, recordID: recordID(for: id))
        if let data = upload.systemFields, let restored = restore(data), restored.recordType == id.recordType.rawValue {
            record = restored
        }
        switch upload.record.fields {
        case .project(let fields):
            record["name"] = fields.name
            record["colorHex"] = fields.colorHex
            record["isArchived"] = Int64(fields.isArchived ? 1 : 0)
            record["createdAt"] = fields.createdAt
            setOptional(record, "customId", fields.customId)
            record["updatedAt"] = fields.updatedAt
            record["schemaVersion"] = Int64(fields.schemaVersion)
        case .timeEntry(let fields):
            record["projectSyncId"] = fields.projectSyncId.uuidString
            record["start"] = fields.start
            record["end"] = fields.end
            setOptional(record, "title", fields.title)
            setOptional(record, "note", fields.note)
            record["createdAt"] = fields.createdAt
            record["updatedAt"] = fields.updatedAt
            record["timesUpdatedAt"] = fields.timesUpdatedAt
            record["textUpdatedAt"] = fields.textUpdatedAt
            record["projectUpdatedAt"] = fields.projectUpdatedAt
            record["schemaVersion"] = Int64(fields.schemaVersion)
        }
        return record
    }

    private static func setOptional(_ record: CKRecord, _ key: String, _ value: String?) {
        if let value { record[key] = value } else { record[key] = nil }
    }

    /// Nil when the record is not ours or lacks a required field.
    static func syncRecord(from record: CKRecord) -> SyncRecord? {
        guard let syncId = UUID(uuidString: record.recordID.recordName),
              let type = SyncRecordType(rawValue: record.recordType) else { return nil }
        let version = Int((record["schemaVersion"] as? Int64) ?? 1)
        switch type {
        case .project:
            guard let name = record["name"] as? String, let color = record["colorHex"] as? String,
                  let createdAt = record["createdAt"] as? Date, let updatedAt = record["updatedAt"] as? Date else {
                logger.error("Skipping a Project record without its required fields")
                return nil
            }
            let archived = ((record["isArchived"] as? Int64) ?? 0) != 0
            let fields = ProjectFields(name: name, colorHex: color, isArchived: archived, createdAt: createdAt,
                                       customId: record["customId"] as? String, updatedAt: updatedAt, schemaVersion: version)
            return SyncRecord(syncId: syncId, project: fields)
        case .timeEntry:
            guard let projectText = record["projectSyncId"] as? String, let projectSyncId = UUID(uuidString: projectText),
                  let start = record["start"] as? Date, let end = record["end"] as? Date,
                  let createdAt = record["createdAt"] as? Date, let updatedAt = record["updatedAt"] as? Date else {
                logger.error("Skipping a TimeEntry record without its required fields")
                return nil
            }
            let fields = TimeEntryFields(
                projectSyncId: projectSyncId, start: start, end: end, title: record["title"] as? String,
                note: record["note"] as? String, createdAt: createdAt, updatedAt: updatedAt,
                timesUpdatedAt: (record["timesUpdatedAt"] as? Date) ?? updatedAt,
                textUpdatedAt: (record["textUpdatedAt"] as? Date) ?? updatedAt,
                projectUpdatedAt: (record["projectUpdatedAt"] as? Date) ?? updatedAt, schemaVersion: version)
            return SyncRecord(syncId: syncId, timeEntry: fields)
        }
    }

    // MARK: System fields

    /// The change tag and record metadata, without the field values.
    static func encodeSystemFields(_ record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    static func restore(_ data: Data) -> CKRecord? {
        guard let coder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        coder.requiresSecureCoding = true
        let record = CKRecord(coder: coder)
        coder.finishDecoding()
        return record
    }
}
