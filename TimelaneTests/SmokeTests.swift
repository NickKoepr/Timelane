import Testing
@testable import Timelane

struct SmokeTests {
    @Test func sidebarHasThreeItems() {
        #expect(SidebarItem.allCases.count == 3)
    }
}
