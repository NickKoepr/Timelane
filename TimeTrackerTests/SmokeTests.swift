import Testing
@testable import TimeTracker

struct SmokeTests {
    @Test func sidebarHasTwoItems() {
        #expect(SidebarItem.allCases.count == 2)
    }
}
