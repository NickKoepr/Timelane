import Foundation

struct Project: Identifiable, Hashable, Sendable, Codable {
    var id: Int64?
    var name: String
    var colorHex: String
    var isArchived: Bool
    var createdAt: Date
    /// Optional free-text identifier chosen by the user (e.g. a customer code). Not the primary key.
    var customId: String?

    init(id: Int64? = nil, name: String, colorHex: String, isArchived: Bool = false, createdAt: Date = .now,
         customId: String? = nil) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.customId = customId
    }
}
