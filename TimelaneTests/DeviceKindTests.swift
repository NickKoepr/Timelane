import Testing
@testable import Timelane

struct DeviceKindTests {
    @Test func namesAreUserFacing() {
        #expect(DeviceKind.mac.noun == "Mac")
        #expect(DeviceKind.iPhone.thisDevice == "this iPhone")
        #expect(DeviceKind.iPad.thisDevice == "this iPad")
    }

    @Test func settingsAppNameDiffersOnTheMac() {
        #expect(DeviceKind.mac.systemSettingsName == "System Settings")
        #expect(DeviceKind.iPhone.systemSettingsName == "Settings")
    }

    @MainActor @Test func macTestsRunOnAMac() {
        #expect(DeviceKind.current == .mac)
    }
}
