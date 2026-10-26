import SwiftUI

/// Icon and title on top of one lane.
struct LaneHeaderCell: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(.secondary).imageScale(.small)
            Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}
