# AGENTS.md — working on Timelane

Guide for AI coding agents (and humans) picking up this project in a new session. Read this first; it tells you how the app is built, how to work on it, and which traps were already found the hard way. `README.md` describes the app for users/developers; `plans/` holds the design history.

## What the app is

Timelane is a native **macOS** app (SwiftUI, Swift 6) to register working hours per project.
- It records which **tracked apps** (an opt-in list) are in the foreground → *app sessions*.
- The **Timeline** shows one day in two lanes: left "Tracked apps" (automatic), right "Logged hours" (the user's *time entries*). The user drags over the timeline (or clicks an app session) and picks a project in a form to create an entry.
- **Projects** screen: monthly totals per project, month navigation, archive.
- **Tracked Apps** screen: manage which apps are recorded.
- **Menu bar panel** (`MenuBarExtra`): live tracking status, the same timeline, a popup form.
- **Record / Stop** timer: records a period and opens the entry form on Stop.
- All data is local (SQLite via GRDB) inside the app sandbox. No network.

Bundle ID `nl.nickkoepr.timelane`, version in the Xcode build settings (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`, app target), deployment target **macOS 26.0**, built with Xcode 27.x. Repo: github.com/NickKoepr/Timelane (private). The local folder may still be called `TimeTracker/`; everything inside is named Timelane.

## Build, test, run

```sh
# build + run all unit tests (Swift Testing, ~170 tests, ~3 s)
xcodebuild -project Timelane.xcodeproj -scheme Timelane -destination 'platform=macOS' -derivedDataPath build/DerivedData test

# build and (re)launch the Debug app
osascript -e 'quit app "Timelane"'
xcodebuild -project Timelane.xcodeproj -scheme Timelane -destination 'platform=macOS' -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/Timelane.app
```
- CI runs the same tests on every PR to `main` via `.github/workflows/tests.yml`, with ad-hoc signing overrides on the command line (`CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= ...`). If a test needs the owner's signing identity or local state, it will fail in CI.
- `build/` is git-ignored. Always use `-derivedDataPath build/DerivedData` so the user's running app is the one you just built.
- After every change: run the tests, then rebuild and relaunch the app so the user can try it.
- **Never** launch with `-resetDatabase YES` unless the user explicitly asks — that DEBUG-only argument deletes the user's database.
- You cannot see or drive the UI (no screenshots, no Accessibility). Reason carefully about layout/gestures and tell the user exactly what to check by hand.
- The SQLite file is in the sandbox container (`~/Library/Containers/nl.nickkoepr.timelane/Data/Library/Application Support/Timelane/db.sqlite`); the shell can't read it (macOS container protection). Verify persistence with tests and `os.Logger` output (`/usr/bin/log show --last 5m --predicate 'subsystem == "nl.nickkoepr.timelane"'`).

## Project layout

```
Timelane/                     app target (folder is a synchronized group: new files are picked up automatically)
  App/                        TimelaneApp (@main: Window + MenuBarExtra), AppDelegate (keep-alive, start tracker),
                              AppEnvironment (composition root: DB, repositories, tracker, editor, timer), WindowMetrics
  Models/                     plain value types: Project, TimeEntry, AppSession, TrackedApp, ProjectColor, ProjectMonthTotal
  Database/                   AppDatabase (live / inMemory, ValueObservation → AsyncStream, DEBUG reset), Migrations (v1, v2),
                              Records/ (GRDB conformances, dates as Unix Double)
  Repositories/               protocols (ProjectRepository, TimeEntryRepository, AppSessionRepository, TrackedAppRepository)
    GRDB/                     the GRDB implementations
  Services/Export/            MonthExport(+Builder/Service/FileName), Formats/ (MonthExportFormat, ExportFormats registry, JSON, Excel),
                              Spreadsheet/ (workbook model, XLSXWriter), Zip/ (stored ZipArchiveWriter, CRC32). To add an export format:
                              implement `MonthExportFormat` and add it to `ExportFormats.all` — nothing else changes.
  Services/                   DayTotals, TimeEntryOverlapResolver (pure), AppCandidates, AppIconProvider, RunningApps
    Tracking/                 AppActivityTracker (one serial ActivityEvent stream), SystemEventObserver (sleep/wake/lock),
                              IdleMonitor/IdleDetector, Heartbeat (crash recovery), TrackingStatus, TrackingSettings
    Timer/                    RecordingTimer (shared, persisted in UserDefaults), RecordedPeriod (pure rounding/midnight logic)
  Utilities/                  DateRange, DurationFormatter, Calendar helpers, StableColor, View+ErrorAlert
  Features/
    Root/                     RootView (NavigationSplitView, ⌘1/⌘2/⌘3), SidebarItem
    Timeline/
      Layout/                 PURE, unit-tested: TimelineGeometry, TimelineZoom, TimelineLaneLayout, AppSessionMerger,
                              SessionLabelStyle, HourGridLayout, EntryDragCalculator, HoverCardPlacement, ZoomTransition, ...
      ViewModels/             TimelineViewModel (+Recording), TimeEntryForm/FormViewModel, ProjectSearch, EntryEditingViewModel,
                              TimelineZoomState, ZoomScrollAnchor, TimelineHoverState, TimeEntryEditor, LastProjectStore,
                              TimeEntryHistory (undo/redo)
      Views/                  TimelineScreen, TimelineScrollArea (shared by window + menu bar), TimelineColumn, lanes, blocks,
                              DayNavigationBar (ViewThatFits variants), hover card, form sheet/content, RecordButton,
                              TimeEntryUndoShortcuts (⌘Z / ⇧⌘Z)
    Projects/                 ProjectsViewModel, ProjectFormViewModel + views
    TrackedApps/              TrackedAppsViewModel, AddTrackedAppViewModel + views (incl. NSOpenPanel wrapper)
  MenuBar/                    MenuBarContentView, MenuBarViewModel, status line, day bar, MenuBarFormPopup, PanelOpenObserver
  Assets.xcassets/            AppIcon, MenuBarIcon (template), AccentColor — generated by Tools/generate-app-icon.swift
TimelaneTests/                Swift Testing (`import Testing`, `@testable import Timelane`), in-memory DB, fake clocks
Tools/generate-app-icon.swift regenerates AppIcon + MenuBarIcon (same clock drawing)
plans/                        PLAN.md (base spec, §11 = conventions) + PLAN-v1.x.md (one file per iteration)
docs/icon.png                 README image
```

## Architecture rules (MVVM)

- **Models**: plain `struct`s, `Foundation` only. No GRDB/SwiftUI.
- **Repositories**: protocols in `Repositories/`, GRDB code only in `Repositories/GRDB/` and `Database/`. Observation is exposed as `AsyncStream` (via `AppDatabase.stream`), never GRDB types.
- **ViewModels**: `@MainActor @Observable final class`, dependencies through `init`, no SwiftUI view types and **no `import GRDB`**. They expose state + intent methods and an `async func task()` that observes repositories (`.task(id:)` in the view restarts it).
- **Views**: no business logic, never call repositories directly. Extract a subview when a `body` gets long.
- **Pure logic** (geometry, rounding, overlap, merging, layout) lives in structs/enums without side effects and is unit-tested.
- **Composition root**: `AppEnvironment` wires everything; `.live()`, `.inMemory()`, `.preview()` (sample data for `#Preview`). Hosted unit tests automatically get an in-memory environment and no tracking.
- Default actor isolation is *nonisolated* (project setting removed); mark main-actor types explicitly.
- All time-entry changes go through `TimeEntryEditor` → `TimeEntryOverlapResolver` (entries never overlap; newest action wins) → one repository transaction.
- **Undo/redo**: the shared `AppEnvironment.timeEntryEditor` reports every change as a `TimeEntryChange` (all touched rows before/after) to `TimeEntryHistory`; undo/redo write straight through the repository so they never record themselves. Automatic writers must use their own `TimeEntryEditor(repository:)` without `onChange`, so they stay off the undo stack.
- Schema changes: add a **new** migration (`v3`, …) in `Migrations.swift`; never edit `v1`/`v2`.

## Conventions

- One type per file, file name = type name; extensions as `Type+Purpose.swift`.
- Keep files small: aim < 150 lines, hard limit ~250. `TimelineViewModel.swift` is ~205 lines — put new timeline features in an extension file (like `TimelineViewModel+Recording.swift`) or a separate type instead of growing it.
- Every view has a `#Preview` using `AppEnvironment.preview()`.
- UI text in English. No new third-party dependencies (only GRDB).
- Match the surrounding code style and comment density.

## Workflow the owner uses

- The owner writes requests in Dutch; reply in Dutch. Code, comments, commit messages, README and plans are in English.
- For a feature/bugfix: write a plan `plans/PLAN-v1.N.md` (next free number; English, detailed enough for an agent: context, cause, design, files, tests, order of work, definition of done), implement it, run tests, commit.
- Work directly on `main` (no feature branches) unless asked for an experiment branch. Commit messages end with the Co-Authored-By line the session prescribes. The owner normally wants changes **committed and pushed** to `origin main`.
- Update `README.md` and `plans/PLAN.md` when behaviour changes, so they stay the source of truth.
- Releases: bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` (app target, Debug + Release) — the build number must go up for every App Store Connect/TestFlight upload; tag `vX.Y.Z` when asked.

## Known traps (learned the hard way)

- **Popovers on offset views**: blocks are positioned with `.offset(y:)`; a `.popover` attached to them anchors at the *layout* position (top of the day) and doesn't show. Use the sheet / popup that's already there, not per-block popovers.
- **MenuBarExtra panel**: a real `.sheet`/window from the panel makes it lose key and close, and makes the inactive app bounce in the Dock. That's why the menu bar uses `MenuBarFormPopup` (drawn inside the panel) and an inline error banner instead of alerts. `onAppear` only fires once — `PanelOpenObserver` detects each opening. `.background(.background)` is translucent there; use `panelBackground()`.
- **Keyboard shortcuts + `ViewThatFits`**: shortcuts on buttons inside multiple variants register twice or not at all. Register them once in hidden buttons (`DayNavigationShortcuts`, `TimelineZoomShortcuts`, `MonthNavigationShortcuts`, `RootView.sidebarShortcuts`).
- **Narrow windows**: bars use `ViewThatFits` variants with single-line, `fixedSize` texts; minimum window size is in `WindowMetrics` (700 × 520, detail ≥ 480). The menu bar panel is fixed at 380 × 600.
- **Lane alignment**: header, lanes, divider and tint all take x positions from `TimelineLaneLayout`; app lane = 1/3 (`TimelineMetrics.appLaneFraction`).
- **Loading states**: view models expose `isLoaded`; show empty states only after the first observed value (otherwise they flash).
- **Drag preview vs. observation**: a dropped entry keeps its drag preview (`isCommitting`) until `TimelineViewModel` observes the new rows (`EntryEditingViewModel.entriesDidChange`). Clearing it when the save returns makes the block flash back, because the GRDB observation arrives later.
- **Dates round-trip through Double**: stored dates are not bit-identical to in-memory `Date.now`; compare with what the database returns (`save` returns re-read rows) or with a tolerance.
- **Tracking rule**: the tracked-apps list only decides what is *recorded*; everything already recorded is always shown.
- **App icons**: never use SF Symbols in the app icon (licence); regenerate with `swift Tools/generate-app-icon.swift Timelane/Assets.xcassets/AppIcon.appiconset Timelane/Assets.xcassets/MenuBarIcon.imageset`. The Dock caches icons: `touch` the app and run `lsregister -f` on it after changing the icon.
- **Tests**: shared state (UserDefaults keys, timer store) must be injected with throw-away suites / in-memory stores in tests; one unexplained flaky run was seen once while the app was running.
