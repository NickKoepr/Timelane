import Foundation

/// Metadata of one database snapshot, stored next to it in iCloud so the UI and the safety rule
/// can look at a backup without downloading it.
struct BackupInfo: Sendable, Equatable {
    var createdAt: Date
    var deviceName: String
    var appVersion: String
    /// Identifier of the last applied migration, e.g. "v3".
    var schemaVersion: String
    var projectCount: Int
    var timeEntryCount: Int

    var hasData: Bool { projectCount > 0 || timeEntryCount > 0 }
}
