import SwiftUI

/// The menu bar item: the clock icon, with a red dot while the Record timer runs.
struct MenuBarLabel: View {
    let timer: RecordingTimer

    var body: some View {
        let style = MenuBarIconStyle(isRecording: timer.isRunning)
        Image(nsImage: MenuBarIconRenderer.image(for: style))
            .renderingMode(style == .recording ? .original : .template)
            .accessibilityLabel(style.title)
    }
}

#Preview {
    HStack(spacing: 24) {
        Image(nsImage: MenuBarIconRenderer.image(for: .normal))
        Image(nsImage: MenuBarIconRenderer.image(for: .recording))
    }
    .padding()
}
