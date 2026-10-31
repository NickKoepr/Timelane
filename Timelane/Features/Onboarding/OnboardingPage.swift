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
            message: "Add the apps you work in, like Xcode or your browser, under **Tracked Apps** (`⌘3`). "
                + "Timelane records when they're in the foreground and shows this on your timeline, "
                + "as a guide for logging your hours."),
        OnboardingPage(
            id: "lanes", icon: .symbol("rectangle.split.2x1"), title: "Two lanes, one day",
            message: "The left lane, **Tracked apps**, fills itself whenever a tracked app is in the foreground. "
                + "The right lane, **Logged hours**, shows the hours you've registered. "
                + "Only those count towards your projects."),
        OnboardingPage(
            id: "register", icon: .symbol("hand.draw"), title: "Log your hours",
            message: "**Drag** across the timeline to select a period, or **click** an app session "
                + "to select its whole duration. Choose a project, and the time is added to **Logged hours**."),
        OnboardingPage(
            id: "record", icon: .symbol("record.circle"), title: "Record, or let it log itself",
            message: "**Record** (`⌘R`) measures your time until you press **Stop**, then asks which project "
                + "it belongs to and adds it to **Logged hours**. You can also link a tracked app to a project "
                + "under **Tracked Apps**, so its time is logged automatically."),
        OnboardingPage(
            id: "more", icon: .symbol("chart.bar.xaxis"), title: "Your hours at a glance",
            message: "**Projects** shows your monthly totals and exports them. **Overview** shows your whole year. "
                + "And the **menu bar icon** keeps your timeline one click away.",
            footnote: "You can reopen this introduction via **Help ▸ Welcome to Timelane**."),
    ]
}
