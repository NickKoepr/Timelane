import Foundation
import Testing
@testable import Timelane

struct BackupScheduleTests {
    let schedule = BackupSchedule()
    let now = Date(timeIntervalSince1970: 100_000)

    @Test func disabledNeverRuns() {
        #expect(!schedule.shouldBackUp(now: now, isEnabled: false, isDirty: true, lastAttempt: nil))
    }

    @Test func notDirtyNeverRuns() {
        #expect(!schedule.shouldBackUp(now: now, isEnabled: true, isDirty: false, lastAttempt: nil))
    }

    @Test func firstTimeRunsImmediately() {
        #expect(schedule.shouldBackUp(now: now, isEnabled: true, isDirty: true, lastAttempt: nil))
    }

    @Test func waitsForTheMinimumInterval() {
        let recent = now.addingTimeInterval(-14 * 60)
        #expect(!schedule.shouldBackUp(now: now, isEnabled: true, isDirty: true, lastAttempt: recent))
    }

    @Test func runsAfterTheInterval() {
        let old = now.addingTimeInterval(-15 * 60)
        #expect(schedule.shouldBackUp(now: now, isEnabled: true, isDirty: true, lastAttempt: old))
    }
}
