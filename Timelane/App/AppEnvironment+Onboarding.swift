#if os(macOS)
import AppKit
#endif

extension AppEnvironment {
    /// Shows the welcome carousel on the main window (Help ▸ Welcome to Timelane).
    /// The caller makes sure the main window exists (see `OnboardingCommands`).
    func showOnboarding() {
        #if os(macOS)
        NSApp.activate()
        #endif
        isShowingOnboarding = true
    }

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(store: onboardingStore)
    }
}
