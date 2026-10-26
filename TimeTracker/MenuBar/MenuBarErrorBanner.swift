import SwiftUI

/// Inline replacement for the error alert of the main window.
struct MenuBarErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            Text(message).font(.callout).foregroundStyle(.red)
            Spacer()
            Button("OK", action: dismiss)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.5))
    }
}
