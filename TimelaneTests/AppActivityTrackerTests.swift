import Foundation
import Testing
@testable import Timelane

final class FakeHeartbeat: HeartbeatStore {
    var lastBeat: Date?
}

@MainActor
final class TrackerFixture {
    let repository: GRDBAppSessionRepository
    let trackedApps: GRDBTrackedAppRepository
    let heartbeat = FakeHeartbeat()
    var clock = TestCalendar.date(2026, 11, 3, 9)
    var frontmost: ForegroundApp? = ForegroundApp(bundleIdentifier: "xcode", name: "Xcode")
    lazy var tracker = AppActivityTracker(
        repository: repository, trackedApps: trackedApps, heartbeat: heartbeat,
        now: { [self] in self.clock }, frontmostProvider: { [self] in self.frontmost })

    /// Seeds the tracked list synchronously with `tracked` (default: the apps the tests use).
    init(tracked: [String] = ["xcode", "safari", "slack"]) throws {
        let database = try AppDatabase.inMemory()
        repository = GRDBAppSessionRepository(database: database)
        trackedApps = GRDBTrackedAppRepository(database: database)
        try database.writer.write { db in
            for id in tracked { var app = TrackedApp(bundleIdentifier: id, name: id.capitalized); try app.insert(db) }
        }
    }

    func advance(minutes: Int) { clock = clock.addingTimeInterval(TimeInterval(minutes * 60)) }

    func stored() async throws -> [AppSession] {
        try await repository.sessions(in: .day(of: clock, calendar: TestCalendar.make()))
    }
}

@MainActor
struct AppActivityTrackerTests {
    let app = { (id: String) in ForegroundApp(bundleIdentifier: id, name: id.capitalized) }

    @Test func startBeginsSessionForFrontmostApp() async throws {
        let f = try TrackerFixture()
        await f.tracker.start()
        let sessions = try await f.stored()
        #expect(sessions.count == 1)
        #expect(sessions[0].bundleIdentifier == "xcode")
        #expect(sessions[0].end == nil)
        await f.tracker.stop()
    }

    @Test func activatingAnotherAppClosesAndStartsSession() async throws {
        let f = try TrackerFixture()
        await f.tracker.start()
        f.advance(minutes: 10)
        await f.tracker.handle(.appActivated(app("safari")))
        let sessions = try await f.stored()
        #expect(sessions.map(\.bundleIdentifier) == ["xcode", "safari"])
        #expect(sessions[0].end == sessions[1].start)
        #expect(sessions[1].end == nil)
        await f.tracker.stop()
    }

    @Test func reactivatingSameAppDoesNotSplitSession() async throws {
        let f = try TrackerFixture()
        await f.tracker.start()
        f.advance(minutes: 5)
        await f.tracker.handle(.appActivated(app("xcode")))
        #expect(try await f.stored().count == 1)
        await f.tracker.stop()
    }

    @Test func pauseClosesSessionAndResumeStartsNewOne() async throws {
        let f = try TrackerFixture()
        await f.tracker.start()
        f.advance(minutes: 10)
        await f.tracker.handle(.paused(.locked))
        #expect(f.tracker.isPaused)
        f.advance(minutes: 30)
        f.frontmost = app("slack")
        await f.tracker.handle(.resumed(.locked))
        let sessions = try await f.stored()
        #expect(sessions.map(\.bundleIdentifier) == ["xcode", "slack"])
        #expect(sessions[0].end == TestCalendar.date(2026, 11, 3, 9, 10))
        #expect(sessions[1].start == TestCalendar.date(2026, 11, 3, 9, 40))
        await f.tracker.stop()
    }

    @Test func activationWhilePausedDoesNotStartSession() async throws {
        let f = try TrackerFixture()
        await f.tracker.start()
        await f.tracker.handle(.paused(.sleep))
        await f.tracker.handle(.appActivated(app("safari")))
        #expect(try await f.stored().filter { $0.end == nil }.isEmpty)
        #expect(f.tracker.currentApp?.bundleIdentifier == "safari")
        await f.tracker.stop()
    }

    @Test func resumesOnlyWhenAllPauseReasonsCleared() async throws {
        let f = try TrackerFixture()
        await f.tracker.start()
        await f.tracker.handle(.paused(.sleep))
        await f.tracker.handle(.paused(.idle))
        await f.tracker.handle(.resumed(.sleep))
        #expect(f.tracker.isPaused)
        #expect(try await f.stored().filter { $0.end == nil }.isEmpty)
        await f.tracker.handle(.resumed(.idle))
        #expect(!f.tracker.isPaused)
        #expect(try await f.stored().filter { $0.end == nil }.count == 1)
        await f.tracker.stop()
    }

    @Test func idlePauseEndsSessionAtLastInputTime() async throws {
        let f = try TrackerFixture()
        await f.tracker.start()
        f.advance(minutes: 20)
        let lastInput = TestCalendar.date(2026, 11, 3, 9, 12)
        await f.tracker.handle(.paused(.idle, at: lastInput))
        #expect(try await f.stored()[0].end == lastInput)
        await f.tracker.stop()
    }

    @Test func startClosesDanglingSessionsAtHeartbeat() async throws {
        let f = try TrackerFixture()
        _ = try await f.repository.start(AppSession(bundleIdentifier: "old", appName: "Old",
                                                     start: TestCalendar.date(2026, 11, 3, 7)))
        f.heartbeat.lastBeat = TestCalendar.date(2026, 11, 3, 8)
        await f.tracker.start()
        let sessions = try await f.stored()
        #expect(sessions[0].end == TestCalendar.date(2026, 11, 3, 8))
        #expect(sessions[1].bundleIdentifier == "xcode")
        await f.tracker.stop()
    }

    @Test func stopClosesOpenSession() async throws {
        let f = try TrackerFixture()
        await f.tracker.start()
        f.advance(minutes: 15)
        await f.tracker.stop()
        #expect(try await f.stored()[0].end == TestCalendar.date(2026, 11, 3, 9, 15))
    }
}
