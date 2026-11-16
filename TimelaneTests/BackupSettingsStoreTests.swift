import Foundation
import Testing
@testable import Timelane

@MainActor
struct BackupSettingsStoreTests {
    @Test func userDefaultsRoundTrip() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = UserDefaultsBackupSettingsStore(defaults: defaults)
        #expect(store.activityUploadedAt == nil)
        #expect(store.legacyCheckedAt == nil)

        let date = Date(timeIntervalSince1970: 12_345)
        store.activityUploadedAt = date
        store.legacyCheckedAt = date.addingTimeInterval(1)
        let reread = UserDefaultsBackupSettingsStore(defaults: defaults)
        #expect(reread.activityUploadedAt == date)
        #expect(reread.legacyCheckedAt == date.addingTimeInterval(1))

        store.activityUploadedAt = nil
        #expect(store.activityUploadedAt == nil)
    }

    @Test func legacyKeysAreReadAndRemoved() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: UserDefaultsBackupSettingsStore.legacyEnabledKey)
        defaults.set(Date(), forKey: UserDefaultsBackupSettingsStore.legacyLastBackupKey)
        let store = UserDefaultsBackupSettingsStore(defaults: defaults)
        #expect(store.legacyBackupEnabled)
        store.removeLegacyKeys()
        #expect(!store.legacyBackupEnabled)
        #expect(defaults.object(forKey: UserDefaultsBackupSettingsStore.legacyLastBackupKey) == nil)
    }
}
