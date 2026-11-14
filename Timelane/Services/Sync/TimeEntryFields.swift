import Foundation

/// Synced fields of a time entry. Three field groups each have their own modification time (see
/// `SyncMergePolicy`): times (`start`, `end`), text (`title`, `note`) and project.
struct TimeEntryFields: Codable, Equatable, Sendable {
    var projectSyncId: UUID
    var start: Date
    var end: Date
    var title: String?
    var note: String?
    var createdAt: Date
    var updatedAt: Date
    var timesUpdatedAt: Date
    var textUpdatedAt: Date
    var projectUpdatedAt: Date
    var schemaVersion: Int = SyncFields.currentSchemaVersion

    /// When the newest change to this entry was made; decides who wins an overlap.
    var actionTime: Date { max(timesUpdatedAt, textUpdatedAt, projectUpdatedAt) }

    var timesKey: String { "\(start.timeIntervalSince1970)|\(end.timeIntervalSince1970)" }
    var textKey: String { "\(title ?? "")\u{1}\(note ?? "")" }
    var projectKey: String { projectSyncId.uuidString }
}
