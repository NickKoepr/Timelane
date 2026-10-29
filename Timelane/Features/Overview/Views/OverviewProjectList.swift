import SwiftUI

/// Per-project total for the year with a thin proportional bar and the share in %.
struct OverviewProjectList: View {
    let rows: [OverviewProjectRow]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(rows) { row in
                HStack(spacing: 8) {
                    Circle().fill(row.project.color).frame(width: 10, height: 10)
                    HStack(spacing: 4) {
                        Text(row.project.name).lineLimit(1)
                        if row.project.isArchived { Text("Archived").foregroundStyle(.secondary) }
                    }
                    .frame(minWidth: 80, maxWidth: 200, alignment: .leading)
                    Capsule().fill(.quaternary).frame(height: 6)
                        .overlay(alignment: .leading) {
                            GeometryReader { proxy in
                                Capsule().fill(row.project.color).frame(width: proxy.size.width * row.share)
                            }
                        }
                    Text(DurationFormatter.short(row.seconds)).frame(minWidth: 64, alignment: .trailing)
                    Text(row.share.formatted(.percent.precision(.fractionLength(0))))
                        .foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
                }
                .monospacedDigit()
                .accessibilityElement(children: .combine)
            }
        }
    }
}

#Preview {
    OverviewProjectList(rows: [
        OverviewProjectRow(project: Project(id: 1, name: "Alpha", colorHex: "#4F8EF7"), seconds: 90 * 3600, share: 0.75),
        OverviewProjectRow(project: Project(id: 2, name: "Old one", colorHex: "#34C759", isArchived: true), seconds: 30 * 3600, share: 0.25),
    ]).padding().frame(width: 480)
}
