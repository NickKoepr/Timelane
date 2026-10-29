# PLAN v1.13 — Link a tracked app to a project (automatic logged hours)

## Context

On the **Tracked Apps** screen the user wants to pick, per app, a project. While that app is in
the foreground (and tracking is not paused), a **time entry** for that project is created
automatically and grows live, so it is visible in the timeline's "Logged hours" lane while the
user is still working (not only after leaving the app). No title or note. The entry is a normal
time entry: the user can edit/move/resize/delete it like any other.

Relevant code:
- `TrackedApp` model, `TrackedAppRepository` / `GRDBTrackedAppRepository`, `Migrations` (v1, v2).
- `AppActivityTracker` (main actor) opens/closes `AppSession`s for tracked apps
  (`switchSession(to:)`, `closeSession(at:)`); pauses on sleep/lock/idle (idle closes at the moment
  input stopped).
- `TimeEntryEditor` (create/update/delete via the overlap resolver; minimum duration 60 s).
- `TrackedAppsScreen`, `TrackedAppsViewModel`, `TrackedAppRow`.
- `TrackingSettings` holds tracking constants.

## Design (keep it simple)

### 1. Data

- `TrackedApp.projectId: Int64?` (default nil in init).
- Migration **`v3`** (new; never edit v1/v2): `ALTER TABLE trackedApp ADD COLUMN projectId INTEGER
  REFERENCES project(id) ON DELETE SET NULL`. (GRDB: `db.alter(table:) { t in t.add(column: "projectId", .integer).references("project", onDelete: .setNull) }`.)
  Update `TrackedApp+Record` if it lists columns explicitly. Add a `MigrationTests` case.
- `TrackedAppRepository.setProject(_ projectId: Int64?, forAppId id: Int64) async throws`.

### 2. Tracked Apps UI

- `TrackedAppsViewModel` also gets the `ProjectRepository`, observes non-archived projects
  (`observeProjects(includeArchived: false)`) in `task()` next to the tracked apps (two child
  tasks / `async let`-style, or a `withDiscardingTaskGroup`), and has
  `func setProject(_ projectId: Int64?, for app: TrackedApp) async`.
  If an app is linked to an archived project, still show that project as the current choice
  (include it in the options for that row).
- `TrackedAppRow` gets a compact `Picker` (menu style, label hidden, `fixedSize`) with "No project"
  plus the projects (color dot + name if easy, otherwise just name). Keep the row on one line;
  window minimum width is small (see `WindowMetrics`, detail ≥ 480) — test mentally that name +
  picker + remove button fit; let the name truncate.
- Update the footer text: "Only these apps are recorded. Pick a project to log hours for it
  automatically while you use the app."
- Update `TrackedAppsScreen` init and `#Preview`s.

### 3. `AutoTimeLogger` (Services/Tracking/AutoTimeLogger.swift, `@MainActor final class`)

Turns "app X with project P is active" into a growing time entry.

Dependencies: `TimeEntryRepository`, its **own** `TimeEntryEditor(repository:)` instance (never
`AppEnvironment.timeEntryEditor` — another branch adds undo history to that shared editor and
automatic writes must not end up on the undo stack), `TrackedAppRepository`, `now: () -> Date`.

State: `projectByBundleId: [String: Int64]` (kept current by observing tracked apps),
`active: (projectId, start)?`, `current: (entryId, projectId, lastEnd)?` (the entry it is growing).

API (called by the tracker, all on the main actor):
- `func sessionStarted(bundleIdentifier: String, at: Date) async` — if the app has a project:
  `active = (project, at)`.
- `func sessionEnded(at: Date) async` — finalize: write `end = at` if an entry exists (or create
  one if `at - start ≥ 60 s`), then `active = nil`.
- `func tick() async` — called every `TrackingSettings.autoLogInterval` (new constant, 30 s) by
  the tracker's loop: if `active` and `now - start ≥ TimeEntryEditor.minimumDuration`, create or
  extend the entry to `now`.
- When the tracked-app mapping changes for the active app (project changed / unlinked): end the
  current one at now and start a new `active` with the new project (or none).

Rules:
- **Appears after 1 minute.** Entries shorter than the editor minimum (60 s) are never created, so
  quick ⌘-Tab visits don't produce entries. After that the entry is extended every 30 s, so the
  user sees it grow in the "Logged hours" lane.
- **Create**: `editor.create(projectId:, range: start…now, note: nil)`; then find its id with
  `repository.entries(in: range)` (the entry with that `projectId` and `start`). Do not change
  `TimeEntryEditor`'s public signatures (avoids merge conflicts with the undo branch).
- **Extend**: re-read the entry (by id via `entries(in:)` around `lastEnd`). It is still "ours"
  only when it exists, has the same `projectId` and `end == lastEnd`. Then
  `editor.update(entry with end = now)`, store `lastEnd = now`.
  If it is **not** ours any more (user deleted it, resized it, changed its project, or another
  entry trimmed it), stop touching it and start a fresh entry from `now` (new `active.start = now`).
  User edits always win; the logger never grows an entry back over the user's change.
