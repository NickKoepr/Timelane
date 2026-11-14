import Foundation
import Testing
@testable import Timelane

struct BackupScheduleTests {
    let schedule = BackupSchedule.projectsAndHours
    let now = Date(timeIntervalSince1970: 100_000)

    @Test func notDirtyNeverRuns() {
        #expect(!schedule.shouldBackUp(now: now, isDirty: false, lastAttempt: nil))
    }

    @Test func firstTimeRunsImmediately() {
        #expect(schedule.shouldBackUp(now: now, isDirty: true, lastAttempt: nil))
    }

    @Test func waitsForTheMinimumInterval() {
        let recent = now.addingTimeInterval(-14 * 60)
        #expect(!schedule.shouldBackUp(now: now, isDirty: true, lastAttempt: recent))
    }

    @Test func runsAfterTheInterval() {
        let old = now.addingTimeInterval(-15 * 60)
        #expect(schedule.shouldBackUp(now: now, isDirty: true, lastAttempt: old))
    }

    @Test func appActivityWaitsAnHour() {
        let activity = BackupSchedule.appActivity
        #expect(!activity.shouldBackUp(now: now, isDirty: true, lastAttempt: now.addingTimeInterval(-59 * 60)))
        #expect(activity.shouldBackUp(now: now, isDirty: true, lastAttempt: now.addingTimeInterval(-60 * 60)))
    }
}
