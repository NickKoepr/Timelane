import Foundation
import Testing
@testable import Timelane

struct DateSameInstantTests {
    @Test func withinOneMillisecondIsSameInstant() {
        let d = Date(timeIntervalSinceReferenceDate: 783_000_000.123)
        #expect(d.isSameInstant(as: d.addingTimeInterval(0.0005)))
        #expect(d.isSameInstant(as: d.addingTimeInterval(-0.0005)))
    }

    @Test func furtherApartIsNotSameInstant() {
        let d = Date(timeIntervalSinceReferenceDate: 783_000_000.123)
        #expect(!d.isSameInstant(as: d.addingTimeInterval(0.002)))
        #expect(!d.isSameInstant(as: d.addingTimeInterval(1)))
    }
}
