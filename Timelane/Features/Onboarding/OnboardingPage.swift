import Foundation

/// One page of the welcome carousel. `message` and `footnote` are Markdown (`**bold**`, `` `⌘R` ``).
struct OnboardingPage: Identifiable, Equatable {
    enum Icon: Equatable {
        case symbol(String)
        /// The clock from the app icon (`ClockMark` asset, from `Tools/generate-app-icon.swift`).
        case appClock
    }

    /// The platforms a page is shown on: the Mac app has tracking and a menu bar, iOS only the logged-hours timeline.
    enum Platform: Equatable, Sendable {
        case macOS, iOS

        static var current: Platform {
            #if os(macOS)
            .macOS
            #else
            .iOS
            #endif
        }
    }

    let id: String
    let icon: Icon
    let title: String
    let message: String
    var footnote: String?
    var platforms: Set<Platform> = [.macOS, .iOS]

    /// The pages for one platform, in order.
    static func pages(for platform: Platform) -> [OnboardingPage] {
        all.filter { $0.platforms.contains(platform) }
    }

    /// The pages of the platform the app runs on.
    static var forCurrentPlatform: [OnboardingPage] { pages(for: .current) }

    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: "welcome", icon: .appClock, title: "Welcome to Timelane",
            message: "See where your working day went, and turn it into **hours per project** in seconds. "
                + "No timers to forget, no guesswork at the end of the week."),
        OnboardingPage(
            id: "tracked-apps", icon: .symbol("app.badge.checkmark"), title: "Choose the apps you work in",
            message: "Add the apps you work in, like Xcode or your browser, under **Tracked Apps** (`⌘3`). "
                + "Timelane records when they're in the foreground and shows this on your timeline, "
                + "as a guide for logging your hours.",
            platforms: [.macOS]),
        OnboardingPage(
            id: "lanes", icon: .symbol("rectangle.split.2x1"), title: "Two lanes, one day",
            message: "The left lane, **Tracked apps**, fills itself whenever a tracked app is in the foreground. "
                + "The right lane, **Logged hours**, shows the hours you've registered. "
                + "Only those count towards your projects.",
            platforms: [.macOS]),
        OnboardingPage(
            id: "register", icon: .symbol("hand.draw"), title: "Log your hours",
            message: "**Drag** across the timeline to select a period, or **click** an app session "
                + "to select its whole duration. Choose a project, and the time is added to **Logged hours**.",
            platforms: [.macOS]),
        OnboardingPage(
            id: "record", icon: .symbol("record.circle"), title: "Record, or let it log itself",
            message: "**Record** (`⌘R`) measures your time until you press **Stop**, then asks which project "
                + "it belongs to and adds it to **Logged hours**. You can also link a tracked app to a project "
                + "under **Tracked Apps**, so its time is logged automatically.",
            platforms: [.macOS]),
        OnboardingPage(
            id: "more", icon: .symbol("chart.bar.xaxis"), title: "Your hours at a glance",
            message: "**Projects** shows your monthly totals and exports them. **Overview** shows your whole year. "
                + "And the **menu bar icon** keeps your timeline one click away.",
            footnote: "You can reopen this introduction via **Help ▸ Welcome to Timelane**.",
            platforms: [.macOS]),
        OnboardingPage(
            id: "register-ios", icon: .symbol("hand.tap"), title: "Log your hours",
            message: "**Tap** an empty spot on the timeline to add an entry, or **touch and hold**, then drag to select a period. "
                + "Choose a project, and the time is added to **Logged hours**. Tap an entry to edit or delete it.",
            platforms: [.iOS]),
        OnboardingPage(
            id: "record-ios", icon: .symbol("record.circle"), title: "Record your time",
            message: "**Record** measures your time until you press **Stop**, then asks which project it belongs to. "
                + "Pinch the timeline to zoom in for exact times.",
            platforms: [.iOS]),
        OnboardingPage(
            id: "more-ios", icon: .symbol("chart.bar.xaxis"), title: "Your hours at a glance",
            message: "**Projects** shows your monthly totals and exports them. **Overview** shows your whole year. "
                + "Turn on **iCloud Sync** in Settings to keep your hours in step with your Mac.",
            footnote: "You can replay this introduction in **Settings**.",
            platforms: [.iOS]),
    ]
}
