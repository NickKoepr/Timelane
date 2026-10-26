import Foundation

struct AppSession: Identifiable, Hashable, Sendable, Codable {
    var id: Int64?
    var bundleIdentifier: String
    var appName: String
    var start: Date
    var end: Date?           // nil = currently active session

    init(id: Int64? = nil, bundleIdentifier: String, appName: String, start: Date, end: Date? = nil) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.start = start
        self.end = end
    }
}
