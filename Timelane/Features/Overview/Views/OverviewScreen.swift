import SwiftUI

struct OverviewScreen: View {
    @State private var viewModel: OverviewViewModel
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = State(initialValue: OverviewViewModel(
            timeEntries: environment.timeEntries, projects: environment.projects))
    }

    var body: some View {
        VStack(spacing: 0) {
            YearNavigationBar(
                title: viewModel.yearTitle,
                isCurrentYear: viewModel.isCurrentYear,
                projects: viewModel.projects,
                selectedProjectId: $viewModel.selectedProjectId,
                previous: viewModel.goToPreviousYear,
                next: viewModel.goToNextYear,
                current: viewModel.goToCurrentYear
            )
            Divider()
            if viewModel.isLoaded {
                ScrollView { content.padding() }
            } else {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task(id: viewModel.year) { await viewModel.task() }
        .errorAlert($viewModel.errorMessage)
        .navigationTitle("Overview")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(viewModel.heading).font(.title3.weight(.semibold))
            VStack(alignment: .heatmapTrailing, spacing: 8) {
                ActivityHeatmap(layout: viewModel.heatmapLayout, dailyTotals: viewModel.dailyTotals,
                                today: viewModel.now(), dayDetail: viewModel.dayDetail(for:),
                                onSelectDay: showTimeline)
                ActivityLegend()
            }
            .zIndex(1)   // the hover card hangs over the sections below
            if viewModel.hasHours {
                OverviewStatTiles(statistics: viewModel.statistics)
                section("Hours per month") {
                    OverviewMonthlyChart(year: viewModel.year, bars: viewModel.monthlyBars)
                }
                section("Projects") { OverviewProjectList(rows: viewModel.projectRows) }
            } else {
                ContentUnavailableView("No hours in \(viewModel.yearTitle)", systemImage: "square.grid.3x3",
                                       description: Text("Hours you register on the Timeline show up here."))
                    .frame(maxWidth: .infinity)   // centered, not at the leading edge of the stack
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }

    private func showTimeline(on day: Date) {
        environment.requestedTimelineDay = day
        environment.requestedSidebarItem = .timeline
    }
}

#Preview {
    OverviewScreen(environment: .preview()).frame(width: 800, height: 700)
}

#Preview("480") {
    OverviewScreen(environment: .preview()).frame(width: 480, height: 700)
}

#Preview("Empty") {
    OverviewScreen(environment: .inMemory()).frame(width: 800, height: 600)
}
