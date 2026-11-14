import Foundation

/// The kinds of rows that are synced. The raw value is the CloudKit record type.
enum SyncRecordType: String, Codable, Sendable, CaseIterable {
    case project = "Project"
    case timeEntry = "TimeEntry"
}
