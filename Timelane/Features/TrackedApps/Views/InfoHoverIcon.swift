import SwiftUI

/// An info icon that shows its explanation as soon as the pointer is over it
/// (`.help` tooltips only appear after the system's delay of about a second).
struct InfoHoverIcon: View {
    let text: String
    @State private var isShowing = false

    var body: some View {
        Image(systemName: "info.circle")
            .foregroundStyle(.secondary)
            .onHover { isShowing = $0 }
            .popover(isPresented: $isShowing, arrowEdge: .bottom) {
                Text(text)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 240, alignment: .leading)
                    .padding(10)
            }
            .accessibilityLabel(text)
    }
}

#Preview {
    InfoHoverIcon(text: "Hours are logged automatically to this project while you use the app.").padding(40)
}
