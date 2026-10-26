import SwiftUI

struct AppSessionBlock: View {
    let block: AppSessionBlockModel
    let height: CGFloat

    private var tint: Color { StableColor.color(for: block.bundleIdentifier) }

    var body: some View {
        HStack(spacing: 6) {
            if height >= 18, let icon = AppIconProvider.shared.icon(for: block.bundleIdentifier) {
                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
            }
            if height > 30 {
                VStack(alignment: .leading, spacing: 0) {
                    Text(block.appName).font(.caption.weight(.medium)).lineLimit(1)
                    Text(DurationFormatter.short(block.duration)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .background(tint.opacity(0.28), in: RoundedRectangle(cornerRadius: 5))
        .overlay(alignment: .leading) { Rectangle().fill(tint).frame(width: 3).clipShape(RoundedRectangle(cornerRadius: 2)) }
        .clipped()
        .contentShape(Rectangle())
        .help("\(block.appName)\n\(block.start.formatted(date: .omitted, time: .shortened)) – \(block.end.formatted(date: .omitted, time: .shortened))")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(block.appName), \(DurationFormatter.short(block.duration))")
    }
}
