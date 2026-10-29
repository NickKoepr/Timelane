import Foundation
import Testing
@testable import Timelane

@MainActor
final class LoggerFixture {
    let database: AppDatabase
    let entries: GRDBTimeEntryRepository
    let trackedApps: GRDBTrackedAppRepository
    let projectId: Int64
    let store = InMemoryAutoLogStateStore()
    var clock = TestCalendar.date(2026, 11, 3, 9)
    let live = LiveAutoEntry()
    lazy var logger = AutoTimeLogger(timeEntries: entries, trackedApps: trackedApps, store: store, live: live, now: { [self] in self.clock })

    /// "xcode" and "sim" are linked to the project, "safari" is tracked without a project.
    init() async throws {
        database = try AppDatabase.inMemory()
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

    /// Simulates quitting and relaunching Timelane: a new logger on the same database (and store).
    func restart() async {
        logger = AutoTimeLogger(timeEntries: entries, trackedApps: trackedApps, store: store, live: live, now: { [self] in self.clock })
        await logger.load()
    }

    func makeProject(_ name: String) async throws -> Int64 {
        try await GRDBProjectRepository(database: database).save(Project(name: name, colorHex: "#FFFFFF")).id!
    }

    /// Changes the link and gives the logger's observer time to react.
    func link(_ bundleId: String, to projectId: Int64?) async throws {
        let app = try #require(try await trackedApps.trackedApps().first { $0.bundleIdentifier == bundleId })
        try await trackedApps.setProject(projectId, forAppId: app.id!)
        try await Task.sleep(for: .milliseconds(150))
    }

    func stored() async throws -> [TimeEntry] {
        try await entries.entries(in: .day(of: clock, calendar: TestCalendar.make()))
    }
}

@MainActor
struct AutoTimeLoggerTests {
    /// Real clocks have sub-second dates, which often change by an ULP in the database (stored as Unix Double).
    /// The logger must not lose its own entry because of that.
    @Test func subSecondDatesDoNotBreakTheRun() async throws {
        let f = try await LoggerFixture()
        let base = Date(timeIntervalSinceReferenceDate: 783_000_000.123_456_7)
        let start = try #require((0..<200).lazy.map { base.addingTimeInterval(Double($0) * 0.0137) }
            .first { Date(timeIntervalSince1970: $0.timeIntervalSince1970) != $0 }, "need a date that does not round-trip")
        f.clock = start
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: start)
        for offset in [60.0, 65, 120] {
            f.clock = start.addingTimeInterval(offset)
            await f.logger.tick()
        }
        var all = try await f.entries.entries(in: DateRange(start: start.addingTimeInterval(-60), end: start.addingTimeInterval(600)))
        #expect(all.count == 1)
        #expect(all[0].start.isSameInstant(as: start) && all[0].end.isSameInstant(as: start.addingTimeInterval(120)))
        f.clock = start.addingTimeInterval(150)
        await f.logger.sessionEnded(at: f.clock)
        all = try await f.entries.entries(in: DateRange(start: start.addingTimeInterval(-60), end: start.addingTimeInterval(600)))
        #expect(all.count == 1 && all[0].end.isSameInstant(as: start.addingTimeInterval(150)))
    }

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

    @Test func idleWithinFirstMinuteOfRunLeavesNoEntry() async throws {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 5)                       // entry grew while the user was away
        await f.logger.sessionEnded(at: f.at(0.5))
        #expect(try await f.stored().isEmpty)
    }

    @Test func idleAfterThreeMinutesShrinksEntryToThatMoment() async throws {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 5)
        await f.logger.sessionEnded(at: f.at(3))
        #expect(try await f.stored().map(\.end) == [f.at(3)])
    }

    @Test func idleOnMergedEntryOnlyRemovesTimeOfTheLastRun() async throws {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 3)
        await f.logger.sessionEnded(at: f.clock)
        f.advance(seconds: 30)
        await f.logger.sessionStarted(bundleIdentifier: "sim", at: f.clock)   // run starts at 3.5
        await f.run(minutes: 3)
        await f.logger.sessionEnded(at: f.at(4))                              // idle began at 4
        let all = try await f.stored()
        #expect(all.count == 1 && all[0].start == f.at(0) && all[0].end == f.at(4))
    }

    // MARK: Links only affect new hours

    @Test func ownersExampleTenMinutesOnAThenTenOnB() async throws {
        let f = try await LoggerFixture()
        let b = try await f.makeProject("B")
        let observer = Task { await f.logger.observe() }
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 10)
        let before = try #require(try await f.stored().first)
        try await f.link("xcode", to: b)
        await f.run(minutes: 10)
        let all = try await f.stored().sorted { $0.start < $1.start }
        #expect(all.count == 2)
        #expect(all[0] == before && all[0].projectId == f.projectId && all[0].start == f.at(0) && all[0].end == f.at(10))
        #expect(all[1].projectId == b && all[1].start == f.at(10) && all[1].end == f.at(20))
        observer.cancel()
    }

    @Test func linkChangeWhileAppIsNotActiveKeepsOldEntries() async throws {
        let f = try await LoggerFixture()
        let b = try await f.makeProject("B")
        let observer = Task { await f.logger.observe() }
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 4)
        await f.logger.sessionEnded(at: f.clock)
        let before = try await f.stored()
        try await f.link("xcode", to: b)
        #expect(try await f.stored() == before)
        f.advance(seconds: 600)
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 2)
        let all = try await f.stored().sorted { $0.start < $1.start }
        #expect(all.map(\.projectId) == [f.projectId, b])
        #expect(all[0] == before[0])
        observer.cancel()
    }

    @Test func switchingLinkAToBToAKeepsSeparateEntries() async throws {
        let f = try await LoggerFixture()
        let b = try await f.makeProject("B")
        let observer = Task { await f.logger.observe() }
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 3)
        try await f.link("xcode", to: b)
        await f.run(minutes: 1.5)
        try await f.link("xcode", to: f.projectId)
        await f.run(minutes: 2)
        let all = try await f.stored().sorted { $0.start < $1.start }
        #expect(all.map(\.projectId) == [f.projectId, b, f.projectId])
        #expect(all[0].end == f.at(3) && all[1].start == f.at(3) && all[1].end == f.at(4.5))
        observer.cancel()
    }

    @Test func unlinkingOrRemovingTheAppKeepsExistingEntries() async throws {
        let f = try await LoggerFixture()
        let observer = Task { await f.logger.observe() }
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 4)
        let before = try await f.stored()
        try await f.link("xcode", to: nil)
        await f.run(minutes: 2)
        #expect(try await f.stored() == before)
        let id = try #require(try await f.trackedApps.trackedApps().first { $0.bundleIdentifier == "xcode" }?.id)
        try await f.trackedApps.remove(id: id)
        try await Task.sleep(for: .milliseconds(100))
        #expect(try await f.stored() == before)
        observer.cancel()
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

