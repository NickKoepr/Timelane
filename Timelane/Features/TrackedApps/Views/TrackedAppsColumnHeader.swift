import SwiftUI

/// Column titles above the tracked apps list; an info icon next to "Project" explains the picker once
/// (on hover), instead of a label in every row. Widths come from `TrackedAppRow` so the columns line up.
struct TrackedAppsColumnHeader: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: TrackedAppRow.spacing) {
            Text("App")
                .lineLimit(1)
            Spacer(minLength: 8)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Project")
                    .lineLimit(1)
                InfoHoverIcon(text: "Hours are logged automatically to this project while you use the app. Changing it only affects new hours.")
            }
            .padding(.leading, TrackedAppRow.pickerTextInset)
            .frame(width: TrackedAppRow.projectColumnWidth, alignment: .leading)
            Color.clear.frame(width: TrackedAppRow.removeColumnWidth, height: 1)
        }
        .font(.headline)
        .foregroundStyle(.primary)
        .padding(.vertical, 4)
    }
}

#Preview {
    TrackedAppsColumnHeader().padding().frame(width: 500)
}
