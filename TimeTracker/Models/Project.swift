import Foundation

struct Project: Identifiable, Hashable, Sendable, Codable {
    var id: Int64?
    var name: String
    var colorHex: String
    var isArchived: Bool
    var createdAt: Date

    init(id: Int64? = nil, name: String, colorHex: String, isArchived: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}