@MainActor
struct AutoTimeLoggerLiveEntryTests {
    @Test func publishesTheRunningEntryAndClearsItAtTheEnd() async throws {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        #expect(f.live.entryId == nil)
        await f.run(minutes: 0.5)
        #expect(f.live.entryId == nil)                       // not written yet
        await f.run(minutes: 1)
        let id = try #require(try await f.stored().first?.id)
        #expect(f.live.entryId == id)
        await f.run(minutes: 1)
        #expect(f.live.entryId == id)                        // kept while extending
        await f.logger.sessionEnded(at: f.clock)
        #expect(f.live.entryId == nil)
    }

    @Test func continuingAnEarlierEntryAcrossAGapPublishesIt() async throws {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 3)
        let id = try #require(try await f.stored().first?.id)
        await f.logger.sessionEnded(at: f.clock)
        f.advance(seconds: 60)
        await f.logger.sessionStarted(bundleIdentifier: "sim", at: f.clock)
        #expect(f.live.entryId == nil)
        await f.run(minutes: 1)
        #expect(f.live.entryId == id)
    }

    @Test func userDeletingTheEntryClearsIt() async throws {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 2)
        let entry = try #require(try await f.stored().first)
        #expect(f.live.entryId == entry.id)
        try await f.entries.save([], deleting: [entry.id!])
        f.advance(seconds: 30); await f.logger.tick()
        #expect(f.live.entryId == nil)
    }

    @Test func linkChangeClearsIt() async throws {
        let f = try await LoggerFixture()
        let observer = Task { await f.logger.observe() }
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 2)
        #expect(f.live.entryId != nil)
        try await f.link("xcode", to: nil)
        #expect(f.live.entryId == nil)
        observer.cancel()
    }
}
