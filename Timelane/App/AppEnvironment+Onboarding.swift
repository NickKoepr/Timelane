import AppKit

extension AppEnvironment {
    /// Shows the welcome carousel on the main window (Help ▸ Welcome to Timelane).
    /// The caller makes sure the main window exists (see `OnboardingCommands`).
    func showOnboarding() {
        NSApp.activate()
        isShowingOnboarding = true
    }

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(store: onboardingStore)
    }
}
