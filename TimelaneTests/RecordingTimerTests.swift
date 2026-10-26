import Foundation
import Testing
@testable import Timelane

@MainActor
struct RecordingTimerTests {
    let cal = TestCalendar.make()

    final class Clock { var now = TestCalendar.date(2026, 11, 3, 9, 0) }

    func makeTimer(_ clock: Clock, store: any RecordingTimerStore = InMemoryRecordingTimerStore()) -> RecordingTimer {
        RecordingTimer(store: store, calendar: cal, clock: { clock.now })
    }

    @Test func startStopProducesRoundedPeriod() throws {
        let clock = Clock()
        let timer = makeTimer(clock)
        #expect(!timer.isRunning)
        timer.start()
        clock.now = clock.now.addingTimeInterval(125)
        #expect(timer.elapsed(at: clock.now) == 125)
        let period = try #require(timer.stop())
        #expect(period.range == DateRange(start: TestCalendar.date(2026, 11, 3, 9, 0), end: TestCalendar.date(2026, 11, 3, 9, 3)))
        #expect(!timer.isRunning)
        #expect(timer.elapsed(at: clock.now) == 0)
    }

    @Test func startWhileRunningIsNoOp() {
        let clock = Clock()
        let timer = makeTimer(clock)
        timer.start()
        let first = timer.startedAt
        clock.now = clock.now.addingTimeInterval(60)
        timer.start()
        #expect(timer.startedAt == first)
    }

    @Test func stopWithoutStartIsNil() {
        #expect(makeTimer(Clock()).stop() == nil)
    }

    @Test func tooShortStopReturnsNilButStops() {
        let timer = makeTimer(Clock())
        timer.start()
        #expect(timer.stop() == nil)
        #expect(!timer.isRunning)
    }

    @Test func persistsAcrossInstancesAndClearsOnStop() throws {
        let clock = Clock()
        let defaults = UserDefaults(suiteName: "RecordingTimer-\(UUID())")!
        let store = UserDefaultsRecordingTimerStore(defaults: defaults)
        makeTimer(clock, store: store).start()
        clock.now = clock.now.addingTimeInterval(600)
        let restored = makeTimer(clock, store: UserDefaultsRecordingTimerStore(defaults: defaults))
        #expect(restored.isRunning)
        #expect(restored.elapsed(at: clock.now) == 600)
        _ = restored.stop()
        #expect(UserDefaultsRecordingTimerStore(defaults: defaults).startedAt == nil)
        #expect(!makeTimer(clock, store: store).isRunning)
    }
}
