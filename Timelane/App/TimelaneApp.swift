import SwiftUI

@main
struct TimelaneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var environment = AppEnvironment.shared

    var body: some Scene {
        Window("Timelane", id: "main") {
            RootView()
                .environment(environment)
        }
        .defaultSize(width: 900, height: 750)
        .windowResizability(.contentMinSize)

        // Same clock as the app icon (template image from Tools/generate-app-icon.swift).
        MenuBarExtra("Timelane", image: "MenuBarIcon") {
            MenuBarContentView(environment: environment)
                .environment(environment)
        }
        .menuBarExtraStyle(.window)
    }
}
