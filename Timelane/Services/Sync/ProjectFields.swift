import Foundation

/// Synced fields of a project. The whole record is one conflict unit (last writer wins on `updatedAt`).
struct ProjectFields: Codable, Equatable, Sendable {
    var name: String
    var colorHex: String
    var isArchived: Bool
    var createdAt: Date
    var customId: String?
    var updatedAt: Date
    var schemaVersion: Int = SyncFields.currentSchemaVersion

    /// Content ordering for equal timestamps (the `syncId` is identical for two versions of one record).
    var tiebreakKey: String {
        [name, colorHex, isArchived ? "1" : "0", customId ?? ""].joined(separator: "\u{1}")
    }
}
