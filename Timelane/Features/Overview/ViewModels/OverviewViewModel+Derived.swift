import Foundation

extension OverviewViewModel {
    var heatmapLayout: ActivityHeatmapLayout { ActivityHeatmapLayout(year: year, calendar: calendar) }

    /// Day → seconds for the current filter.
    var dailyTotals: [Date: TimeInterval] { activity.dailyTotals(projectId: effectiveProjectId) }

    var statistics: ActivityStatistics {
        ActivityStatistics(dailyTotals: dailyTotals, year: year, today: now(), calendar: calendar)
    }

    var totalSeconds: TimeInterval { dailyTotals.values.reduce(0, +) }
    var hasHours: Bool { totalSeconds > 0 }

    var selectedProject: Project? { projects.first { $0.id == effectiveProjectId } }

    /// "1,234 h registered in 2026", or "… on <project>" when filtered.
    var heading: String {
        let hours = (totalSeconds / 3600).formatted(.number.precision(.fractionLength(0)))
        let base = "\(hours) h registered in \(yearTitle)"
        return selectedProject.map { "\(base) on \($0.name)" } ?? base
    }

    /// Projects with hours in the year, most hours first.
    var projectRows: [OverviewProjectRow] {
        let totals = activity.projectTotals()
        let total = totals.filter { effectiveProjectId == nil || $0.key == effectiveProjectId }.values.reduce(0, +)
        return projects
            .compactMap { project -> OverviewProjectRow? in
                guard let id = project.id, let seconds = totals[id], seconds > 0,
                      effectiveProjectId == nil || effectiveProjectId == id else { return nil }
                return OverviewProjectRow(project: project, seconds: seconds, share: total > 0 ? seconds / total : 0)
            }
            .sorted {
                if $0.seconds != $1.seconds { return $0.seconds > $1.seconds }
                return $0.project.name.localizedCaseInsensitiveCompare($1.project.name) == .orderedAscending
            }
    }

    /// Stacked chart segments: one per month and project with hours.
    var monthlyBars: [OverviewMonthBar] {
        let months = activity.monthlyTotals(projectId: effectiveProjectId, calendar: calendar)
        var bars: [OverviewMonthBar] = []
        for (index, perProject) in months.enumerated() {
            guard let start = calendar.date(byAdding: .month, value: index, to: year.start) else { continue }
            for project in projects {
                guard let id = project.id, let seconds = perProject[id], seconds > 0 else { continue }
                bars.append(OverviewMonthBar(monthStart: start, projectId: id, projectName: project.name,
                                             colorHex: project.colorHex, seconds: seconds))
            }
        }
        return bars
    }
}
