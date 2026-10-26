import SwiftUI

struct DayNavigationBar: View {
    let viewModel: TimelineViewModel
    let changeZoom: (ZoomChange) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button { viewModel.goToPreviousDay() } label: { Image(systemName: "chevron.left") }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .help("Previous day")
            Button("Today") { viewModel.goToToday() }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(viewModel.isToday)
            Button { viewModel.goToNextDay() } label: { Image(systemName: "chevron.right") }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .help("Next day")
            Text(viewModel.title)
                .font(.title3.weight(.semibold))
                .padding(.leading, 6)
            DatePicker("Day", selection: Binding(get: { viewModel.day.start }, set: { viewModel.go(to: $0) }),
                       displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
            Spacer()
            TimelineZoomControls(zoomState: viewModel.zoomState, apply: changeZoom)
            DayTotalsView(registered: viewModel.registeredTotal, tracked: viewModel.trackedTotal)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}
