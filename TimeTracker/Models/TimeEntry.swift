import Foundation

struct TimeEntry: Identifiable, Hashable, Sendable, Codable {
    var id: Int64?
    var projectId: Int64
    var start: Date
    var end: Date            // invariant: end > start
    var title: String?
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }
    var range: DateRange { DateRange(start: start, end: end) }

    init(id: Int64? = nil, projectId: Int64, start: Date, end: Date, title: String? = nil, note: String? = nil,
         createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.projectId = projectId
        self.start = start
        self.end = end
        self.title = title
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
