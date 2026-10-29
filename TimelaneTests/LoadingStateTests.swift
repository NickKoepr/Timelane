import Foundation
import Testing
@testable import Timelane

/// Screens show their empty state only after the first data arrived, so they don't flash it while loading.
@MainActor
struct LoadingStateTests {
    func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() { try? await Task.sleep(for: .milliseconds(10)) }
    }

    @Test func trackedAppsIsLoadedAfterFirstList() async throws {
        let repository = GRDBTrackedAppRepository(database: try AppDatabase.inMemory())
        let viewModel = TrackedAppsViewModel(repository: repository, projects: GRDBProjectRepository(database: try AppDatabase.inMemory()))
        #expect(!viewModel.isLoaded)

        let task = Task { await viewModel.task() }
        await waitUntil { viewModel.isLoaded }
        task.cancel()

        #expect(viewModel.isLoaded && viewModel.apps.isEmpty)
    }

    @Test func projectsIsLoadedAfterFirstTotals() async throws {
        let repository = GRDBProjectRepository(database: try AppDatabase.inMemory())
        let viewModel = ProjectsViewModel(repository: repository)
        #expect(!viewModel.isLoaded)

        let task = Task { await viewModel.task() }
        await waitUntil { viewModel.isLoaded }
        task.cancel()

        #expect(viewModel.isLoaded && viewModel.rows.isEmpty)
    }
}
