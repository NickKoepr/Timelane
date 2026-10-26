import Foundation
import Testing
@testable import TimeTracker

struct AppSessionRepositoryTests {
    let sessions: GRDBAppSessionRepository
    let cal = TestCalendar.make()

    init() throws { sessions = GRDBAppSessionRepository(database: try AppDatabase.inMemory()) }

    func date(_ h: Int, _ min: Int = 0) -> Date { TestCalendar.date(2026, 11, 3, h, min, calendar: cal) }

    @Test func startAndCloseSession() async throws {
        let started = try await sessions.start(AppSession(bundleIdentifier: "com.apple.dt.Xcode", appName: "Xcode", start: date(9)))
        #expect(started.id != nil)
        try await sessions.close(id: started.id!, at: date(10))
        let day = try await sessions.sessions(in: .day(of: date(12), calendar: cal))
        #expect(day.count == 1)
        #expect(day[0].end == date(10))
    }

    @Test func openSessionIsIncludedInRange() async throws {
        _ = try await sessions.start(AppSession(bundleIdentifier: "a", appName: "A", start: date(9)))
        #expect(try await sessions.sessions(in: .day(of: date(12), calendar: cal)).count == 1)
    }

    @Test func danglingSessionsAreClosed() async throws {
        _ = try await sessions.start(AppSession(bundleIdentifier: "a", appName: "A", start: date(9)))
        _ = try await sessions.start(AppSession(bundleIdentifier: "b", appName: "B", start: date(11)))
        try await sessions.closeDanglingSessions(at: date(10))
        let all = try await sessions.sessions(in: .day(of: date(12), calendar: cal))
        #expect(all[0].end == date(10))
        #expect(all[1].end == date(11))   // never ends before it started
        try await sessions.closeDanglingSessions(at: nil)
    }
}
