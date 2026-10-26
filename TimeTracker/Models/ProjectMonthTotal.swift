import Foundation

/// Read model: a project with the seconds registered in some period.
struct ProjectMonthTotal: Identifiable, Hashable, Sendable {
    var project: Project
    var totalSeconds: TimeInterval

    var id: Int64? { project.id }
}
