import Foundation
import Testing
@testable import Timelane

struct AutoLogStateStoreTests {
    private func withSuite(_ body: (UserDefaults) -> Void) {
        let name = "test-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        body(defaults)
        defaults.removePersistentDomain(forName: name)
    }

    @Test func roundTripsSubSecondDatesExactly() {
        withSuite { defaults in
            let base = Date(timeIntervalSinceReferenceDate: 783_000_000.123_456_7)
            let state = AutoLogState(entry: AutoLogEntry(id: 7, projectId: 3, start: base, lastEnd: base.addingTimeInterval(61.987_654)),
                                     pending: AutoLogPending(projectId: 3, start: base.addingTimeInterval(5.1), lastSeen: base.addingTimeInterval(9.77)))
            UserDefaultsAutoLogStateStore(defaults: defaults).state = state
            #expect(UserDefaultsAutoLogStateStore(defaults: defaults).state == state)
        }
    }

    @Test func garbageDecodesToEmptyState() {
        withSuite { defaults in
            defaults.set(Data("not json".utf8), forKey: "autoLogState")
            #expect(UserDefaultsAutoLogStateStore(defaults: defaults).state == AutoLogState())
        }
    }

    @Test func missingValueIsEmptyState() {
        withSuite { #expect(UserDefaultsAutoLogStateStore(defaults: $0).state == AutoLogState()) }
    }
}
