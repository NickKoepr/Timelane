import SwiftUI

@main
struct TimeTrackerApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        Window("TimeTracker", id: "main") {
            RootView()
                .environment(environment)
        }
        .defaultSize(width: 900, height: 750)
    }
}
