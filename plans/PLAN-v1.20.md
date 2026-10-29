# PLAN v1.20 — Overview screen: yearly activity heatmap and statistics

Branch: `feature/activity-overview` (branched from `origin/main`). A PR to `main` is opened for it.
Commit on this branch; do **not** merge into `main`. (`PLAN-v1.19` is the month export on another branch.)

## Goal

A new sidebar screen **Overview** shows, for one calendar year, how many hours the user registered
(time entries, not app sessions) — like the contribution graph on a GitHub profile: one small square
per day, 7 rows (weekdays) × ~53 columns (weeks); the more hours on a day, the brighter the square.
Around it, a few useful statistics for that year.

Screen, top to bottom:

1. **Year bar** — `‹ 2026 › This year`, ⌘← / ⌘→ / ⌘T (same pattern as `MonthNavigationBar`).
   Plus a **project filter** `Picker` ("All projects" or one project, archived ones included).
2. **Heading** — "1,234 h registered in 2026" (filtered: "… on <project>").
3. **Heatmap** (the core feature, see §3).
4. **Statistic tiles** — Total hours · Active days · Average per active day · Longest streak ·
   Busiest day (date + hours).
5. **Hours per month** — a Swift Charts bar chart, 12 bars, stacked by project color.
6. **Projects** — per-project total for the year with a thin proportional bar in the project color
   and its share in %, sorted by hours desc (only projects with hours > 0).

Clicking a day square opens the **Timeline** on that day.

Non-goals: rolling "last 12 months" view, app-session statistics, goals/targets, settings for the
color thresholds, menu bar changes.

## Constraints (AGENTS.md / PLAN.md §11)

- MVVM: models plain structs; view models `@MainActor @Observable final class`, dependencies via
  `init`, no SwiftUI views and **no `import GRDB`**; views contain no business logic and never call
  repositories. `async func task()` observes, restarted with `.task(id:)`.
- Pure logic (day bucketing, levels, heatmap layout, streaks, stats) lives in side-effect-free
  `Sendable` structs/enums and is unit-tested.
- No new third-party dependencies. **Swift Charts** (Apple framework) is allowed.
- One type per file, file name = type name, aim < 150 lines (hard ~250).
- Every view has a `#Preview` using `AppEnvironment.preview()` (pure subviews may use literal data).
- UI text in English. Native macOS look: system fonts, `.secondary`/`.quaternary` styles,
  `GroupBox` or plain sections, accent color — **no** hard-coded GitHub green.
- No schema change, no new migration — everything is computed from existing `time_entry` and
  `project` rows.
- Known traps apply: keyboard shortcuts registered once in a hidden view (not inside
  `ViewThatFits` variants); `isLoaded` to avoid flashing empty states; no `.popover` on offset views.

## Design

### 1. Date helpers — `Timelane/Utilities/`

- `Calendar+Helpers.swift`: add `func startOfYear(for date: Date) -> Date`.
- `DateRange.swift`: add `static func year(of:calendar:)` and
  `func shiftedYears(_:calendar:)`, mirroring `month(of:)` / `shiftedMonths`.

### 2. Pure statistics — `Timelane/Services/Activity/`

```swift
/// Registered seconds per calendar day, per project, for one year. Entries are clipped to the year
/// and split at midnight (an entry 23:00–01:00 adds 1 h to each day). DST-safe: days come from the calendar.
struct YearActivity: Sendable, Hashable {
    let year: DateRange
    /// Start of day → project id → seconds. Only days with time.
    let secondsByDay: [Date: [Int64: TimeInterval]]

    init(entries: [TimeEntry], year: DateRange, calendar: Calendar)

    /// Seconds on one day, optionally for one project only.
    func seconds(on day: Date, projectId: Int64?) -> TimeInterval
    /// Day → seconds for the filter (days without time are absent).
    func dailyTotals(projectId: Int64?) -> [Date: TimeInterval]
    /// Project id → seconds in the year.
    func projectTotals() -> [Int64: TimeInterval]
    /// 12 items (one per month, in order), each project id → seconds; respects the filter.
    func monthlyTotals(projectId: Int64?, calendar: Calendar) -> [[Int64: TimeInterval]]
}
```

