# TimeTracker — Implementation Plan

A native macOS app (SwiftUI) that helps a software developer register working hours per project. The app automatically records which applications were in the foreground and shows them on a vertical day timeline. The user then drags across the timeline to assign time ranges to projects. A separate screen manages projects and shows the hours spent per project per month.

Guiding principles: **simple, not over-engineered, small files, MVVM, easy to extend.**

---

## 1. Requirements

### 1.1 Functional

**Day timeline (main screen)**
- R1. A vertical, column-shaped timeline for one day (00:00–24:00, scrollable; on open it scrolls to the current time, or to 08:00 for past days).
- R2. The app tracks which application is in the foreground and stores these as *app sessions* (app, start, end). **v1.1:** only apps on the user's *tracked apps list* are recorded and shown; the list starts empty and is managed in the Tracked Apps screen (see PLAN-v1.1.md §4).
- R3. App sessions are drawn on the timeline in their own lane, so the user can see how long they spent in which app.
- R4. The user registers hours by **dragging** vertically over the timeline to select a time range (e.g. 10:00–13:00). After releasing, a *time entry window* (sheet) opens where they pick the project, adjust the times and give the block a title. The result is a *time entry* (project, start, end, optional title, optional note).
- R5. The user can assign a whole app session to a project in one action (click the session → time entry window prefilled with the session's range).
- R6. Splitting a session over several projects is done by simply dragging several smaller ranges. There is no special "split" feature.
- R7. Existing time entries can be selected, moved, resized (drag top/bottom edge), have their title, project, note or times changed (same window), and be deleted.
- R8. Day navigation: previous day, next day, "Today", and a date picker. Today is the default view.
- R9. A day total shows the registered hours (sum of time entries) and the tracked hours (sum of app sessions).

**Projects screen**
- R10. List of projects with the number of hours registered in the selected month.
- R11. Month navigation: previous month, next month, "This month". Default is the current month.
- R12. Add a project quickly (name + color). Edit name/color. Archive a project (hidden from the project picker, but historical hours remain). Deleting is only allowed when a project has no entries.
- R13. A total for the month is shown at the bottom.

### 1.2 Non-functional
- Native macOS (SwiftUI), deployment target macOS 27 (as set in the project).
- Data is stored locally in SQLite.
- MVVM: Views contain no business logic; ViewModels contain no SQL; Models are plain value types.
- Small files: aim for **< 150 lines per file**, hard limit ~250. A View that grows beyond that is split into subviews.
- App tracking keeps running while the main window is closed (the app stays running; a menu bar item gives access).
- Works within the App Sandbox (already enabled).

### 1.3 Explicitly out of scope (v1)
- Window titles / document names (requires Accessibility permission). Only the app name and bundle id are tracked.
- Sync, accounts, multi-device, export integrations (but the architecture must make these easy to add — see §10).
- Week view, reports, charts.

---

## 2. Technical decisions

| Topic | Decision | Reason |
|---|---|---|
| UI | SwiftUI, `NavigationSplitView` with sidebar (Timeline, Projects) | Native, simple, easy to add screens later. |
| State | `@Observable` ViewModels (Observation framework), `@MainActor` | Modern, less boilerplate than `ObservableObject`. The project already has `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. |
| Database | **GRDB.swift** (SPM, `https://github.com/groue/GRDB.swift`, latest 7.x) on top of SQLite | Real SQLite with explicit migrations, `Codable` records, efficient aggregate queries (monthly totals), and `ValueObservation` for live UI updates. Thin and predictable compared to SwiftData. |
| Data access | Repository protocols (`ProjectRepository`, …) with a GRDB implementation | ViewModels depend on protocols → testable with in-memory DB or fakes, and the storage can be swapped/extended (e.g. sync) later. |
| App tracking | `NSWorkspace.shared.notificationCenter` (`didActivateApplicationNotification`) + sleep/wake + screen lock + idle detection | Works in the sandbox, no extra permissions needed. |
| Dependency injection | One `AppEnvironment` (composition root) created in `TimeTrackerApp`, passed down via SwiftUI `.environment(...)` | No DI framework needed; one place where everything is wired. |
| Tests | Swift Testing (`import Testing`) in a new unit test target | Pure logic (geometry, overlap resolution, aggregation) and repositories (in-memory GRDB). |
| Time | Store `Date` as UTC timestamp in SQLite. Day/month boundaries are calculated using `Calendar.current` in a single helper (`DateRange`). | Avoids timezone/DST bugs scattered over the code. |

### 2.1 Project setup tasks
1. Set the target to **macOS only** (`SDKROOT = macosx`, `SUPPORTED_PLATFORMS = macosx`) and remove the iOS-specific `INFOPLIST_KEY_UI*` settings.
2. Add GRDB via Swift Package Manager.
3. Add a unit test target `TimeTrackerTests`.
4. Rename `MyApp.swift` → `App/TimeTrackerApp.swift` (struct `TimeTrackerApp`). Delete `ContentView.swift` (including the `Playgrounds` import).
5. The project uses `PBXFileSystemSynchronizedRootGroup`: files created in the `TimeTracker/` folder are picked up by Xcode automatically. Create the folder structure from §3 on disk.
6. Set the Swift language version to 6 (strict concurrency) if the project builds cleanly; otherwise keep 5 with complete concurrency checking.

---

## 3. Folder structure

```
TimeTracker/
├── App/
│   ├── TimeTrackerApp.swift          // @main, scenes (WindowGroup + MenuBarExtra)
│   ├── AppEnvironment.swift          // composition root: DB, repositories, tracker
│   └── AppDelegate.swift             // keep running when window closes; start tracker
│
├── Models/
│   ├── Project.swift
│   ├── TimeEntry.swift
│   ├── AppSession.swift
│   ├── ProjectColor.swift            // predefined palette + hex <-> Color
│   └── ProjectMonthTotal.swift       // read model: project + total seconds
│
├── Database/
│   ├── AppDatabase.swift             // opens DatabaseQueue/Pool, location, in-memory factory
│   ├── Migrations.swift              // DatabaseMigrator with versioned migrations
│   └── Records/                      // GRDB conformances, kept separate from models
│       ├── Project+Record.swift
│       ├── TimeEntry+Record.swift
│       └── AppSession+Record.swift
│
├── Repositories/
│   ├── ProjectRepository.swift       // protocol
│   ├── TimeEntryRepository.swift     // protocol
│   ├── AppSessionRepository.swift    // protocol
│   └── GRDB/
│       ├── GRDBProjectRepository.swift
│       ├── GRDBTimeEntryRepository.swift
│       └── GRDBAppSessionRepository.swift
│
├── Services/
│   ├── Tracking/
│   │   ├── AppActivityTracker.swift      // listens to NSWorkspace, writes AppSessions
│   │   ├── ActivityEvent.swift           // enum: appActivated, idleStarted, sleep, wake, …
│   │   ├── IdleMonitor.swift             // polls system idle time
│   │   └── SystemEventObserver.swift     // sleep/wake/lock/unlock notifications
│   └── TimeEntryOverlapResolver.swift    // pure logic: trim/split overlapping entries
│
├── Utilities/
│   ├── DateRange.swift               // day(of:), month(of:), contains, intersection
│   ├── DurationFormatter.swift       // seconds -> "3:45" / "3u 45m"
│   └── Calendar+Helpers.swift
│
├── Features/
│   ├── Root/
│   │   ├── RootView.swift            // NavigationSplitView
│   │   └── SidebarItem.swift         // enum: timeline, projects
│   │
│   ├── Timeline/
│   │   ├── ViewModels/
│   │   │   ├── TimelineViewModel.swift       // day state, loading, observation
│   │   │   ├── TimelineSelection.swift       // drag selection state (value type)
│   │   │   └── TimeEntryEditor.swift         // create/update/delete entry use-cases
│   │   ├── Layout/
│   │   │   ├── TimelineGeometry.swift        // time <-> y, snapping (pure, tested)
│   │   │   └── AppSessionMerger.swift        // merges/filters sessions for display (pure, tested)
│   │   └── Views/
│   │       ├── TimelineScreen.swift          // header + scrollable timeline
│   │       ├── DayNavigationBar.swift        // < Today > + date picker + totals
│   │       ├── DayTotalsView.swift
│   │       ├── TimelineColumn.swift          // ZStack of the lanes + gesture layer
│   │       ├── HourGridView.swift            // hour lines and labels
│   │       ├── NowIndicatorView.swift        // red line at current time (today only)
│   │       ├── AppSessionLane.swift
│   │       ├── AppSessionBlock.swift
│   │       ├── TimeEntryLane.swift
│   │       ├── TimeEntryBlock.swift          // incl. resize handles
│   │       ├── SelectionOverlay.swift        // the range being dragged
│   │       ├── SelectionDragGesture.swift    // drag over both lanes
│   │       ├── NoTrackedAppsBanner.swift
│   │       ├── TimeEntryFormSheet.swift      // v1.1: new/edit window (replaces both popovers)
│   │       ├── TimeEntryFormTimeFields.swift
│   │       └── ProjectSearchList.swift
│   │
│   ├── TrackedApps/                      // v1.1: list, add sheet, open panel
│   └── Projects/
│       ├── ViewModels/
│       │   ├── ProjectsViewModel.swift       // month, totals, observation
│       │   └── ProjectFormViewModel.swift    // add/edit validation + save
│       └── Views/
│           ├── ProjectsScreen.swift
│           ├── MonthNavigationBar.swift
│           ├── ProjectRow.swift
│           ├── ProjectsTotalFooter.swift
│           ├── ProjectFormSheet.swift
│           └── ColorPickerRow.swift
│
├── MenuBar/
│   ├── MenuBarContentView.swift      // status line + compact day bar + timeline (or inline form) + footer
│   ├── MenuBarViewModel.swift        // own TimelineViewModel (own zoom key), "today on open"
│   ├── MenuBarStatusLine / MenuBarDayBar / MenuBarFooter / MenuBarFormView / MenuBarErrorBanner
│   └── PanelOpenObserver.swift       // NSView helper: fires on every window key / visible
│
└── Assets.xcassets

TimeTrackerTests/
├── TimelineGeometryTests.swift
├── AppSessionMergerTests.swift
├── TimeEntryOverlapResolverTests.swift
├── DateRangeTests.swift
├── ProjectRepositoryTests.swift
├── TimeEntryRepositoryTests.swift
└── AppActivityTrackerTests.swift
```

Rule of thumb: one type per file. Extensions that add a separate responsibility (e.g. GRDB conformance) go into their own file.

---

## 4. Data model

### 4.1 Models (plain Swift value types, `Identifiable`, `Hashable`, `Sendable`)

```swift
struct Project {
    var id: Int64?
    var name: String
    var colorHex: String          // e.g. "#4F8EF7"
    var isArchived: Bool
    var createdAt: Date
}

struct TimeEntry {
    var id: Int64?
    var projectId: Int64
    var start: Date
    var end: Date                 // invariant: end > start
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

struct AppSession {
    var id: Int64?
    var bundleIdentifier: String
    var appName: String
    var start: Date
    var end: Date?                // nil = currently active session
}

struct ProjectMonthTotal {       // read model, not stored
    var project: Project
    var totalSeconds: TimeInterval
}
```

Keep the models free of GRDB and SwiftUI imports (except `Foundation`). `ProjectColor` translates `colorHex` into a SwiftUI `Color` in a separate extension.

### 4.2 SQLite schema (migration `v1`; `v2` adds `timeEntry.title` and the `trackedApp` table, see PLAN-v1.1.md §1)

```sql
CREATE TABLE project (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL COLLATE NOCASE UNIQUE,
  colorHex    TEXT NOT NULL,
  isArchived  BOOLEAN NOT NULL DEFAULT 0,
  createdAt   DATETIME NOT NULL
);

CREATE TABLE timeEntry (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  projectId   INTEGER NOT NULL REFERENCES project(id) ON DELETE RESTRICT,
  start       DATETIME NOT NULL,
  "end"       DATETIME NOT NULL,
  note        TEXT,
  createdAt   DATETIME NOT NULL,
  updatedAt   DATETIME NOT NULL,
  CHECK ("end" > start)
);
CREATE INDEX timeEntry_start ON timeEntry(start);
CREATE INDEX timeEntry_projectId ON timeEntry(projectId);

CREATE TABLE appSession (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  bundleIdentifier  TEXT NOT NULL,
  appName           TEXT NOT NULL,
  start             DATETIME NOT NULL,
  "end"             DATETIME
);
CREATE INDEX appSession_start ON appSession(start);
```

Use GRDB's `DatabaseMigrator` with `t.autoIncrementedPrimaryKey`, `t.belongsTo` etc. rather than raw SQL; the above is the intended result. Every future schema change becomes a **new** migration (`v2`, `v3`, …) — never edit an existing migration.

Database location: `Application Support/TimeTracker/db.sqlite` (inside the sandbox container). `AppDatabase` also offers `static func inMemory()` for tests and previews.

### 4.3 Queries the repositories must provide

```swift
protocol ProjectRepository: Sendable {
    func observeProjects(includeArchived: Bool) -> AsyncValueObservation<[Project]>  // or an AsyncStream
    func monthTotals(in range: DateRange) async throws -> [ProjectMonthTotal]
    func observeMonthTotals(in range: DateRange) -> AsyncStream<[ProjectMonthTotal]>
    func save(_ project: Project) async throws -> Project
    func archive(id: Int64, archived: Bool) async throws
    func delete(id: Int64) async throws          // throws if entries exist
}

protocol TimeEntryRepository: Sendable {
    func observeEntries(in range: DateRange) -> AsyncStream<[TimeEntry]>
    func entries(in range: DateRange) async throws -> [TimeEntry]
    func save(_ entries: [TimeEntry], deleting ids: [Int64]) async throws   // one transaction
}

protocol AppSessionRepository: Sendable {
    func observeSessions(in range: DateRange) -> AsyncStream<[AppSession]>
    func start(_ session: AppSession) async throws -> AppSession
    func close(id: Int64, at end: Date) async throws
    func closeDanglingSessions(at end: Date) async throws   // on launch after crash
}
```

Hide GRDB-specific types behind `AsyncStream` so ViewModels never import GRDB.

**Monthly totals must clip entries to the range**: an entry from 23:00 on the 31st to 01:00 on the 1st counts 1 hour in each month. Implement as SQL:
`SUM(MIN("end", :rangeEnd) - MAX(start, :rangeStart))` over entries where `start < :rangeEnd AND "end" > :rangeStart`, grouped by project (use `julianday` or store as Unix timestamps — pick one and be consistent; Unix `Double` timestamps via a custom `DatabaseDateEncodingStrategy` make the arithmetic simple). Projects with 0 hours in the month are still listed (LEFT JOIN), unless archived and 0.

---

## 5. App activity tracking

### 5.1 `AppActivityTracker`
- `@MainActor final class`, started once from `AppDelegate.applicationDidFinishLaunching`.
- On start:
  1. `appSessionRepository.closeDanglingSessions(at: lastKnownTimestamp)` — sessions without `end` from a previous crash are closed. Keep a "heartbeat" timestamp in `UserDefaults` that is updated every 60s, and use that as the end time (fallback: start + 1 min).
  2. Start a session for `NSWorkspace.shared.frontmostApplication`.
- Subscribe to `NSWorkspace.shared.notificationCenter`:
  - `didActivateApplicationNotification` → close the current session at now, start a new one for the activated app.
  - `willSleepNotification`, `screensDidSleepNotification`, `sessionDidResignActiveNotification` → close the current session (pause).
  - `didWakeNotification`, `screensDidWakeNotification`, `sessionDidBecomeActiveNotification` → resume with the frontmost app.
- `DistributedNotificationCenter`: `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked` → pause / resume.
- `IdleMonitor`: every 30s check `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)` (use `kCGAnyInputEventType`). When idle > 5 min (configurable constant in `TrackingSettings`): close the current session at `now - idleSeconds` and pause. On the first check after activity returns: resume.
- On `applicationWillTerminate`: close the current session.
- **v1.1:** only apps on the tracked apps list (`TrackedAppRepository`) open sessions; list changes arrive as `ActivityEvent.trackedAppsChanged`. Untracked frontmost apps behave like a pause. The app's own bundle id is only recorded if the user adds it. **v1.3:** the list only decides what is recorded from now on; all stored sessions are always shown on the timeline and in the totals (see PLAN-v1.3.md). DEBUG builds accept the launch argument `-resetDatabase YES`, which deletes the database file before opening it.

Translate all sources into one `ActivityEvent` enum and handle them in a single `handle(_ event:)` method; this keeps the tracker small and testable (inject a clock `() -> Date` and feed events in tests).

### 5.2 Keeping the app alive
- `AppDelegate.applicationShouldTerminateAfterLastWindowClosed` → `false`.
- Add a `MenuBarExtra` (`.window` style, 380 × 600 pt, `MenuBarContentView`). Since v1.5 it shows the live status line plus the same timeline as the main window (see §5.3).
- Leave "launch at login" for later (see §10) but structure settings so it can be added via `SMAppService.mainApp`.

### 5.3 Menu bar timeline (v1.5)
- The panel reuses `TimelineScrollArea` (scroll view, `TimelineColumn`, zoom, delete key) with its own `TimelineViewModel` (same database, so both stay in sync) created by `MenuBarViewModel.make`. Zoom is remembered under `"menuBarTimelineZoomLevel"` (default 30 min) via `TimelineZoomState(key:defaultLevel:)`.
- Registering uses an inline form: while `timeline.form != nil`, `MenuBarFormView` (wrapping `TimeEntryFormContent`, the content of the main window's `TimeEntryFormSheet`) covers the timeline, which stays alive underneath so its scroll position survives. Errors from move/resize/delete show in `MenuBarErrorBanner` instead of an alert.
- No project/tracked-app management: the timeline view model is created with `allowsCreatingProjects: false` (no "New project" row, Return without a match does nothing). "Open TimeTracker to add projects" and the no-tracked-apps banner open the main window on Projects / Tracked Apps through `AppEnvironment.requestedSidebarItem`, consumed by `RootView`.
- "Today on open": `onAppear`/`task` of MenuBarExtra content run once, so `PanelOpenObserver` (an `NSViewRepresentable`) observes `didBecomeKey` and `didChangeOcclusionState` of its window and calls `MenuBarViewModel.panelDidOpen()`: go to today and bump `scrollTrigger`, which makes `TimelineScrollArea` scroll to now − 1 h. An open form is left alone.
- (v1.6) Right-click on an entry block (`TimeEntryBlock.contextMenu`, shared by window and panel): **Edit…** (`TimelineViewModel.select`) and **Delete** (`TimelineViewModel.delete`, no confirmation). The panel form uses `View.panelBackground()` (opaque `windowBackgroundColor`, also used by `MenuBarContentView`) and fills the whole timeline area; `.background` would resolve to the translucent panel material.

---

## 6. Timeline feature (detailed)

### 6.1 Layout
```
┌───────────────────────────────────────────────────────────────┐
│  ◀  Today  ▶   Monday 26 October 2026  [📅]   Registered 6:15 │  DayNavigationBar
│                                               Tracked    7:40 │
├───────┬────────────────────────┬──────────────────────────────┤
│ 09:00 │ ▓ Xcode                │ ███ Project A                │
│       │ ▓                      │ ███                          │
│ 10:00 │ ░ Safari               │                              │
│       │ ▓ Xcode                │ ███ Project B                │
│ 11:00 │ ▒ Slack                │ ███                          │
│  ...  │  AppSessionLane        │  TimeEntryLane (drag here)   │
└───────┴────────────────────────┴──────────────────────────────┘
```
- One `ScrollView(.vertical)` containing `TimelineColumn` with a fixed height of `24 * pointsPerHour`.
- `pointsPerHour` follows the zoom level (v1.2, §6.9); 80 at the overview level.
- Three columns: hour labels (fixed width ~50pt), app session lane (~40%), time entry lane (~60%).
- `HourGridView` draws horizontal lines for every hour (and faint lines every 15 min) across both lanes.
- `NowIndicatorView` only on today, updates every minute via `TimelineView(.periodic(from:by: 60))`.
- On appear: `ScrollViewReader` scrolls to `max(now - 1h, 0)` for today, else to 08:00 or the first entry/session.

### 6.2 `TimelineGeometry` (pure struct, unit-tested)
```swift
struct TimelineGeometry {
    let day: DateRange
    let pointsPerHour: CGFloat
    let snapMinutes: Int = 5

    func y(for date: Date) -> CGFloat
    func date(forY y: CGFloat) -> Date              // clamped to the day
    func snapped(_ date: Date) -> Date              // round to nearest snapMinutes
    func frame(for start: Date, end: Date) -> (y: CGFloat, height: CGFloat)  // clipped to day
    var totalHeight: CGFloat
}
```
Watch out for DST days (23 or 25 hours): compute based on the real `DateRange` duration rather than assuming 24h. It's acceptable to make the column height follow the real duration.

### 6.3 App session display — `AppSessionMerger` (pure, tested)
Raw sessions can be very fragmented (Cmd-Tab every few seconds). Before display:
1. Clip sessions to the day; an open session (`end == nil`) runs until now.
2. Merge consecutive sessions of the same app when the gap is < 60s.
3. Drop sessions shorter than 60s **for display only** (keep the data).
Output: `[AppSessionBlockModel]` (id, appName, bundleId, start, end, duration).

`AppSessionBlock` shows: app icon (via `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` → `icon(forFile:)`, cached in a small `AppIconProvider`), app name and duration if the block is tall enough (> 30pt), otherwise only the icon/color. Color: a stable hash-based color per bundle id. Tooltip (`.help`) with name + start–end.

Clicking an `AppSessionBlock` opens the `TimeEntryFormSheet` (§6.5) pre-filled with the block's range → "assign whole session to project" (R5).

### 6.4 Drag to select (R4, R6)
- **v1.1:** the drag gesture lives on a full-size layer behind both lanes in `TimelineColumn` (and as a `simultaneousGesture` on the app-session blocks, so a click still assigns the session and a drag selects a range). It works in the past, present and future of the shown day. All pure overlays have `allowsHitTesting(false)`.
- `DragGesture(minimumDistance: 4, coordinateSpace: .named("timeline"))`:
  - `onChanged`: `selection = TimelineSelection(anchor: snapped(date(forY: startLocation.y)), current: snapped(date(forY: location.y)))`. `TimelineSelection` exposes a normalized `start`/`end` (handles dragging upward).
  - `onEnded`: if duration ≥ 5 min → open the `TimeEntryFormSheet`; else clear.
- `SelectionOverlay` draws a translucent accent-colored rectangle with a label "10:00 – 13:00 (3:00)" while dragging.
- Auto-scroll when dragging near the top/bottom edge is a nice-to-have; not required in v1.

### 6.5 `TimeEntryFormSheet` (v1.1; replaced the v1 popovers)
- A modal sheet (`.sheet(item:)` from `TimelineScreen`), independent of view positions (v1's popovers were anchored to `.offset` views and never appeared). Opens after a drag selection, a click on an app session (new entry) or a click on an entry (edit).
- Fields: title (optional), project (searchable list of non-archived projects, last used preselected, inline "New project" row), From/To (`DatePicker(.hourAndMinute)`, validation end > start and ≥ 1 min), note. Buttons: Cancel (Esc), Save (↩ / ⌘↩), Delete (edit mode).
- Logic: `TimeEntryForm` (values + validation), `ProjectSearch` (filter/highlight/inline-create, pure), `TimeEntryFormViewModel` (save/delete through `TimeEntryEditor`).

### 6.6 Overlap rule — `TimeEntryOverlapResolver` (pure, tested)
Time entries on the timeline **must not overlap**. The newest action wins:
- Given the existing entries of the day and a new/changed entry, return `(toSave: [TimeEntry], toDelete: [Int64])`:
  - Existing entry fully covered → delete.
  - Existing entry partially overlapping at one side → trim.
  - Existing entry strictly containing the new one → split into two (keep original id for the first part, new row for the second).
- `TimeEntryEditor` applies the result in **one transaction** via `TimeEntryRepository.save(_:deleting:)`.
- If an existing entry and the new one have the same project and are adjacent/overlapping, merging them is a nice-to-have; not in v1.

### 6.7 Editing existing entries (R7)
- `TimeEntryBlock`: filled with the project color, shows the title (or the project name when there is none), the project name, time/duration and note (as far as there is room).
- Click → `TimeEntryFormSheet` in edit mode (title, project, note, start/end, Delete). Also support the `Delete` key when an entry is selected.
- Resize: small (6pt) drag handles at the top and bottom edge; cursor `NSCursor.resizeUpDown` on hover (`.onContinuousHover` / `.pointerStyle`). Dragging updates a local preview; on end → `TimeEntryEditor.update(...)` (which goes through the overlap resolver).
- Move: dragging the body of a block moves it (keeping the duration), snapped. Same commit path.
- Minimum entry duration: 5 minutes.

### 6.8 `TimelineViewModel` responsibilities (keep it small)
```swift
@Observable @MainActor final class TimelineViewModel {
    private(set) var day: DateRange
    private(set) var sessionBlocks: [AppSessionBlockModel] = []
    private(set) var entries: [TimeEntry] = []
    private(set) var projects: [Project] = []      // for colors/names lookup
    var selection: TimelineSelection?
    var registeredTotal: TimeInterval { … }
    var trackedTotal: TimeInterval { … }

    func goToPreviousDay(); func goToNextDay(); func goToToday(); func go(to date: Date)
    func task() async      // starts observations for current day; restarts on day change
}
```
- Uses repository observations so the timeline updates live (the active app session grows; entries appear immediately after saving).
- Create/update/delete go through a separate `TimeEntryEditor` (injected), so the ViewModel stays focused on presenting the day.
- While viewing today, refresh the open session's end every 60s (the merger uses `now`).

---

### 6.9 Zoom, adaptive labels, hover card (v1.2, see PLAN-v1.2.md)
- **Zoom:** `TimelineZoom` has four levels (1 h = 80 pt, 30 min = 160, 15 min = 320, 10 min = 480 pt per hour; at the last one 10 minutes = 80 pt). `TimelineZoomState` (owned by `TimelineViewModel`) holds the level and remembers it in `UserDefaults`; `TimelineViewModel.geometry` is built from it. Controls: `TimelineZoomControls` in `DayNavigationBar` (− / level menu / +), ⌘− / ⌘+ (⌘=) / ⌘0, and trackpad pinch (`MagnifyGesture` as a simultaneous gesture on the scroll view, one level per 25% via `PinchZoomStepper`). Every change goes through `TimelineScreen.changeZoom`, which captures the time at the centre of the visible area (`ZoomScrollAnchor`, `TimelineZoomAnchor`) and scrolls so it stays centred. Snapping stays 5 minutes at all levels.
- **Grid:** `HourGridLayout` (pure) decides lines and labels per zoom level (labels every 60/30/15/10 min, minor lines every 15/15/5/5); `HourGridView` only draws it.
- **Adaptive labels:** `SessionLabelStyle.style(forHeight:width:)` picks `full` (>= 32 pt), `singleLine` (>= 15), `iconOnly` (>= 10) or `colorOnly`; narrow lanes drop the name. `AppSessionBlockLabel` renders it.
- **Hover card:** blocks report hover via `reportsHover(...)` to `TimelineHoverState` (`HoverTarget`, frame in the "timeline" space). `TimelineColumn` draws a single `TimelineHoverCard` overlay (`allowsHitTesting(false)`, no popover) placed by `HoverCardPlacement`; hidden during selection and entry drags. The old `.help` tooltips are gone.

## 7. Projects feature (detailed)

### 7.1 Layout
```
┌──────────────────────────────────────────────┐
│  ◀  October 2026  ▶   [This month]   [+ New] │  MonthNavigationBar + toolbar
├──────────────────────────────────────────────┤
│ ● Project A                         42:15   │  ProjectRow
│ ● Project B                         18:30   │
│ ● Internal / meetings                6:00   │
│ ─────────────────────────────────────────── │
│   Show archived ☐                            │
├──────────────────────────────────────────────┤
│   Total                             66:45    │  ProjectsTotalFooter
└──────────────────────────────────────────────┘
```

### 7.2 `ProjectsViewModel`
```swift
@Observable @MainActor final class ProjectsViewModel {
    private(set) var month: DateRange
    private(set) var rows: [ProjectMonthTotal] = []
    var showArchived = false
    var monthTotal: TimeInterval { rows.reduce(0) { $0 + $1.totalSeconds } }

    func goToPreviousMonth(); func goToNextMonth(); func goToCurrentMonth()
    func archive(_ project: Project); func unarchive(_ project: Project)
    func delete(_ project: Project) async   // shows error alert if project has entries
    func task() async                       // observe totals for current month
}
```
Sort rows: by total descending, then by name. Archived projects only shown when `showArchived` is on (they're shown when they have hours in that month regardless).

### 7.3 Add / edit
- `+ New` toolbar button (shortcut ⌘N) opens `ProjectFormSheet` backed by `ProjectFormViewModel` (name, color from `ProjectColor.palette`, validation: non-empty, unique name case-insensitively).
- Double-click or context menu "Edit…" on a row opens the same sheet in edit mode.
- Context menu: Edit…, Archive/Unarchive, Delete (disabled + explanatory tooltip if the project has entries).
- Hours format: `DurationFormatter` → `"42:15"` (hours:minutes). Keep the format in one place so it can become a preference (decimal hours `42.25` is common for timesheets — add as a setting later).

---

## 8. Root / navigation / app

- `TimeTrackerApp`:
  ```swift
  @main struct TimeTrackerApp: App {
      @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
      @State private var environment = AppEnvironment.live()
      var body: some Scene {
          Window("TimeTracker", id: "main") { RootView().environment(environment) }
              .defaultSize(width: 900, height: 750)
          MenuBarExtra("TimeTracker", systemImage: "clock") { MenuBarContentView().environment(environment) }
      }
  }
  ```
  Use `Window` (single window) rather than `WindowGroup`; the app doesn't need multiple windows.
- `AppEnvironment` holds: `AppDatabase`, the three repositories, `AppActivityTracker`, `TimeEntryEditor`. Provides `static func live()` and `static func preview()` (in-memory DB with sample data) for SwiftUI previews.
- `AppDelegate` gets the environment injected (or the tracker is started from `TimeTrackerApp`'s `init`), and starts tracking on launch.
- `RootView`: `NavigationSplitView` with a sidebar (`SidebarItem.timeline` "Timeline" ⌘1, `SidebarItem.projects` "Projects" ⌘2, `SidebarItem.trackedApps` "Tracked Apps" ⌘3) and the detail area showing the screen. Each screen creates its own ViewModel (`@State private var viewModel: TimelineViewModel`) from the environment.
- Commands: ⌘T → today (timeline) / this month (projects); ⌘← / ⌘→ previous/next day or month.

---

## 9. Implementation order (milestones)

Each milestone must build, run, and have its tests passing before moving on. Commit after each milestone.

1. **Project setup** — §2.1. App launches with an empty `RootView` and sidebar.
2. **Models + database + repositories** — §4. Migrations, GRDB records, repository implementations, `AppDatabase.inMemory()`. Tests: repository CRUD, monthly totals incl. month-boundary clipping, delete-with-entries refusal.
3. **Utilities** — `DateRange`, `DurationFormatter` + tests (incl. DST day).
4. **Projects screen** — §7. Fully usable: add/edit/archive, month navigation, totals (will be 0 until entries exist; seed via preview data to verify).
5. **App tracking** — §5. Tracker + idle + sleep/lock + menu bar + keep-alive. Tests: feed `ActivityEvent`s with a fake clock and assert stored sessions. Manually verify by switching apps for a few minutes.
6. **Timeline read-only** — §6.1–6.3. Hour grid, now indicator, app session lane, day navigation, totals. Tests: `TimelineGeometry`, `AppSessionMerger`.
7. **Timeline registering** — §6.4–6.6. Drag selection, project picker (incl. inline new project), click session to assign, overlap resolver. Tests: `TimeEntryOverlapResolver` (cover: no overlap, full cover, trim start, trim end, split, multiple overlaps).
8. **Timeline editing** — §6.7. Detail popover, delete, resize, move.
9. **Polish** — keyboard shortcuts, empty states ("No activity tracked yet"), error alerts, app icon, dark mode check, VoiceOver labels on blocks.

---

## 10. Extensibility (design for, don't build yet)

The structure above is chosen so these can be added without restructuring:

| Future feature | Where it plugs in |
|---|---|
| Auto-assign rules (e.g. "Xcode with repo X → Project A", suggested entries) | New `Services/Suggestions/` module that reads `AppSession`s and proposes `TimeEntry`s; shown as ghost blocks in `TimeEntryLane`. New table `assignmentRule` via migration. |
| Window title / Git repo / branch detection | Extra optional columns on `appSession` (new migration) + a separate collector service feeding the tracker's `ActivityEvent` (requires Accessibility permission). |
| Export (CSV / clipboard per month) | `Services/Export/` using `TimeEntryRepository.entries(in:)`; button on the Projects screen. |
| Integration with company timesheet systems (Jira Tempo, Harvest, …) | Protocol `TimesheetExporter` with one implementation per system; no changes to the core. |
| Tasks / sub-items / tags under a project | New table `task` with `projectId`; optional `taskId` on `timeEntry`. |
| Week view, reports, charts | New feature folder `Features/Reports/` reusing repositories and `DateRange`. |
| Settings (idle threshold, snap minutes, hour format, launch at login, pointsPerHour/zoom) | `Features/Settings/` + a `Settings` scene; values in a `SettingsStore` (UserDefaults) injected via `AppEnvironment`. Constants are already centralized (`TrackingSettings`, `TimelineGeometry`, `DurationFormatter`). |
| Sync / backup | Repository protocols allow a syncing implementation; `createdAt`/`updatedAt` columns are already present. |
| Data retention (purge app sessions older than N months) | Method on `AppSessionRepository`, triggered on launch. |

---

## 11. Coding conventions for the implementing agent

- One type per file; file name = type name. Extensions in `Type+Purpose.swift`.
- Views: no `async` business calls directly to repositories — always via the ViewModel. Extract a subview as soon as a `body` exceeds ~40 lines.
- ViewModels: `@Observable @MainActor final class`, dependencies via `init`, no SwiftUI view types inside, no GRDB imports.
- Pure logic (geometry, merging, overlap, date math) lives in structs/enums without side effects and is unit-tested.
- Errors: repositories `throw`; ViewModels catch and expose `var errorMessage: String?`; screens show it with `.alert`.
- Every View gets a `#Preview` using `AppEnvironment.preview()`.
- No force unwraps except for programmer errors with a clear message.
- No third-party dependencies besides GRDB.
- Strings in the UI are in English for now; wrap them so localization (e.g. Dutch) can be added later via a String Catalog.

---

## 12. Definition of done (v1)

- [ ] App runs on macOS, stays active in the menu bar when the window is closed, and records app sessions (paused on idle/sleep/lock).
- [ ] Timeline shows today's app sessions; navigating to other days works.
- [ ] Dragging over the entry lane creates a time entry for the chosen project; clicking an app session assigns the whole session.
- [ ] Entries can be edited, resized, moved, and deleted; overlaps are resolved automatically.
- [ ] Projects screen: add/edit/archive/delete projects, see hours per project per month, navigate months, see the month total.
- [ ] All data persists in SQLite across restarts.
- [ ] Unit tests for geometry, merger, overlap resolver, date ranges, repositories, and tracker pass.
- [ ] No file above ~250 lines.
