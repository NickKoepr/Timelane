import Foundation

/// Rules for the optional, user-chosen project identifier.
enum ProjectCustomId {
    static let maxLength = 40
    /// Longest ID shown in full outside the Projects screen; longer ones are cut off with "…".
    static let displayLength = 20

    /// Trims whitespace/newlines; empty becomes nil. Does not truncate.
    static func normalized(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// The ID cut to `limit` characters plus "…" when it is longer.
    static func shortened(_ id: String, to limit: Int = displayLength) -> String {
        id.count > limit ? String(id.prefix(limit)) + "…" : id
    }
}
