import Foundation

/// One page of the welcome carousel. `message` and `footnote` are Markdown (`**bold**`, `` `⌘R` ``).
struct OnboardingPage: Identifiable, Equatable {
    enum Icon: Equatable {
        case symbol(String)
        /// The clock from the app icon (`OnboardingClockMark`).
        case appClock
    }

    let id: String
    let icon: Icon
    let title: String
    let message: String
    var footnote: String?

    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: "welcome", icon: .appClock, title: "Welcome to Timelane",
            message: "See where your working day went, and turn it into **hours per project** in seconds. "
                + "No timers to forget, no guesswork at the end of the week."),
        OnboardingPage(
            id: "tracked-apps", icon: .symbol("app.badge.checkmark"), title: "Choose the apps you work in",
            message: "Add apps like Xcode or your browser under **Tracked Apps** (`⌘3`). "
                + "Only these apps are recorded, so start here: without them, your timeline stays empty."),
        OnboardingPage(
            id: "lanes", icon: .symbol("rectangle.split.2x1"), title: "Two lanes, one day",
            message: "The left lane, **Tracked apps**, fills itself whenever a tracked app is in the foreground. "
                + "The right lane, **Logged hours**, shows the hours you've registered. "
                + "Only those count towards your projects."),
        OnboardingPage(
            id: "register", icon: .symbol("hand.draw"), title: "Log your hours",
            message: "**Drag** across the timeline to select a period, or **click** an app session to take it over. "
                + "Pick a project, and the hours appear in **Logged hours**."),
        OnboardingPage(
            id: "record", icon: .symbol("record.circle"), title: "Record, or let it log itself",
            message: "Press **Record** (`⌘R`) when you start and **Stop** when you're done. "
                + "Or link a tracked app to a project under **Tracked Apps**: its hours are then logged automatically."),
        OnboardingPage(
            id: "more", icon: .symbol("chart.bar.xaxis"), title: "Your hours at a glance",
            message: "**Projects** shows your monthly totals and exports them. **Overview** shows your whole year. "
                + "And the **menu bar icon** keeps your timeline one click away.",
            footnote: "You can reopen this introduction via **Help ▸ Welcome to Timelane**."),
    ]
}
