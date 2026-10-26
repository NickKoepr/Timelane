import SwiftUI

struct TrackedAppRow: View {
    let app: TrackedApp
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            AppIconView(bundleIdentifier: app.bundleIdentifier, size: 28)
                .fixedSize()
            VStack(alignment: .leading, spacing: 0) {
                Text(app.name).lineLimit(1).truncationMode(.tail)
                Text(app.bundleIdentifier)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Button(action: onRemove) { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
                .fixedSize()
                .help("Stop tracking \(app.name)")
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    TrackedAppRow(app: TrackedApp(bundleIdentifier: "com.apple.dt.Xcode", name: "Xcode"), onRemove: {}).padding()
}
