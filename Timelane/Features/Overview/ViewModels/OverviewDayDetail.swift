import Foundation

/// What the hover card of one heatmap day shows.
struct OverviewDayDetail: Hashable, Sendable {
    struct Row: Hashable, Sendable {
        let projectId: Int64?        // nil for the "+N more" row
        let name: String             // project name, "Unknown project", or "+3 more"
        let colorHex: String?        // nil for the "+N more" row
        let isArchived: Bool
        let seconds: TimeInterval
        let isHighlighted: Bool      // the filtered project
    }

    let day: Date
    let totalSeconds: TimeInterval   // all projects, ignores the filter
    let rows: [Row]

    static let maximumRows = 5

    /// Builds the detail from one day's per-project seconds. Projects missing from `projects` become
    /// "Unknown project" (gray). Exactly `maximumRows` projects are all shown; more than that →
    /// the first `maximumRows - 1` plus one "+N more" row, so the card never exceeds `maximumRows` rows.
    init(day: Date, secondsByProject: [Int64: TimeInterval], projects: [Project], highlightedProjectId: Int64?) {
        let byId = Dictionary(projects.compactMap { project in project.id.map { ($0, project) } },
                              uniquingKeysWith: { first, _ in first })
        let all = secondsByProject.filter { $0.value > 0 }.map { id, seconds -> Row in
            let project = byId[id]
            return Row(projectId: id, name: project?.name ?? "Unknown project", colorHex: project?.colorHex ?? "#8E8E93",
                       isArchived: project?.isArchived ?? false, seconds: seconds,
                       isHighlighted: id == highlightedProjectId)
        }
        .sorted {
            if $0.seconds != $1.seconds { return $0.seconds > $1.seconds }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        var rows = all
        if all.count > Self.maximumRows {
            let rest = all.dropFirst(Self.maximumRows - 1)
            rows = Array(all.prefix(Self.maximumRows - 1)) + [
                Row(projectId: nil, name: "+\(rest.count) more", colorHex: nil, isArchived: false,
                    seconds: rest.reduce(0) { $0 + $1.seconds }, isHighlighted: false),
            ]
        }
        self.day = day
        self.totalSeconds = all.reduce(0) { $0 + $1.seconds }
        self.rows = rows
    }
}
