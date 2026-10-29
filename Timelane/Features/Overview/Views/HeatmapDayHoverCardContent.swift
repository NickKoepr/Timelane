import SwiftUI

/// Date, total and per-project hours of one heatmap day.
struct HeatmapDayHoverCardContent: View {
    let detail: OverviewDayDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(detail.day.formatted(.dateTime.weekday(.wide).day().month(.wide).year())).font(.headline)
            Text(detail.totalSeconds > 0 ? "\(DurationFormatter.short(detail.totalSeconds)) registered" : "No hours registered")
                .font(.caption).foregroundStyle(.secondary)
            if !detail.rows.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(detail.rows, id: \.projectId) { row in
                        HStack(spacing: 6) {
                            Circle().fill(row.colorHex.map(ProjectColor.color(hex:)) ?? .clear).frame(width: 8, height: 8)
                            Text(row.name).lineLimit(1)
                            if row.isArchived { Text("Archived").foregroundStyle(.secondary) }
                            Spacer(minLength: 4)
                            Text(DurationFormatter.short(row.seconds)).monospacedDigit()
                        }
                        .font(.caption)
                        .fontWeight(row.isHighlighted ? .bold : .regular)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

#Preview("Empty") { cardPreview(hours: [:]) }
#Preview("2 projects") { cardPreview(hours: [1: 4.5, 2: 2], highlighted: 1) }
#Preview("7 projects") { cardPreview(hours: [1: 6, 2: 5, 3: 4, 4: 3, 5: 2, 6: 1, 7: 0.5]) }

private func cardPreview(hours: [Int64: Double], highlighted: Int64? = nil) -> some View {
    let projects = (1...7).map {
        Project(id: Int64($0), name: "Project \($0)", colorHex: ProjectColor.hex(forIndex: $0), isArchived: $0 == 2)
    }
    let detail = OverviewDayDetail(day: .now, secondsByProject: hours.mapValues { $0 * 3600 },
                                   projects: projects, highlightedProjectId: highlighted)
    return HeatmapDayHoverCardContent(detail: detail).padding().frame(width: 240)
}
