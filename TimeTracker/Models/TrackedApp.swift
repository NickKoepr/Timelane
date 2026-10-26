import Foundation

/// An application the user wants to track. Only tracked apps produce app sessions.
struct TrackedApp: Identifiable, Hashable, Sendable, Codable {
    var id: Int64?
    var bundleIdentifier: String
    var name: String
    var addedAt: Date

    init(id: Int64? = nil, bundleIdentifier: String, name: String, addedAt: Date = .now) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.addedAt = addedAt
    }
}
