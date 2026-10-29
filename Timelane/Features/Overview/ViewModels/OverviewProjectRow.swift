import Foundation

/// One line of the per-project list of the Overview screen.
struct OverviewProjectRow: Identifiable, Hashable, Sendable {
    let project: Project
    let seconds: TimeInterval
    /// Fraction of the (filtered) year total, 0…1.
    let share: Double

    var id: Int64? { project.id }
}
