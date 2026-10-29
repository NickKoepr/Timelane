import Foundation
import Testing
@testable import Timelane

@MainActor
struct AutoTimeLoggerRestartTests {
    /// Ticks every 5 s like the tracker's loop.
    private func tick(_ f: LoggerFixture, seconds: Double) async {
        for _ in 0..<Int(seconds / 5) { f.advance(seconds: 5); await f.logger.tick() }
    }

    @Test func restartContinuesTheEntry() async throws {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 3)
        await f.logger.sessionEnded(at: f.at(3))
        await f.restart()
        f.clock = f.at(3 + 10.0 / 60)
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 2)
        let all = try await f.stored()
        #expect(all.count == 1)
        #expect(all.first?.start == f.at(0) && all.first?.end == f.clock)
    }

    @Test func frequentRestartsNeverLoseTime() async throws {
        let f = try await LoggerFixture()
        for _ in 0..<10 {
            await f.restart()
            await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
            await tick(f, seconds: 40)
            await f.logger.sessionEnded(at: f.clock)
            f.advance(seconds: 5)
        }
        let all = try await f.stored()
        #expect(all.count == 1)
        #expect(all.first?.start == f.at(0) && all.first?.end == f.at(0).addingTimeInterval(9 * 45 + 40))
    }

    @Test func crashContinuesTheEntry() async throws {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 3)                       // killed here: no sessionEnded
        await f.restart()
        f.advance(seconds: 30)
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 2)
        let all = try await f.stored()
        #expect(all.count == 1 && all[0].start == f.at(0) && all[0].end == f.clock)
    }

    @Test func shortRunsOfTheSameProjectAddUp() async throws {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await tick(f, seconds: 40)
        await f.logger.sessionEnded(at: f.clock)
        await f.logger.sessionStarted(bundleIdentifier: "safari", at: f.clock)
        await tick(f, seconds: 20)
        await f.logger.sessionEnded(at: f.clock)
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await tick(f, seconds: 40)
        await f.logger.sessionEnded(at: f.clock)
        let all = try await f.stored()
        #expect(all.count == 1 && all[0].start == f.at(0) && all[0].end == f.at(100.0 / 60))
    }

    @Test func gapTooLargeDoesNotUseThePendingStart() async throws {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await tick(f, seconds: 40)
        await f.logger.sessionEnded(at: f.clock)
        f.advance(seconds: TrackingSettings.mergeGap + 1)
        let secondStart = f.clock
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: secondStart)
        await tick(f, seconds: 70)
        let all = try await f.stored()
        #expect(all.count == 1 && all[0].start == secondStart)
    }

    @Test func pendingRunOfAnotherProjectIsNotUsed() async throws {
        let f = try await LoggerFixture()
        let other = try await f.makeProject("Other")
        try await f.link("sim", to: other)
        await f.logger.load()                         // pick up the new link
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await tick(f, seconds: 40)
        await f.logger.sessionEnded(at: f.clock)
        let simStart = f.clock
        await f.logger.sessionStarted(bundleIdentifier: "sim", at: simStart)
        await tick(f, seconds: 70)
        let all = try await f.stored()
        #expect(all.count == 1 && all[0].projectId == other && all[0].start == simStart)
    }

    @Test func entryDeletedWhileClosedIsNotRecreated() async throws {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 3)
        await f.logger.sessionEnded(at: f.at(3))
        let id = try #require(try await f.stored().first?.id)
        _ = try await f.entries.save([], deleting: [id])
        await f.restart()
        f.advance(seconds: 10)
        let newStart = f.clock
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: newStart)
        await f.run(minutes: 2)
        let all = try await f.stored()
        #expect(all.count == 1 && all[0].start == newStart)
    }

    @Test func entryMovedWhileClosedIsLeftAlone() async throws {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 3)
        await f.logger.sessionEnded(at: f.at(3))
        var moved = try #require(try await f.stored().first)
        moved.start = f.at(-30)
        _ = try await f.entries.save([moved], deleting: [])
        await f.restart()
        f.advance(seconds: 10)
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 2)
        let all = try await f.stored().sorted { $0.start < $1.start }
        #expect(all.count == 2 && all[0].start == f.at(-30) && all[0].end == f.at(3))
    }

    // MARK: Returning to a linked app

    /// 2 minutes on xcode (entry exists), `away` seconds on safari, back on xcode.
    private func returnFixture(away: Double) async throws -> LoggerFixture {
        let f = try await LoggerFixture()
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        await f.run(minutes: 2)
        await f.logger.sessionEnded(at: f.clock)
        await f.logger.sessionStarted(bundleIdentifier: "safari", at: f.clock)
        f.advance(seconds: away)
        await f.logger.sessionEnded(at: f.clock)
        await f.logger.sessionStarted(bundleIdentifier: "xcode", at: f.clock)
        return f
    }

    @Test func returnWithinTheGapKeepsPaceFromTheFirstMoment() async throws {
        let f = try await returnFixture(away: 20)
        let id = try #require(try await f.stored().first?.id)
        #expect(f.live.entryId == id)                        // before any tick
        f.advance(seconds: 5)
        await f.logger.tick()
        let all = try await f.stored()
        #expect(all.count == 1 && all[0].end == f.clock)
    }

    @Test func shortReturnEndsTheEntryWhereTheSessionEnds() async throws {
        let f = try await returnFixture(away: 20)
        f.advance(seconds: 10)
        await f.logger.sessionEnded(at: f.clock)
        let all = try await f.stored()
        #expect(all.count == 1 && all[0].end == f.clock)
    }

    @Test func returnAfterALargerGapStartsANewEntryAfterAMinute() async throws {
        let f = try await returnFixture(away: TrackingSettings.mergeGap + 1)
        let first = try #require(try await f.stored().first)
        #expect(f.live.entryId == nil)
        await tick(f, seconds: 30)
        #expect(f.live.entryId == nil)
        await tick(f, seconds: 35)
        let all = try await f.stored().sorted { $0.start < $1.start }
        #expect(all.count == 2 && all[0] == first)
        #expect(f.live.entryId == all[1].id)
    }
}
