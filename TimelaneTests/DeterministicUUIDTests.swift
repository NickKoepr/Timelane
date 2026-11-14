import Foundation
import Testing
@testable import Timelane

struct DeterministicUUIDTests {
    @Test func sameNameGivesSameUUID() {
        #expect(DeterministicUUID.make(from: "abc") == DeterministicUUID.make(from: "abc"))
        #expect(DeterministicUUID.make(from: "abc") != DeterministicUUID.make(from: "abd"))
    }

    @Test func knownValueIsStable() {
        #expect(DeterministicUUID.make(from: "timelane").uuidString == "4B132022-3669-599E-8734-B5FD41AA0C76")
    }

    @Test func versionAndVariantBitsAreSet() {
        for name in ["a", "b", "c", "parent:split:123.0", ""] {
            let text = Array(DeterministicUUID.make(from: name).uuidString)
            #expect(text[14] == "5")
            #expect(["8", "9", "A", "B"].contains(text[19]))
        }
    }
}
