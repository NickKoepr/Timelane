import Foundation

/// Rules for the optional, user-chosen project identifier.
enum ProjectCustomId {
    static let maxLength = 40

    /// Trims whitespace/newlines; empty becomes nil. Does not truncate.
    static func normalized(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
