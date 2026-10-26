import Foundation

/// State of the "Add App" sheet: candidates, search, multi-selection and saving.
@MainActor @Observable
final class AddTrackedAppViewModel {
    var searchText = ""
    private(set) var candidates: [ForegroundApp] = []
    private(set) var selected: Set<String> = []
    private(set) var errorMessage: String?

    private let trackedApps: any TrackedAppRepository
    private let appSessions: any AppSessionRepository
    private let runningApps: () -> [ForegroundApp]
    private let ownBundleId: String?
    private let onFinish: () -> Void

    init(trackedApps: any TrackedAppRepository, appSessions: any AppSessionRepository,
         runningApps: @escaping () -> [ForegroundApp], ownBundleId: String? = Bundle.main.bundleIdentifier,
         onFinish: @escaping () -> Void) {
        self.trackedApps = trackedApps
        self.appSessions = appSessions
        self.runningApps = runningApps
        self.ownBundleId = ownBundleId
        self.onFinish = onFinish
    }

    var filtered: [ForegroundApp] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return candidates }
        return candidates.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.bundleIdentifier.localizedCaseInsensitiveContains(query) }
    }

    var canAdd: Bool { !selected.isEmpty }

    func load() async {
        do {
            let tracked = Set(try await trackedApps.trackedApps().map(\.bundleIdentifier))
            let known = try await appSessions.knownApps()
            candidates = AppCandidates.merge(running: runningApps(), known: known, tracked: tracked, ownBundleId: ownBundleId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isSelected(_ app: ForegroundApp) -> Bool { selected.contains(app.bundleIdentifier) }

    func toggle(_ app: ForegroundApp) {
        if selected.contains(app.bundleIdentifier) { selected.remove(app.bundleIdentifier) } else { selected.insert(app.bundleIdentifier) }
    }

    /// Apps picked in the open panel: shown in the list and selected (already tracked apps are ignored when saving).
    func include(_ apps: [ForegroundApp]) {
        let fresh = apps.filter { $0.bundleIdentifier != ownBundleId }
        candidates = AppCandidates.merge(running: fresh, known: candidates, tracked: [], ownBundleId: ownBundleId)
        selected.formUnion(fresh.map(\.bundleIdentifier))
    }

    func add() async {
        let apps = candidates.filter { selected.contains($0.bundleIdentifier) }
            .map { TrackedApp(bundleIdentifier: $0.bundleIdentifier, name: $0.name) }
        do {
            try await trackedApps.add(apps)
            onFinish()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancel() { onFinish() }
}
