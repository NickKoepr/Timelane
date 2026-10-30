#if DEBUG
import Foundation

/// Sample data for the App Store screenshots: an app developer's year. Pure: the same `today` gives the same data.
struct ScreenshotSampleData: Sendable {
    let projects: [Project]
    let trackedApps: [TrackedApp]
    let entries: [TimeEntry]
    let sessions: [AppSession]
    /// The day the Timeline and menu bar screenshots show: the last weekday before `today`.
    let showcaseDay: Date
    /// The unlogged Xcode session at the end of the showcase day; the entry form screenshot registers it.
    let unloggedRange: DateRange

    enum ProjectID {
        static let fitness: Int64 = 1, portal: Int64 = 2, design: Int64 = 3, api: Int64 = 4
        static let planning: Int64 = 5, support: Int64 = 6, android: Int64 = 7
    }

    init(today: Date = .now, calendar: Calendar = .current) {
        let start = calendar.startOfDay(for: today)
        var showcase = calendar.date(byAdding: .day, value: -1, to: start)!
        while calendar.isDateInWeekend(showcase) { showcase = calendar.date(byAdding: .day, value: -1, to: showcase)! }
        showcaseDay = showcase
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: start))!
        let created = calendar.date(byAdding: .day, value: -10, to: yearStart)!

        projects = [
            Project(id: ProjectID.fitness, name: "Fitness Tracker iOS", colorHex: "#4F8EF7", createdAt: created),
            Project(id: ProjectID.portal, name: "Client Portal", colorHex: "#FF9500", createdAt: created),
            Project(id: ProjectID.design, name: "Design System", colorHex: "#AF52DE", createdAt: created),
            Project(id: ProjectID.api, name: "Sync API", colorHex: "#34C759", createdAt: created),
            Project(id: ProjectID.planning, name: "Planning & Meetings", colorHex: "#30B0C7", createdAt: created),
            Project(id: ProjectID.support, name: "Bugfixes & Support", colorHex: "#FF2D55", createdAt: created),
            Project(id: ProjectID.android, name: "Legacy Android App", colorHex: "#FFCC00", isArchived: true, createdAt: created),
        ]
        trackedApps = [
            TrackedApp(bundleIdentifier: "com.apple.dt.Xcode", name: "Xcode", addedAt: created),
            TrackedApp(bundleIdentifier: "com.figma.Desktop", name: "Figma", addedAt: created, projectId: ProjectID.design),
            TrackedApp(bundleIdentifier: "com.microsoft.VSCode", name: "Visual Studio Code", addedAt: created),
            TrackedApp(bundleIdentifier: "com.apple.Terminal", name: "Terminal", addedAt: created),
            TrackedApp(bundleIdentifier: "com.postmanlabs.mac", name: "Postman", addedAt: created, projectId: ProjectID.api),
            TrackedApp(bundleIdentifier: "com.apple.Safari", name: "Safari", addedAt: created),
        ]

        func at(_ hour: Double) -> Date { showcase.addingTimeInterval(hour * 3600) }
        unloggedRange = DateRange(start: at(16.5), end: at(17.25))
        sessions = Self.showcaseSessions.map { app, from, to in
            AppSession(bundleIdentifier: app.bundle, appName: app.name, start: at(from), end: at(to))
        }
        let showcaseEntries = [
            TimeEntry(projectId: ProjectID.fitness, start: at(8.75), end: at(12.4), title: "Workout history screen"),
            TimeEntry(projectId: ProjectID.planning, start: at(13), end: at(13.4), title: "Sprint planning"),
            TimeEntry(projectId: ProjectID.design, start: at(13.4), end: at(15), title: "Buttons & form fields"),
            TimeEntry(projectId: ProjectID.api, start: at(15), end: at(16.4), title: "Conflict resolution endpoint"),
        ]
        entries = Self.history(from: yearStart, to: showcase, calendar: calendar) + showcaseEntries
    }

    // MARK: Showcase day

    private typealias App = (bundle: String, name: String)
    private static let xcode: App = ("com.apple.dt.Xcode", "Xcode"), safari: App = ("com.apple.Safari", "Safari")
    private static let figma: App = ("com.figma.Desktop", "Figma"), code: App = ("com.microsoft.VSCode", "Visual Studio Code")
    private static let terminal: App = ("com.apple.Terminal", "Terminal"), postman: App = ("com.postmanlabs.mac", "Postman")

    private static let showcaseSessions: [(App, Double, Double)] = [
        (xcode, 8.75, 10.5), (safari, 10.5, 10.75), (xcode, 10.75, 11.6), (terminal, 11.6, 11.8), (xcode, 11.8, 12.4),
        (figma, 13.4, 15), (safari, 15, 15.15), (code, 15.15, 15.8), (terminal, 15.8, 16.05), (postman, 16.05, 16.4),
        (xcode, 16.5, 17.25),
    ]

    // MARK: History

    /// Logged hours on every working day in [`from`, `to`), except holidays: 5–8.5 h split over two or three projects.
    private static func history(from: Date, to: Date, calendar: Calendar) -> [TimeEntry] {
        var entries: [TimeEntry] = []
        var day = from
        var index = 0
        while day < to {
            defer {
                day = calendar.date(byAdding: .day, value: 1, to: day)!
                index += 1
            }
            guard !calendar.isDateInWeekend(day), !isHoliday(day, calendar: calendar) else { continue }
            var random = SeededRandom(seed: UInt64(index) &* 2_654_435_761 &+ 97)
            let month = calendar.component(.month, from: day)
            var hour = 8.5 + Double(random.next(4)) * 0.25
            if calendar.component(.weekday, from: day) == 2 {   // Monday: planning first
                entries.append(entry(ProjectID.planning, day, hour, 1))
                hour += 1
            }
            let blocks = 2 + random.next(2)
            for block in 0..<blocks {
                let length = 1.75 + Double(random.next(6)) * 0.25
                let project = pick(month: month, block: block, random: &random)
                entries.append(entry(project, day, hour, length))
                hour += length + (block == 0 ? 0.75 : 0)   // lunch after the first block
            }
        }
        return entries
    }

    /// Which project gets a block: the focus shifts over the year, like real client work.
    private static func pick(month: Int, block: Int, random: inout SeededRandom) -> Int64 {
        let roll = random.next(10)
        if roll == 0 { return ProjectID.support }
        switch month {
        case 1...2: return [ProjectID.android, ProjectID.portal, ProjectID.design][block % 3]
        case 3...5: return roll < 6 ? ProjectID.portal : (block == 0 ? ProjectID.fitness : ProjectID.design)
        case 6...8: return roll < 5 ? ProjectID.fitness : (roll < 8 ? ProjectID.api : ProjectID.portal)
        default: return [ProjectID.fitness, ProjectID.api, ProjectID.design, ProjectID.portal][(block + roll) % 4]
        }
    }

    private static func entry(_ project: Int64, _ day: Date, _ start: Double, _ length: Double) -> TimeEntry {
        TimeEntry(projectId: project, start: day.addingTimeInterval(start * 3600),
                  end: day.addingTimeInterval((start + length) * 3600))
    }

    /// New Year, a summer holiday and a few days off, so the yearly heatmap looks lived-in.
    private static func isHoliday(_ day: Date, calendar: Calendar) -> Bool {
        let parts = calendar.dateComponents([.month, .day], from: day)
        switch (parts.month!, parts.day!) {
        case (1, 1), (4, 27), (5, 5), (12, 25), (12, 26): return true
        case (7, 27...31), (8, 1...14): return true
        default: return false
        }
    }
}

/// Tiny deterministic generator (SplitMix64), so every run draws the same sample year.
private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    /// A number in 0..<upperBound.
    mutating func next(_ upperBound: Int) -> Int {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return Int(value % UInt64(upperBound))
    }
}
#endif
