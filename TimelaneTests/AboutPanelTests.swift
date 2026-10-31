import AppKit
import Testing
@testable import Timelane

struct AboutPanelTests {
    @Test func creditsLinkToWebsiteGitHubAndIssues() {
        let credits = AboutPanel.credits()
        var urls: [String] = []
        credits.enumerateAttribute(.link, in: NSRange(location: 0, length: credits.length)) { value, _, _ in
            if let url = value as? URL { urls.append(url.absoluteString) }
        }
        #expect(urls == [
            "https://timelane.nickkoepr.nl",
            "https://github.com/NickKoepr/Timelane",
            "https://github.com/NickKoepr/Timelane/issues",
        ])
        #expect(credits.string == "Website\nGitHub\nReport an issue")
    }
}
