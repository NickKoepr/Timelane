import Foundation

protocol AppSessionRepository: Sendable {
    func observeSessions(in range: DateRange) -> AsyncStream<[AppSession]>
    func sessions(in range: DateRange) async throws -> [AppSession]
    func start(_ session: AppSession) async throws -> AppSession
    func close(id: Int64, at end: Date) async throws
    /// Every app that has a stored session: distinct bundle identifier with its most recent name, sorted by name.
    func knownApps() async throws -> [ForegroundApp]
    /// Closes sessions that have no end (after a crash). `nil` closes each at start + 60s.
    func closeDanglingSessions(at end: Date?) async throws
}
