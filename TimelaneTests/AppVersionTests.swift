import Testing
@testable import Timelane

struct AppVersionTests {
    @Test func combinesVersionAndBuild() {
        #expect(AppVersion.display(short: "1.9", build: "12") == "1.9 (12)")
        #expect(AppVersion.display(short: "1.9", build: nil) == "1.9")
        #expect(AppVersion.display(short: nil, build: "12") == "(12)")
        #expect(AppVersion.display(short: nil, build: nil) == "–")
    }
}
