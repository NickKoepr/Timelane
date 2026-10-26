import SwiftUI

/// The content of an app session block; shows as much as `style` allows.
struct AppSessionBlockLabel: View {
    let block: AppSessionBlockModel
    let style: SessionLabelStyle
    let height: CGFloat

    var body: some View {
        switch style {
        case .full:
            HStack(spacing: 6) {
                icon(size: 16)
                VStack(alignment: .leading, spacing: 0) {
                    Text(block.appName).font(.caption.weight(.medium)).lineLimit(1)
                    Text(DurationFormatter.short(block.duration)).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 3)
            .frame(maxHeight: .infinity, alignment: .top)
        case .singleLine:
            HStack(spacing: 4) {
                icon(size: 12)
                Text(block.appName).font(.caption2.weight(.medium)).lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)
        case .iconOnly:
            HStack(spacing: 0) {
                icon(size: min(max(height - 2, 8), 14))
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)
        case .colorOnly:
            Color.clear
        }
    }

    @ViewBuilder private func icon(size: CGFloat) -> some View {
        if let image = AppIconProvider.shared.icon(for: block.bundleIdentifier) {
            Image(nsImage: image).resizable().frame(width: size, height: size)
        }
    }
}
