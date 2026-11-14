import SwiftUI

@main
struct TimelaneApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #else
    @UIApplicationDelegateAdaptor(IOSAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    #endif
    @State private var environment = AppEnvironment.shared

    var body: some Scene {
        #if os(macOS)
        Window("Timelane", id: "main") {
            RootView()
                #if DEBUG
                .background { if ScreenshotMode.isActive { ScreenshotDirectorView() } }
                #endif
                .environment(environment)
        }
        .defaultSize(width: 900, height: 750)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Timelane") { AboutPanel.show() }
            }
            TimeEntryUndoCommands(history: environment.timeEntryHistory)
            OnboardingCommands(environment: environment)
        }

        // Same clock as the app icon (template image from Tools/generate-app-icon.swift);
        // a red dot is added while the Record timer runs.
        MenuBarExtra(isInserted: .constant(!AppEnvironment.isIsolatedRun)) {
            MenuBarContentView(environment: environment)
                .environment(environment)
        } label: {
            MenuBarLabel(timer: environment.recordingTimer)
        }
        .menuBarExtraStyle(.window)

        // Timelane ▸ Settings… (⌘,): the out-of-the-way home of opt-in features such as iCloud backup.
        Settings {
            SettingsView()
                .environment(environment)
        }
        #else
        WindowGroup {
            IOSRootView()
                .environment(environment)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, !AppEnvironment.isIsolatedRun else { return }
            Task { await environment.sync.syncNow() }   // no-op while sync is off
        }
        #endif
    }
}
