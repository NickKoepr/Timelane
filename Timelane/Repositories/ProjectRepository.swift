import Foundation

protocol ProjectRepository: Sendable {
    func observeProjects(includeArchived: Bool) -> AsyncStream<[Project]>
    /// One-shot fetch of the projects, ordered by name.
    func projects(includeArchived: Bool) async throws -> [Project]
    /// All projects (archived too) with their clipped total in `range`. Callers decide what to hide.
    func monthTotals(in range: DateRange) async throws -> [ProjectMonthTotal]
    func observeMonthTotals(in range: DateRange) -> AsyncStream<[ProjectMonthTotal]>
    func save(_ project: Project) async throws -> Project
    func archive(id: Int64, archived: Bool) async throws
    /// Throws `RepositoryError.projectHasEntries` when the project has time entries.
    func delete(id: Int64) async throws
}
