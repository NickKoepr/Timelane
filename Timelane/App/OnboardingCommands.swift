import SwiftUI

/// Help ▸ Welcome to Timelane; replaces the default "Timelane Help" item, as the app has no Help Book.
struct OnboardingCommands: Commands {
    let environment: AppEnvironment
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("Welcome to Timelane") {
                openWindow(id: "main")
                environment.showOnboarding()
            }
        }
    }
}
