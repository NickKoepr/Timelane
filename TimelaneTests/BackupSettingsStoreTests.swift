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
        #expect(!store.isEnabled)
        #expect(store.lastBackupAt == nil)

        let date = Date(timeIntervalSince1970: 12_345)
        store.isEnabled = true
        store.lastBackupAt = date
        let reread = UserDefaultsBackupSettingsStore(defaults: defaults)
        #expect(reread.isEnabled)
        #expect(reread.lastBackupAt == date)

        store.lastBackupAt = nil
        #expect(store.lastBackupAt == nil)
    }
}
