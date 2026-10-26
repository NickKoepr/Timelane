import Foundation

@MainActor @Observable
final class TrackedAppsViewModel {
    private(set) var apps: [TrackedApp] = []
    /// False until the first list arrives, so the screen doesn't flash its empty state while loading.
    private(set) var isLoaded = false
    var selectedId: Int64?
    var errorMessage: String?

    private let repository: any TrackedAppRepository

    init(repository: any TrackedAppRepository) { self.repository = repository }

    func task() async {
        for await value in repository.observeTrackedApps() {
            apps = value
            isLoaded = true
        }
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
