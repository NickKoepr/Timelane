import SwiftUI

struct MenuBarFooter: View {
    let openMainWindow: () -> Void

    var body: some View {
        HStack {
            Button("Open Timelane", action: openMainWindow)
            Spacer()
            Button("Quit Timelane") { NSApp.terminate(nil) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
