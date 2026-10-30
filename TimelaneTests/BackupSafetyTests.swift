import Testing
@testable import Timelane

struct BackupSafetyTests {
    let empty = BackupFixtures.info(projects: 0, entries: 0)
    let full = BackupFixtures.info(projects: 2, entries: 3)

    @Test func automaticEmptyNeverReplacesBackupWithData() {
        #expect(!BackupSafety.mayReplace(remote: full, with: empty, isAutomatic: true))
    }

    @Test func manualAlwaysMayReplace() {
        #expect(BackupSafety.mayReplace(remote: full, with: empty, isAutomatic: false))
    }

    @Test func withoutRemoteOrWithEmptyRemoteItMay() {
        #expect(BackupSafety.mayReplace(remote: nil, with: empty, isAutomatic: true))
        #expect(BackupSafety.mayReplace(remote: empty, with: empty, isAutomatic: true))
    }

    @Test func localDataMayAlwaysReplace() {
        #expect(BackupSafety.mayReplace(remote: full, with: full, isAutomatic: true))
    }
}
