import SwiftUI

struct SessionHoverCardContent: View {
    let block: AppSessionBlockModel

    var body: some View {
        HStack(spacing: 10) {
            if let icon = AppIconProvider.shared.icon(for: block.bundleIdentifier) {
                Image(nsImage: icon).resizable().frame(width: 24, height: 24)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(block.appName).font(.headline).lineLimit(1)
                Text("\(block.start.formatted(date: .omitted, time: .shortened)) – \(block.end.formatted(date: .omitted, time: .shortened))")
                    .font(.caption.monospacedDigit())
                Text(DurationFormatter.short(block.duration)).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
