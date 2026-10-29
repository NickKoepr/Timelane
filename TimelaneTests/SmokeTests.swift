import Testing
@testable import Timelane

struct SmokeTests {
    @Test func sidebarHasFourItems() {
        #expect(SidebarItem.allCases.count == 4)
    }
}
