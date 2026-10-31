import Foundation

/// One page of the welcome carousel.
struct OnboardingPage: Identifiable, Equatable {
    let id: String
    let systemImage: String
    let title: String
    let message: String

    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: "welcome", systemImage: "clock.badge.checkmark", title: "Welcome to Timelane",
            message: "Register your working hours per project, right on your Mac. Everything stays on this Mac."),
        OnboardingPage(
            id: "tracked-apps", systemImage: "app.badge.checkmark", title: "Choose which apps to track",
            message: "Add apps (Xcode, your browser, …) under Tracked Apps (⌘3). Only those apps are recorded; "
                + "tracking pauses when you're idle, asleep or locked."),
        OnboardingPage(
            id: "lanes", systemImage: "rectangle.split.2x1", title: "Two lanes",
            message: "The left lane, Tracked apps, fills itself while you work. The right lane, Logged hours, holds "
                + "the hours that count. Tracked time is not registered until it is in Logged hours."),
        OnboardingPage(
            id: "register", systemImage: "hand.draw", title: "Register your hours",
            message: "Drag over the timeline to select a period, or click an app session to take it over, then pick a "
                + "project. New entries always land in Logged hours; drag or resize them there to adjust. "
                + "Or press Record (⌘R) and Stop when you're done. "
                + "Tip: link a tracked app to a project and its hours are logged automatically."),
        OnboardingPage(
            id: "more", systemImage: "chart.bar.xaxis", title: "Projects, overview and menu bar",
            message: "See monthly totals and export them under Projects, your year under Overview, and keep an eye on "
                + "everything from the menu bar icon. Reopen this introduction via Help ▸ Welcome to Timelane."),
    ]
}
