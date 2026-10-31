import SwiftUI

/// Clickable page indicator.
struct OnboardingPageDots: View {
    let count: Int
    let current: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Button { onSelect(index) } label: {
                    Circle()
                        .fill(index == current ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(width: 8, height: 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Page \(index + 1) of \(count)")
            }
        }
    }
}

#Preview {
    OnboardingPageDots(count: 5, current: 2, onSelect: { _ in }).padding()
}