- **Merge small gaps**: when creating, if the last entry the logger wrote has the same project, is
  still ours, and ended ≤ `TrackingSettings.autoLogMergeGap` (2 min) before the new start, extend
  that entry instead of creating a new one. This keeps Xcode ↔ Simulator (both on the same
  project) or a short look at Mail as one block.
- Pauses (sleep/lock/idle) close the session in the tracker → `sessionEnded(at:)` with the
  session's end, so idle time is not logged.
- Errors: store in an `errorMessage` like the tracker does (the tracker already surfaces its own
  `errorMessage`); don't crash, don't alert from the logger.
- Put the decision logic ("given state + now → create / extend / restart / nothing") in a small
  **pure** type (e.g. `AutoLogPlanner`) so it is unit-tested without a database.

### 4. Wiring

- `AppActivityTracker` gets an optional `autoLogger: AutoTimeLogger? = nil` in `init` (existing
  tests keep working). Call `sessionStarted` after a session opens in `switchSession(to:)`,
  `sessionEnded(at:)` in `closeSession(at:)`, and start a `tick` loop in `start()` next to the
  heartbeat task (cancelled in `stop()`). Keep the tracker under ~250 lines; if it grows, move the
  hooks to an extension file `AppActivityTracker+AutoLog.swift`.
- `AutoTimeLogger` observes `trackedApps.observeTrackedApps()` itself for the mapping (start it from
  the tracker's `start()` tasks, or give the logger its own `start()`).
- `AppEnvironment.init`: create `AutoTimeLogger(timeEntries: timeEntries, trackedApps: trackedApps)`
  and pass it to the tracker. Hosted unit tests don't run tracking, so nothing changes there.

## Files

- New: `Services/Tracking/AutoTimeLogger.swift`, `Services/Tracking/AutoLogPlanner.swift` (pure),
  maybe `AppActivityTracker+AutoLog.swift`.
- Changed: `Models/TrackedApp.swift`, `Database/Migrations.swift`, `Database/Records/TrackedApp+Record.swift`
  (if needed), `Repositories/TrackedAppRepository.swift`, `Repositories/GRDB/GRDBTrackedAppRepository.swift`,
  `Services/Tracking/AppActivityTracker.swift`, `Services/Tracking/TrackingSettings.swift`,
  `App/AppEnvironment.swift` (+ preview: link one sample app to a project),
  `Features/TrackedApps/ViewModels/TrackedAppsViewModel.swift`, `Features/TrackedApps/Views/TrackedAppRow.swift`,
  `Features/TrackedApps/Views/TrackedAppsScreen.swift`.
- Docs: `README.md`, `plans/PLAN.md` (tracking section + data model), this plan as `plans/PLAN-v1.13.md`.

## Tests (Swift Testing, in-memory DB, fake clock — see `AppActivityTrackerTests`)

- Migration v3: column exists, existing tracked apps get `projectId = nil`, deleting a project sets
  it to nil.
- Repository `setProject`.
- `AutoLogPlanner`: < 60 s → nothing; ≥ 60 s → create; later tick → extend; entry changed by user →
  restart from now; merge within 2 min gap of same project; no merge for other project or larger gap.
- `AutoTimeLogger` with in-memory DB + fake clock:
  - linked app active 5 min with ticks → one entry start…now for the project, no title/note.
  - session ends after 40 s → no entry.
  - session ends (idle `at:`) → entry ends at that time.
  - user deletes the entry mid-session → next tick creates a new entry starting at that tick.
  - two apps on the same project with a 30 s gap → one entry.
  - unlinked app → no entries.
- `TrackedAppsViewModel.setProject` updates the repository.
- Tracker integration: tracker with an auto logger, app activated → after ticks an entry exists.

## Order of work

1. `git checkout -b feature/app-project-link` from `main`. Copy this plan to `plans/PLAN-v1.13.md`.
2. Model + migration v3 + repository + tests.
3. Tracked Apps view model / row / screen.
4. `AutoLogPlanner` + tests, then `AutoTimeLogger` + tests.
5. Wire into tracker and `AppEnvironment`.
6. README / PLAN.md.
7. Run all tests, build. Commit (message ends with the Co-Authored-By line), push branch, open PR.

## Definition of done

- All tests pass; app builds; no new dependencies; files < ~150 lines where possible.
- A tracked app can be linked to a project (or "No project") on the Tracked Apps screen.
- Using a linked app for ≥ 1 minute shows an entry for its project in "Logged hours" that grows
  every ~30 s while the app stays active; it stops at app switch / idle / sleep / lock.
- The entry can be edited like any other; after a user edit the logger never overwrites it.
- PR open on GitHub from `feature/app-project-link` to `main` with a summary and a manual test checklist.
