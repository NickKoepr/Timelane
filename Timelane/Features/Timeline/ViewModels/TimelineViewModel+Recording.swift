import Foundation

extension TimelineViewModel {
    static let recordingTooShortMessage = "Recording too short to register."

    /// Record when idle; Stop opens the new-entry form with the recorded period (here, in this window).
    func toggleRecording() {
        guard recordingTimer.isRunning else {
            recordingTimer.start()
            return
        }
        guard let period = recordingTimer.stop() else {
            entryEditing.errorMessage = Self.recordingTooShortMessage
            return
        }
        register(period)
    }

    /// Shows the period's day, marks the range and opens the new-entry form for it.
    func register(_ period: RecordedPeriod) {
        show(.day(of: period.range.start, calendar: calendar))
        openNewForm(for: period.range)
        form?.notice = period.continuedPastMidnight ? RecordedPeriod.midnightNotice : nil
    }

    /// The live recording as a range on the shown day, or nil when none is running or it is not on this day.
    var recordingRange: DateRange? {
        guard let started = recordingTimer.startedAt, now > started else { return nil }
        return DateRange(start: started, end: now).intersection(with: day)
    }
}
