import Testing
@testable import Timelane

struct ProjectCustomIdTests {
    @Test func trimsAndTurnsEmptyIntoNil() {
        #expect(ProjectCustomId.normalized("  ACME-042 \n") == "ACME-042")
        #expect(ProjectCustomId.normalized("") == nil)
        #expect(ProjectCustomId.normalized(" \t\n ") == nil)
        #expect(ProjectCustomId.normalized(nil) == nil)
    }

    @Test func keepsSpecialCharactersAndInnerSpaces() {
        #expect(ProjectCustomId.normalized("Intern #3") == "Intern #3")
        #expect(ProjectCustomId.normalized("P2026.17/β 🚀") == "P2026.17/β 🚀")
    }

    @Test func doesNotTruncate() {
        let long = String(repeating: "a", count: 100)
        #expect(ProjectCustomId.normalized(long) == long)
    }
}
