#if os(iOS)
import SwiftUI

/// Page indicator for the welcome carousel. The page TabView's own dots are always white, so they vanished on the
/// light background; these use the primary colour and follow light and dark mode.
struct IOSPageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                    .frame(width: 8, height: 8)
            }
        }
        .animation(.default, value: current)
        .accessibilityElement()
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

#Preview {
    IOSPageDots(count: 4, current: 1).padding()
}
#endif
