import Foundation

/// The one Record/Stop timer of the app, shared by the main window and the menu bar panel.
/// The start time is persisted, so the timer keeps running across window closes and relaunches.
@MainActor @Observable
final class RecordingTimer {
    private(set) var startedAt: Date?
    var isRunning: Bool { startedAt != nil }

    private let store: any RecordingTimerStore
    private let calendar: Calendar, clock: () -> Date

    init(store: any RecordingTimerStore = InMemoryRecordingTimerStore(), calendar: Calendar = .current,
         clock: @escaping () -> Date = { .now }) {
        self.store = store
        self.calendar = calendar
        self.clock = clock
        self.startedAt = store.startedAt
    }

    func elapsed(at now: Date) -> TimeInterval {
        startedAt.map { max(now.timeIntervalSince($0), 0) } ?? 0
    }

    /// Starts at "now"; does nothing while running.
    func start() {
        guard startedAt == nil else { return }
        let now = clock()
        startedAt = now
        store.startedAt = now
    }

    /// Ends at "now" and clears the timer. nil when nothing ran or the period is under a minute even rounded.
    func stop() -> RecordedPeriod? {
        guard let started = startedAt else { return nil }
        startedAt = nil
        store.startedAt = nil
        return RecordedPeriod(start: started, end: clock(), calendar: calendar)
    }
}
