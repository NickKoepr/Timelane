import SwiftUI

/// "Record" when idle; "Stop" with the live elapsed time while the shared timer runs.
/// Shortcut (⌘R) lives in `DayNavigationShortcuts`, not here.
struct RecordButton: View {
    let timer: RecordingTimer
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if timer.isRunning {
                HStack(spacing: 4) {
                    Image(systemName: "stop.circle.fill").foregroundStyle(.red)
                    Text("Stop")
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(DurationFormatter.clock(timer.elapsed(at: context.date)))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "record.circle").foregroundStyle(.red)
                    Text("Record")
                }
            }
        }
        .lineLimit(1)
        .fixedSize()
        .help(timer.isRunning ? "Stop and register (⌘R)" : "Start recording (⌘R)")
        .accessibilityLabel(timer.isRunning ? "Stop recording" : "Start recording")
    }
}

#Preview {
    let environment = AppEnvironment.preview()
    environment.recordingTimer.start()
    return VStack {
        RecordButton(timer: RecordingTimer(), action: {})
        RecordButton(timer: environment.recordingTimer, action: {})
    }.padding()
}