```swift
/// The five brightness steps of a heatmap square (GitHub-style).
enum ActivityLevel: Int, CaseIterable, Sendable {
    case none, low, medium, high, max
    /// Fixed hour thresholds, so colors mean the same in every year:
    /// 0 → none, (0, 2h) → low, [2h, 4h) → medium, [4h, 6h) → high, ≥ 6h → max.
    init(seconds: TimeInterval)
}
```
Fixed thresholds are chosen over GitHub's relative quartiles because hours are an absolute
quantity (a full working day should always look bright).

```swift
/// Positions of the day squares: column = week, row = weekday, honoring `calendar.firstWeekday`.
struct ActivityHeatmapLayout: Sendable {
    struct Cell: Hashable, Sendable { let day: Date; let column: Int; let row: Int }
    struct MonthLabel: Hashable, Sendable { let title: String; let column: Int }

    init(year: DateRange, calendar: Calendar)
    let columnCount: Int          // 53 or 54
    let cells: [Cell]             // only days inside the year (no padding cells)
    let monthLabels: [MonthLabel] // short month symbol at the column containing the 1st of the month;
                                  // drop a label that is < 3 columns after the previous one (like GitHub)
    let weekdayLabels: [(row: Int, title: String)] // rows 0, 2, 4 → e.g. Mon, Wed, Fri when Monday-first
}
```
Column 0 is the week (by `firstWeekday`) containing January 1; row = days since that week's start.

```swift
/// Summary numbers of a year for the filter.
struct ActivityStatistics: Sendable, Hashable {
    let totalSeconds: TimeInterval
    let activeDays: Int                     // days with > 0 s
    let averagePerActiveDay: TimeInterval   // 0 when no active days
    let longestStreak: Int                  // most consecutive calendar days with > 0 s
    let currentStreak: Int                  // streak ending today or yesterday (0 for past years if not applicable: only when `today` is inside the year)
    let busiestDay: (day: Date, seconds: TimeInterval)?  // make it a small Hashable struct instead of a tuple
    init(dailyTotals: [Date: TimeInterval], year: DateRange, today: Date, calendar: Calendar)
}
```
Streaks count consecutive calendar days (weekends break them — keep it simple, document it).
Show `currentStreak` only in the tile's caption ("Current: 3 days") when the year contains today.

### 3. Heatmap view — `Timelane/Features/Overview/Views/ActivityHeatmap.swift`

- Pure input: `layout: ActivityHeatmapLayout`, `dailyTotals: [Date: TimeInterval]`,
  `onSelectDay: (Date) -> Void`.
- Draw: weekday labels column on the left (`.caption2`, `.secondary`), month labels on top, squares
  as `RoundedRectangle(cornerRadius: 2)`; ~2 pt spacing.
- **Size**: cells fit the available width via `GeometryReader`:
  `cell = clamp((width − labelWidth) / columnCount − spacing, 9…16)`. When even 9 pt does not fit
  (narrow detail ≥ 480 pt), wrap in a horizontal `ScrollView` scrolled to the trailing edge
  (most recent weeks) using `ScrollViewReader`/`defaultScrollAnchor(.trailing)`. Never clip squares.
  Give the heatmap a fixed height (7 rows + month label row) so the outer layout is stable.
- **Colors** (light & dark): `none` → `Color.primary.opacity(0.08)`; levels 1–4 →
  `Color.accentColor.opacity(0.35 / 0.55 / 0.78 / 1.0)`. Put these in a small
  `ActivityLevel+Color.swift` extension (SwiftUI file, not in the pure enum file).
- Days after today are drawn as empty with lower opacity (0.04) — no data possible.
- **Tooltip**: `.help("Tue 3 Mar 2026 · 5h 30m")` (use `DurationFormatter`; "No hours" for 0).
- **Click**: `onTapGesture` → `onSelectDay(day)`; pointer gets no special cursor (native).
- Legend below, trailing: `Less ▢▢▢▢▢ More` (`.caption`, `.secondary`).
- Accessibility: each square `accessibilityLabel` with the same text as the tooltip; the grid is an
  `accessibilityElement(children: .contain)` labelled "Registered hours per day".

### 4. View model — `Timelane/Features/Overview/ViewModels/OverviewViewModel.swift`

