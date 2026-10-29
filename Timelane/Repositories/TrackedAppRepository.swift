import Foundation

protocol TrackedAppRepository: Sendable {
    /// All tracked apps, sorted by name.
    func observeTrackedApps() -> AsyncStream<[TrackedApp]>
    func trackedApps() async throws -> [TrackedApp]
    /// Apps that are already tracked (same bundle identifier) are ignored.
    func add(_ apps: [TrackedApp]) async throws
    func remove(id: Int64) async throws
    /// Links the app to a project (nil = no project).
    func setProject(_ projectId: Int64?, forAppId id: Int64) async throws
}
