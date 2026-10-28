import Foundation
import Testing
@testable import Timelane

@MainActor
final class LoggerFixture {
    let entries: GRDBTimeEntryRepository
    let trackedApps: GRDBTrackedAppRepository
    let projectId: Int64
    var clock = TestCalendar.date(2026, 11, 3, 9)
    lazy var logger = AutoTimeLogger(timeEntries: entries, trackedApps: trackedApps, now: { [self] in self.clock })

    /// "xcode" and "sim" are linked to the project, "safari" is tracked without a project.
    init() async throws {
        let database = try AppDatabase.inMemory()
        entries = GRDBTimeEntryRepository(database: database)
        trackedApps = GRDBTrackedAppRepository(database: database)
        projectId = try await GRDBProjectRepository(database: database).save(Project(name: "P", colorHex: "#FFFFFF")).id!
        try await trackedApps.add([TrackedApp(bundleIdentifier: "xcode", name: "Xcode", projectId: projectId),
                                   TrackedApp(bundleIdentifier: "sim", name: "Simulator", projectId: projectId),
                                   TrackedApp(bundleIdentifier: "safari", name: "Safari")])
        await logger.load()
    }

    func advance(seconds: TimeInterval) { clock = clock.addingTimeInterval(seconds) }
    func at(_ minutes: Double) -> Date { TestCalendar.date(2026, 11, 3, 9).addingTimeInterval(minutes * 60) }

    /// Moves the clock in 30 s steps, ticking each time, like the tracker's loop.
    func run(minutes: Double) async {
        for _ in 0..<Int(minutes * 2) { advance(seconds: 30); await logger.tick() }
    }

    func stored() async throws -> [TimeEntry] {
        try await entries.entries(in: .day(of: clock, calendar: TestCalendar.make()))
    }
}

@MainActor
struct AutoTimeLoggerTests {
    @Test func linkedAppActiveFiveMinutesGivesOneGrowingEntry() async throws {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 5)
        let all = try await f.stored()
        #expect(all.count == 1)
        #expect(all[0].projectId == f.projectId && all[0].start == f.at(0) && all[0].end == f.at(5))
        #expect(all[0].title == nil && all[0].note == nil)
    }

    @Test func sessionEndingAfter40SecondsCreatesNothing() async throws {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 0.5)
        f.advance(seconds: 10)
        await f.logger.sessionEnded(at: f.clock)
        #expect(try await f.stored().isEmpty)
    }

    @Test func sessionEndSetsEntryEndToThatMoment() async throws {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 7)                       // idle began at minute 4, detected at 7
        await f.logger.sessionEnded(at: f.at(4))
        let all = try await f.stored()
        #expect(all.count == 1 && all[0].end == f.at(4))
    }

    @Test func userDeletingTheEntryRestartsFromNextTick() async throws {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 2)
        let entry = try #require(try await f.stored().first)
        try await f.entries.save([], deleting: [entry.id!])
        f.advance(seconds: 30); await f.logger.tick()     // notices the deletion, restarts from now
        #expect(try await f.stored().isEmpty)
        let restart = f.clock
        await f.run(minutes: 2)
        let all = try await f.stored()
        #expect(all.count == 1 && all[0].start == restart && all[0].end == f.at(4.5))
    }

    @Test func userResizingTheEntryIsNeverGrownBack() async throws {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 3)
        var entry = try #require(try await f.stored().first)
        entry.end = f.at(2)
        try await f.entries.save([entry], deleting: [])
        await f.run(minutes: 0.5)
        #expect(try await f.stored().first?.end == f.at(2))
    }

    @Test func twoAppsOnSameProjectWithShortGapAreOneEntry() async throws {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 3)
        await f.logger.sessionEnded(at: f.clock)
        f.advance(seconds: 30)
        await f.logger.sessionStarted(bundleIdentifier: "sim", at: f.clock)
        await f.run(minutes: 2)
        let all = try await f.stored()
        #expect(all.count == 1 && all[0].start == f.at(0) && all[0].end == f.at(5.5))
    }

    @Test func unlinkedAppCreatesNoEntries() async throws {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "safari", at: f.clock)
        await f.run(minutes: 5)
        await f.logger.sessionEnded(at: f.clock)
        #expect(try await f.stored().isEmpty)
    }
}

@MainActor
struct AutoLogTrackerIntegrationTests {
    @Test func trackerWithAutoLoggerCreatesEntryAfterTicks() async throws {
        let f = try await LoggerFixture()
        let sessions = GRDBAppSessionRepository(database: try AppDatabase.inMemory())
        let tracker = AppActivityTracker(
            repository: sessions, trackedApps: f.trackedApps, heartbeat: FakeHeartbeat(), autoLogger: f.logger,
            now: { f.clock }, frontmostProvider: { ForegroundApp(bundleIdentifier: "xcode", name: "Xcode") })
        await tracker.start()
        f.advance(seconds: 120)
        await f.logger.tick()
        #expect(try await f.stored().map(\.end) == [f.at(2)])
        await tracker.stop()
        #expect(try await f.stored().count == 1)
    }
}
