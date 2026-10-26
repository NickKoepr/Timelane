import SwiftUI

/// Compact day navigation and zoom controls, plus the day's totals.
struct MenuBarDayBar: View {
    let viewModel: TimelineViewModel
    let changeZoom: (ZoomChange) -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Button { viewModel.goToPreviousDay() } label: { Image(systemName: "chevron.left") }
                    .help("Previous day")
                Button("Today") { viewModel.goToToday() }
                    .disabled(viewModel.isToday)
                    .fixedSize()
                Button { viewModel.goToNextDay() } label: { Image(systemName: "chevron.right") }
                    .help("Next day")
                Text(viewModel.day.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.headline)
                    .lineLimit(1).fixedSize()
                    .padding(.leading, 4)
                Spacer(minLength: 4)
                TimelineZoomControls(zoomState: viewModel.zoomState, apply: changeZoom)
            }
            HStack {
                total("Registered", viewModel.registeredTotal)
                Spacer()
                total("Tracked", viewModel.trackedTotal)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func total(_ title: String, _ seconds: TimeInterval) -> some View {
        HStack(spacing: 6) {
            Text(title).foregroundStyle(.secondary)
            Text(DurationFormatter.hoursMinutes(seconds)).fontWeight(.semibold)
        }
        .font(.callout.monospacedDigit())
        .lineLimit(1).fixedSize()
    }
}
