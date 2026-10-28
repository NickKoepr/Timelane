import Foundation

@MainActor @Observable
final class TrackedAppsViewModel {
    private(set) var apps: [TrackedApp] = []
    /// False until the first list arrives, so the screen doesn't flash its empty state while loading.
    private(set) var isLoaded = false
    var selectedId: Int64?
    var errorMessage: String?

    /// All projects; archived ones are only offered for the app that is already linked to them.
    private(set) var projects: [Project] = []

    private let repository: any TrackedAppRepository
    private let projectRepository: any ProjectRepository

    init(repository: any TrackedAppRepository, projects: any ProjectRepository) {
        self.repository = repository
        self.projectRepository = projects
    }

    func task() async {
        await withDiscardingTaskGroup { group in
            group.addTask { await self.observeApps() }
            group.addTask { await self.observeProjects() }
        }
    }

    private func observeApps() async {
        for await value in repository.observeTrackedApps() {
            apps = value
            isLoaded = true
        }
    }

    private func observeProjects() async {
        for await value in projectRepository.observeProjects(includeArchived: true) { projects = value }
    }

    /// The choices for one row: active projects, plus the linked project when it is archived.
    func options(for app: TrackedApp) -> [Project] {
        projects.filter { !$0.isArchived || $0.id == app.projectId }
    }

    func setProject(_ projectId: Int64?, for app: TrackedApp) async {
        guard let id = app.id else { return }
        do { try await repository.setProject(projectId, forAppId: id) } catch { errorMessage = error.localizedDescription }
    }

    func remove(_ app: TrackedApp) async {
        guard let id = app.id else { return }
        do { try await repository.remove(id: id) } catch { errorMessage = error.localizedDescription }
        if selectedId == id { selectedId = nil }
    }

    func removeSelected() async {
        guard let app = apps.first(where: { $0.id == selectedId }) else { return }
        await remove(app)
    }
}
