import SwiftUI

/// Top bar of the timeline. `ViewThatFits` picks the richest variant that fits (≈ 960 / 760 / 440 pt of detail width);
/// shortcuts are registered once in `DayNavigationShortcuts`, not on the visible buttons.
struct DayNavigationBar: View {
    let viewModel: TimelineViewModel
    let changeZoom: (ZoomChange) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            wide
            medium
            narrow
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .fixedSize(horizontal: false, vertical: true)
        .background { DayNavigationShortcuts(viewModel: viewModel, changeZoom: changeZoom) }
    }

    private var wide: some View {
        HStack(spacing: 8) {
            DayNavigationButtons(viewModel: viewModel)
            date(viewModel.title, font: .title3)
            Spacer(minLength: 8)
            record
            zoom
            DayTotalsView(registered: viewModel.registeredTotal, tracked: viewModel.trackedTotal).fixedSize()
        }
    }

    private var medium: some View {
        HStack(spacing: 8) {
            DayNavigationButtons(viewModel: viewModel)
            date(viewModel.shortTitle, font: .title3)
            Spacer(minLength: 8)
            record
            zoom
            totals
        }
    }

    private var narrow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                DayNavigationButtons(viewModel: viewModel)
                date(viewModel.shortTitle, font: .headline)
                Spacer(minLength: 8)
                zoom
            }
            HStack(spacing: 8) {
                record
                Spacer(minLength: 8)
                totals
            }
        }
    }

    private var record: some View {
        RecordButton(timer: viewModel.recordingTimer) { viewModel.toggleRecording() }
    }

    private var zoom: some View {
        TimelineZoomControls(zoomState: viewModel.zoomState, apply: changeZoom, registersShortcuts: false).fixedSize()
    }

    private var totals: some View {
        CompactDayTotals(registered: viewModel.registeredTotal, tracked: viewModel.trackedTotal)
    }

    /// The day title with its calendar button right next to it.
    private func date(_ text: String, font: Font) -> some View {
        HStack(spacing: 4) {
            Text(text).font(font.weight(.semibold)).lineLimit(1).fixedSize()
            DayDatePicker(viewModel: viewModel)
        }
        .padding(.leading, 6)
    }
}

#Preview("900") { barPreview(width: 900) }
#Preview("600") { barPreview(width: 600) }
#Preview("480") { barPreview(width: 480) }

@MainActor private func barPreview(width: CGFloat) -> some View {
    let environment = AppEnvironment.preview()
    return DayNavigationBar(
        viewModel: TimelineViewModel(
            timeEntries: environment.timeEntries, appSessions: environment.appSessions,
            projects: environment.projects, trackedApps: environment.trackedApps, editor: environment.timeEntryEditor,
            liveAutoEntry: environment.liveAutoEntry),
        changeZoom: { _ in })
        .frame(width: width)
}
