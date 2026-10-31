import Foundation

/// Drives the welcome carousel: which page is shown, and remembering that it has been seen.
@MainActor @Observable
final class OnboardingViewModel {
    let pages: [OnboardingPage]
    private(set) var currentIndex = 0
    private let store: OnboardingStore

    init(pages: [OnboardingPage] = OnboardingPage.all, store: OnboardingStore) {
        self.pages = pages
        self.store = store
    }

    var currentPage: OnboardingPage { pages[currentIndex] }
    var isFirst: Bool { currentIndex == 0 }
    var isLast: Bool { currentIndex == pages.count - 1 }

    func next() { go(to: currentIndex + 1) }
    func back() { go(to: currentIndex - 1) }

    /// Out-of-range indices are ignored.
    func go(to index: Int) {
        guard pages.indices.contains(index) else { return }
        currentIndex = index
    }

    /// Called when the carousel closes in any way; it never reappears on its own afterwards.
    func finish() { store.hasCompleted = true }
}
