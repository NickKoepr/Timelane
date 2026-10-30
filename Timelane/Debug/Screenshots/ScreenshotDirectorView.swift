#if DEBUG
import SwiftUI

/// Invisible view in the main window that runs the screenshot director (it needs `openSettings`).
struct ScreenshotDirectorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .task {
                guard let scene = ScreenshotMode.scene, let output = ScreenshotMode.outputDirectory else { return }
                await ScreenshotDirector(scene: scene, output: output, environment: environment,
                                         openSettings: { openSettings() }).run()
            }
    }
}
#endif
