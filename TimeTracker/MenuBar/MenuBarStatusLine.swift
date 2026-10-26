import SwiftUI

/// The live tracking status: red dot + current app, "Paused" or "Not tracking: X".
struct MenuBarStatusLine: View {
    let tracker: AppActivityTracker

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tracker.isPaused ? "pause.circle" : "record.circle")
                .foregroundStyle(tracker.isPaused ? Color.secondary : Color.red)
            Text(statusText)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private var statusText: String {
        if tracker.isPaused { return "Paused" }
        guard let app = tracker.currentApp else { return "Not tracking" }
        return tracker.isCurrentAppTracked ? app.name : "Not tracking: \(app.name)"
    }
}
