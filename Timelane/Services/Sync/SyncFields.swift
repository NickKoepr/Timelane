import Foundation

/// The synced content of a record, independent of any storage or CloudKit type.
enum SyncFields: Codable, Equatable, Sendable {
    case project(ProjectFields)
    case timeEntry(TimeEntryFields)

    /// Written into every record so newer app versions can add fields (older apps park such records).
    static let currentSchemaVersion = 1

    var recordType: SyncRecordType {
        switch self {
        case .project: .project
        case .timeEntry: .timeEntry
        }
    }
}
