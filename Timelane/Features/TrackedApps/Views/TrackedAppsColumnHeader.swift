import SwiftUI

/// Column titles above the tracked apps list; the Project column explains what the picker does once,
/// instead of a label in every row. Widths come from `TrackedAppRow` so the columns line up.
struct TrackedAppsColumnHeader: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: TrackedAppRow.spacing) {
            Text("App")
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text("Project")
                    .font(.headline)
                    .lineLimit(1)
                Text("Logs hours automatically while you use the app")
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: TrackedAppRow.projectColumnWidth, alignment: .leading)
            Color.clear.frame(width: TrackedAppRow.removeColumnWidth, height: 1)
        }
        .foregroundStyle(.primary)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    TrackedAppsColumnHeader().padding().frame(width: 500)
}
