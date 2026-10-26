import SwiftUI

struct ProjectRow: View {
    let total: ProjectMonthTotal

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(total.project.color)
                .frame(width: 12, height: 12)
            Text(total.project.name)
            if total.project.isArchived {
                Text("Archived")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(DurationFormatter.hoursMinutes(total.totalSeconds))
                .font(.body.monospacedDigit())
                .foregroundStyle(total.totalSeconds > 0 ? .primary : .secondary)
        }
        .opacity(total.project.isArchived ? 0.6 : 1)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(total.project.name), \(DurationFormatter.short(total.totalSeconds))")
    }
}

#Preview {
    ProjectRow(total: ProjectMonthTotal(project: Project(name: "Project A", colorHex: "#4F8EF7"), totalSeconds: 42 * 3600))
        .padding()
}
