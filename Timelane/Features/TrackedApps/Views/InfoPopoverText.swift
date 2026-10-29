import SwiftUI

/// The content of an info popover: text wrapped at a fixed width, never truncated.
struct InfoPopoverText: View {
    static let width: CGFloat = 240
    static let padding: CGFloat = 10

    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .multilineTextAlignment(.leading)
            .frame(width: Self.width, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Self.padding)
            // Fix the size on the outermost view, so the popover is sized from the
            // wrapped height instead of a single-line ideal size.
            .fixedSize()
    }
}

#Preview {
    InfoPopoverText(text: "Hours are logged automatically to this project while you use the app. Changing it only affects new hours.")
}
