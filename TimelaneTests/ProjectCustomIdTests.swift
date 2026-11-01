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

    @Test func shortensLongIdsForDisplay() {
        #expect(ProjectCustomId.shortened("ACME-042") == "ACME-042")
        #expect(ProjectCustomId.shortened(String(repeating: "a", count: 20)) == String(repeating: "a", count: 20))
        #expect(ProjectCustomId.shortened(String(repeating: "a", count: 21)) == String(repeating: "a", count: 20) + "…")
    }

    @Test func shortTitleShortensOnlyTheId() {
        let project = Project(name: "Website", colorHex: "#4F8EF7", customId: String(repeating: "x", count: 30))
        #expect(project.shortTitleWithCustomId == "Website (\(String(repeating: "x", count: 20))…)")
        #expect(project.titleWithCustomId == "Website (\(String(repeating: "x", count: 30)))")
    }
}
