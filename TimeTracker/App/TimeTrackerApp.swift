import SwiftUI

@main
struct TimeTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var environment = AppEnvironment.shared

    var body: some Scene {
        Window("TimeTracker", id: "main") {
            RootView()
                .environment(environment)
        }
        .defaultSize(width: 900, height: 750)

        // Same clock as the app icon (template image from Tools/generate-app-icon.swift).
        MenuBarExtra("TimeTracker", image: "MenuBarIcon") {
            MenuBarContentView(environment: environment)
                .environment(environment)
        }
        .menuBarExtraStyle(.window)
    }
}
