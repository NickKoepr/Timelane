import Foundation
import Testing
@testable import Timelane

struct OnboardingStoreTests {
    @Test func defaultsToNotCompletedAndPersists() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = OnboardingStore(defaults: defaults)
        #expect(!store.hasCompleted)
        store.hasCompleted = true
        #expect(OnboardingStore(defaults: defaults).hasCompleted)
    }

    @Test func pagesAreNonEmptyWithUniqueIds() {
        let ids = OnboardingPage.all.map(\.id)
        #expect(!ids.isEmpty)
        #expect(Set(ids).count == ids.count)
    }

    @Test func pageTextsAreValidMarkdown() throws {
        for page in OnboardingPage.all {
            for text in [page.message, page.footnote].compactMap(\.self) {
                let rendered = try AttributedString(markdown: text)
                #expect(!String(rendered.characters).contains("**"), "Unparsed bold in \(page.id)")
            }
        }
    }
}

struct OnboardingPlatformTests {
    @Test func macPagesAreTheOriginalSix() {
        let ids = OnboardingPage.pages(for: .macOS).map(\.id)
        #expect(ids == ["welcome", "tracked-apps", "lanes", "register", "record", "more"])
    }

    @Test func iOSHasNoTrackingOrMenuBarPages() {
        let pages = OnboardingPage.pages(for: .iOS)
        #expect(pages.map(\.id) == ["welcome", "register-ios", "record-ios", "more-ios"])
        for page in pages {
            #expect(!page.message.contains("Tracked Apps"))
            #expect(!page.message.contains("menu bar"))
            #expect(!page.message.contains("⌘"))
        }
    }

    @Test func everyPageBelongsToAPlatform() {
        for page in OnboardingPage.all { #expect(!page.platforms.isEmpty) }
        #expect(OnboardingPage.forCurrentPlatform == OnboardingPage.pages(for: .current))
    }
}
