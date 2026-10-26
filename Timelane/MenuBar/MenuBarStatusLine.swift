import SwiftUI

/// The live tracking status: red dot + current app, grey "Not tracking: X" or grey "Paused".
struct MenuBarStatusLine: View {
    let tracker: AppActivityTracker

    var body: some View {
        let status = tracker.status
        HStack(spacing: 6) {
            Image(systemName: Self.symbol(for: status))
                .foregroundStyle(Self.isRecording(status) ? Color.red : Color.secondary)
            Text(status.text)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.accessibilityLabel)
    }

    private static func symbol(for status: TrackingStatus) -> String {
        switch status {
        case .tracking: "record.circle"
        case .notTracked: "eye.slash"
        case .paused: "pause.circle"
        }
    }

    private static func isRecording(_ status: TrackingStatus) -> Bool {
        if case .tracking = status { return true }
        return false
    }
}