```swift
@MainActor @Observable
final class OverviewViewModel {
    private(set) var year: DateRange
    var selectedProjectId: Int64?           // nil = all projects
    private(set) var projects: [Project] = [] // archived included, for names/colors/picker
    private(set) var activity: YearActivity
    private(set) var isLoaded = false
    var errorMessage: String?

    init(timeEntries: any TimeEntryRepository, projects: any ProjectRepository,
         calendar: Calendar = .current, now: @escaping () -> Date = { .now })

    var yearTitle: String; var isCurrentYear: Bool
    func goToPreviousYear(); func goToNextYear(); func goToCurrentYear()
    var heatmapLayout: ActivityHeatmapLayout   // cache per year if profiling shows a need; computing is cheap
    var dailyTotals: [Date: TimeInterval]      // for the filter
    var statistics: ActivityStatistics
    var projectRows: [OverviewProjectRow]      // project, seconds, share (0…1), sorted desc, > 0 only
    var monthlyBars: [OverviewMonthBar]        // month start, project id, project name, color hex, seconds
    var heading: String                        // "1,234 h registered in 2026"
    /// Observes entries of the year and all projects; restart with `.task(id: year)`.
    func task() async
}
```
- `task()` observes `timeEntries.observeEntries(in: year)` and
  `projects.observeProjects(includeArchived: true)` concurrently (`withTaskGroup`, each loop
  assigns on the main actor). Set `isLoaded` after the first entries arrive. Rebuild `activity`
  on each entries emission.
- If `selectedProjectId` points to a project that no longer exists, treat it as nil.
- Put `OverviewProjectRow` / `OverviewMonthBar` in their own files (plain structs).
- If the file gets long, move derived properties to `OverviewViewModel+Derived.swift`.

### 5. Views — `Timelane/Features/Overview/Views/`

- `OverviewScreen` — `ScrollView` (vertical) with the sections, `.navigationTitle("Overview")`,
  `.task(id: viewModel.year)`, `.errorAlert`. Before `isLoaded`: `Color.clear`. When the
  year has no hours: still show the (empty) heatmap, and replace stats/chart/projects with a
  `ContentUnavailableView("No hours in 2026", systemImage: "square.grid.3x3", description: …)`.
- `YearNavigationBar` + `YearNavigationShortcuts` — copies of the month versions adapted to years
  ("This year", help texts "Previous year (⌘←)" …). Project filter `Picker` (`.menu` style,
  `fixedSize`) on the trailing side of the bar; use `ViewThatFits` only if needed at 480 pt.
- `ActivityHeatmap` (§3), `ActivityLegend`.
- `OverviewStatTiles` — `Grid`/adaptive `LazyVGrid` of `OverviewStatTile(title:value:caption:)`
  (value `.title2.weight(.semibold).monospacedDigit()`, title `.caption` `.secondary`), background
  `.background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))` or `GroupBox`.
  Must wrap to 2–3 columns at 480 pt.
- `OverviewMonthlyChart` — `Chart` of `BarMark(x: .value("Month", start, unit: .month),
  y: .value("Hours", seconds / 3600))`, `foregroundStyle` per project color via
  `chartForegroundStyleScale(domain:range:)` (project names → `ProjectColor.color(hex:)`), legend hidden
  (the projects list below is the legend), height ~180, axis month labels abbreviated.
- `OverviewProjectList` — rows: color dot, name (+ "Archived" tag in `.secondary`), proportional
  `Capsule` bar, hours (`DurationFormatter`) and percentage, `monospacedDigit`.
- Each view gets a `#Preview` (`AppEnvironment.preview()` for the screen; make sure preview sample
  data contains entries spread over several days — extend the preview seed only if it has none).

### 6. Navigation

- `SidebarItem`: add `case overview` **after** `trackedApps` (keeps ⌘1–⌘3 unchanged), title
  "Overview", `systemImage: "square.grid.3x3.fill"`. `RootView`: detail case and a ⌘4 shortcut in
  `sidebarShortcuts`.
- Day click → Timeline: add `var requestedTimelineDay: Date?` to `AppEnvironment` (next to
  `requestedSidebarItem`, same doc-comment style). `OverviewScreen` sets it and then
  `requestedSidebarItem = .timeline`. `TimelineScreen` consumes it with
  `.onChange(of: environment.requestedTimelineDay, initial: true)` → `viewModel.go(to:)`, then
  sets it back to nil. (The Timeline screen is recreated when the sidebar switches, so `initial: true`
  is required.) Check that the menu bar timeline is unaffected (it does not read this property).

### 7. Docs

- `README.md` Features: add the Overview screen.
- `plans/PLAN.md`: add the Overview screen to the screens/feature description.
- `AGENTS.md` project layout: add `Features/Overview/` and `Services/Activity/`; ⌘1/⌘2/⌘3 → ⌘1–⌘4.

