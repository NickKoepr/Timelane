import SwiftUI

/// The running recording in the Logged hours lane (start → now). Purely visual: never takes clicks or drags.
struct RecordingBlock: View {
    let viewModel: TimelineViewModel

    var body: some View {
        if let range = viewModel.recordingRange {
            let frame = viewModel.geometry.frame(for: range.start, end: range.end)
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.red.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.red, lineWidth: 1.5))
                .overlay(alignment: .topLeading) {
                    if frame.height >= 18 {
                        Text("Recording · \(DurationFormatter.hoursMinutes(range.duration))")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.red)
                            .lineLimit(1)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                    }
                }
                .frame(height: max(frame.height, 2))
                .offset(y: frame.y)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
