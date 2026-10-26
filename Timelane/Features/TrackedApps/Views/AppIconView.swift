import SwiftUI

/// Application icon by bundle identifier, with a generic fallback.
struct AppIconView: View {
    let bundleIdentifier: String
    var size: CGFloat = 24

    var body: some View {
        Group {
            if let icon = AppIconProvider.shared.icon(for: bundleIdentifier) {
                Image(nsImage: icon).resizable()
            } else {
                Image(systemName: "app.dashed").resizable().foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
