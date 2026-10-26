import SwiftUI

@main
struct TimeTrackerApp: App {
    var body: some Scene {
        Window("TimeTracker", id: "main") {
            RootView()
        }
        .defaultSize(width: 900, height: 750)
    }
}
