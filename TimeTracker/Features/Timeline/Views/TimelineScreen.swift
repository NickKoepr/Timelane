import SwiftUI

struct TimelineScreen: View {
    @State private var viewModel: TimelineViewModel
    @State private var scrollPosition = ScrollPosition(edge: .top)

    init(environment: AppEnvironment) {
        _viewModel = State(initialValue: TimelineViewModel(
            timeEntries: environment.timeEntries,
            appSessions: environment.appSessions,
            projects: environment.projects))
    }

    var body: some View {
        VStack(spacing: 0) {
            DayNavigationBar(viewModel: viewModel)
            Divider()
            ScrollView {
                TimelineColumn(viewModel: viewModel)
                    .padding(.bottom, 20)
                    .overlay(alignment: .top) { emptyState }
            }
            .scrollPosition($scrollPosition)
        }
        .task(id: viewModel.day) {
            scrollPosition.scrollTo(y: viewModel.geometry.y(for: viewModel.initialScrollDate))
            await viewModel.task()
        }
        .navigationTitle("Timeline")
    }

    @ViewBuilder private var emptyState: some View {
        if !viewModel.hasActivity {
            Text("No activity tracked yet")
                .foregroundStyle(.secondary)
                .padding(.top, viewModel.geometry.y(for: viewModel.initialScrollDate) + 120)
                .allowsHitTesting(false)
        }
    }
}

#Preview {
    TimelineScreen(environment: .preview()).frame(width: 800, height: 600)
}
