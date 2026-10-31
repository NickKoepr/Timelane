import Foundation
import Testing
@testable import Timelane

@MainActor
struct OnboardingViewModelTests {
    private func makeStore() -> (OnboardingStore, () -> Void) {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        return (OnboardingStore(defaults: defaults), { defaults.removePersistentDomain(forName: name) })
    }

    @Test func navigationClampsAtBothEnds() {
        let (store, cleanup) = makeStore()
        defer { cleanup() }
        let model = OnboardingViewModel(store: store)
        #expect(model.isFirst && !model.isLast)
        model.back()
        #expect(model.currentIndex == 0)
        for _ in 0..<(model.pages.count + 3) { model.next() }
        #expect(model.currentIndex == model.pages.count - 1)
        #expect(model.isLast && !model.isFirst)
        model.back()
        #expect(model.currentIndex == model.pages.count - 2)
    }

    @Test func goToIgnoresOutOfRangeIndices() {
        let (store, cleanup) = makeStore()
        defer { cleanup() }
        let model = OnboardingViewModel(store: store)
        model.go(to: 2)
        #expect(model.currentIndex == 2)
        model.go(to: -1)
        model.go(to: model.pages.count)
        #expect(model.currentIndex == 2)
    }

    @Test func finishMarksOnboardingCompleted() {
        let (store, cleanup) = makeStore()
        defer { cleanup() }
        let model = OnboardingViewModel(store: store)
        #expect(!store.hasCompleted)
        model.finish()
        #expect(store.hasCompleted)
    }

    @Test func isolatedEnvironmentsDoNotShowOnboarding() {
        #expect(!AppEnvironment.inMemory().isShowingOnboarding)
        #expect(!AppEnvironment.preview().isShowingOnboarding)
    }
}
