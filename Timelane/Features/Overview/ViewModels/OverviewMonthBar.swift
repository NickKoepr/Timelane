import Foundation

/// One stacked segment of the "Hours per month" chart.
struct OverviewMonthBar: Identifiable, Hashable, Sendable {
    let monthStart: Date
    let projectId: Int64
    let projectName: String
    let colorHex: String
    let seconds: TimeInterval

    var id: String { "\(monthStart.timeIntervalSince1970)-\(projectId)" }
}
