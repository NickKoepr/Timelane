import SwiftUI

/// Icon, title and optional caption on top of one lane.
struct LaneHeaderCell: View {
    let icon: String
    let title: String
    let caption: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(.secondary).imageScale(.small)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                if let caption { Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption.map { "\(title), \($0.lowercased())" } ?? title)
    }
}
