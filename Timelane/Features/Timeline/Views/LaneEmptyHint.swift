import SwiftUI

/// Faint centred hint inside an empty lane. Never intercepts the mouse, so dragging still works.
struct LaneEmptyHint: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3)
            Text(text).font(.callout).multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .opacity(0.8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }
}
