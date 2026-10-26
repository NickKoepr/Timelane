import SwiftUI

struct MenuBarFooter: View {
    let openMainWindow: () -> Void

    var body: some View {
        HStack {
            Button("Open TimeTracker", action: openMainWindow)
            Spacer()
            Button("Quit TimeTracker") { NSApp.terminate(nil) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
