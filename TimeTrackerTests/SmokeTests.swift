import Testing
@testable import TimeTracker

struct SmokeTests {
    @Test func sidebarHasThreeItems() {
        #expect(SidebarItem.allCases.count == 3)
    }
}
