import Foundation
import Testing
@testable import Timelane

struct OnboardingStoreTests {
    @Test func defaultsToNotCompletedAndPersists() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = OnboardingStore(defaults: defaults)
        #expect(!store.hasCompleted)
        store.hasCompleted = true
        #expect(OnboardingStore(defaults: defaults).hasCompleted)
    }

    @Test func pagesAreNonEmptyWithUniqueIds() {
        let ids = OnboardingPage.all.map(\.id)
        #expect(!ids.isEmpty)
        #expect(Set(ids).count == ids.count)
    }
}