## Files

New:
- `Timelane/Services/Activity/YearActivity.swift`, `ActivityLevel.swift`,
  `ActivityHeatmapLayout.swift`, `ActivityStatistics.swift`
- `Timelane/Features/Overview/ViewModels/OverviewViewModel.swift` (+ `+Derived` if needed),
  `OverviewProjectRow.swift`, `OverviewMonthBar.swift`
- `Timelane/Features/Overview/Views/OverviewScreen.swift`, `YearNavigationBar.swift`,
  `YearNavigationShortcuts.swift`, `ActivityHeatmap.swift`, `ActivityLevel+Color.swift`,
  `ActivityLegend.swift`, `OverviewStatTiles.swift`, `OverviewStatTile.swift`,
  `OverviewMonthlyChart.swift`, `OverviewProjectList.swift`
- Tests: `TimelaneTests/YearActivityTests.swift`, `ActivityLevelTests.swift`,
  `ActivityHeatmapLayoutTests.swift`, `ActivityStatisticsTests.swift`, `OverviewViewModelTests.swift`

Changed: `DateRange.swift`, `Calendar+Helpers.swift`, `SidebarItem.swift`, `RootView.swift`,
`AppEnvironment.swift`, `TimelineScreen.swift`, `DateRangeTests.swift`, README, PLAN.md, AGENTS.md.
The app target folder is a synchronized group — **do not edit `project.pbxproj`** for new files.

## Tests (Swift Testing, fixed Gregorian calendar, `Europe/Amsterdam`, explicit `firstWeekday`)

- `DateRange.year(of:)` / `shiftedYears` incl. leap year length.
- `YearActivity`: entry split at midnight; entry crossing Dec 31 → Jan 1 clipped to the year;
  DST days (last Sunday of March / October) bucket correctly; per-project filter; monthly totals
  have 12 items and sum to the year total.
- `ActivityLevel`: boundaries 0, 1 s, 2 h − 1 s, 2 h, 4 h, 6 h, 12 h.
- `ActivityHeatmapLayout`: 2026 Monday-first (Jan 1 2026 is a Thursday → row 3, column 0);
  Sunday-first variant; Dec 31 is in the last column; cell count = 365 / 366;
  12 month labels at the right columns (or fewer after the < 3 column rule; test the rule);
  weekday labels rows 0/2/4.
- `ActivityStatistics`: empty year; longest streak across a month boundary; current streak ending
  yesterday counts, ending two days ago is 0; busiest day; average per active day.
- `OverviewViewModel` (in-memory environment, fake `now`): loads entries for the year, filter
  changes totals, year navigation changes `year`, unknown `selectedProjectId` behaves as nil,
  `isLoaded` false before the first emission.

## Order of work

1. Date helpers + tests.
2. `ActivityLevel`, `YearActivity`, `ActivityHeatmapLayout`, `ActivityStatistics` + tests.
3. `OverviewViewModel` (+ row/bar structs) + tests.
4. Views, sidebar/⌘4, Timeline day request.
5. Docs.
6. Run the full test suite (command in AGENTS.md, with `-derivedDataPath build/DerivedData` inside
   this worktree); fix everything. Do not launch the app with `-resetDatabase`.
7. Commit in logical steps (plan is already committed), message style as in `git log`.

## Definition of done

- All tests pass (old and new), build has no new warnings.
- Overview appears as 4th sidebar item, ⌘4 opens it; ⌘1–⌘3 unchanged.
- Heatmap shows a full year with month and weekday labels, brighter squares for more hours,
  tooltips, legend, and clicking a square opens that day on the Timeline.
- Works and does not clip at the minimum window size (detail 480 pt) and in light and dark mode.
- Files within the size limits; every view has a `#Preview`; no `import GRDB` outside
  `Database/` and `Repositories/GRDB/`.
- README, PLAN.md and AGENTS.md updated.

### Manual check for the owner

1. ⌘4 → Overview for the current year; squares on days with logged hours, brighter for longer days.
2. Hover a square → tooltip with date and hours. Click → Timeline opens on that day.
3. ⌘← / ⌘→ / ⌘T change the year; the project filter changes heatmap, tiles and chart.
4. Make the window as narrow as possible → heatmap scrolls horizontally (newest weeks visible),
   tiles wrap, nothing clipped. Check light and dark mode.
