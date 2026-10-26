import SwiftUI

/// Shown above the timeline while no apps are tracked.
struct NoTrackedAppsBanner: View {
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "app.badge.checkmark").foregroundStyle(.secondary)
            Text("No apps are tracked yet. Add apps in Tracked Apps.")
            Spacer()
            Button("Tracked Apps", action: action)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5))
    }
}

#Preview {
    NoTrackedAppsBanner(action: {}).frame(width: 600)
}
