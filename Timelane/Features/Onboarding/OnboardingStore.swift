import Foundation

/// Remembers whether the welcome carousel has been completed (or dismissed), so it only shows once on its own.
struct OnboardingStore {
    private let key = "hasCompletedOnboarding"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// A store backed by a throw-away suite: tests, previews and screenshot mode never touch the real defaults.
    static func temporary() -> OnboardingStore {
        OnboardingStore(defaults: UserDefaults(suiteName: "onboarding-" + UUID().uuidString) ?? .standard)
    }

    var hasCompleted: Bool {
        get { defaults.bool(forKey: key) }
        nonmutating set { defaults.set(newValue, forKey: key) }
    }
}
