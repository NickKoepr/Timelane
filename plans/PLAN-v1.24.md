# PLAN v1.24 — Automatic entry survives app restarts (and short runs)

Follow-up on PLAN-v1.13/v1.14/v1.22 (automatic logged hours for apps linked to a project).
Branch `fix/auto-log-across-restarts` (from `main`).

## Context

Owner's report: Claude.app is linked to a project. The Timeline shows a continuous "Claude 9m" app
session up to now, but the "Logged hours" lane has **no automatic entry** for that time. During those
minutes Timelane was quit and relaunched many times (every rebuild). Requirement: as long as the app
session goes on, the automatic entry must keep being registered, also when Timelane restarts in between.

Evidence (unified log, 22:00–22:13): Timelane was relaunched ~15 times (PIDs 57766, 59416, 59517,
59666, 59784, 60218, 61415, 61634, 61818, 62061, 62228, 62416, 62604, 63625, 63810), often less than a
minute apart. Each relaunch via `open` also makes Timelane frontmost for a moment, which ends the Claude
session; the user then clicks back to Claude, which starts a new session. The Timeline merges these
sessions (`AppSessionMerger`, gap < 60 s) into one 9-minute block.

## Cause

`AutoTimeLogger` keeps all its state in memory:
- `run` (project + start of the current foreground run) and
- `entry` (`AutoLogEntry`: the entry it wrote and may keep growing).

1. **Lost on relaunch.** After a restart `entry == nil`, so `AutoLogPlanner`'s rule "written by an
   earlier run: continue it when the gap is small" can never apply across a restart. A new run starts
   at launch time and, at best, creates a separate new entry.
2. **Short-visit rule restarts every run.** The planner writes nothing until a run lasts
   `TimeEntryEditor.minimumDuration` (60 s). Every relaunch, and every short switch away (e.g. to the
   freshly launched Timelane), starts a new run from zero. Runs shorter than 60 s are dropped entirely —
   also on quit (`stop()` → `sessionEnded` → final step → `.nothing`). With relaunches/switches less than
   a minute apart nothing is ever written, while the Timeline shows one long merged session.
   Even when a run eventually reaches 60 s, its entry starts at the *latest* run start, so the time of the
   preceding short runs is missing.

## Design

### A. Persist the logger's state (`AutoLogStateStore`)

New file `Timelane/Services/Tracking/AutoLogStateStore.swift`, modelled on `HeartbeatStore`
(`Heartbeat.swift`):

```swift
/// Remembers what the automatic logger was doing, so a restart of Timelane continues it.
protocol AutoLogStateStore: AnyObject {
    var state: AutoLogState { get set }
}
final class UserDefaultsAutoLogStateStore: AutoLogStateStore { ... } // JSON (Codable) under key "autoLogState"; init(defaults: UserDefaults = .standard)
final class InMemoryAutoLogStateStore: AutoLogStateStore { ... }
```

New value type in `AutoLogPlanner.swift` (or its own file `AutoLogState.swift`, one type per file):

```swift
/// What survives a restart: the logger's own entry and a run that has not written anything yet.
struct AutoLogState: Equatable, Codable, Sendable {
    var entry: AutoLogEntry?
    /// A run of `projectId` that was too short to write an entry; a new run of the same project within
    /// `TrackingSettings.autoLogMergeGap` after `lastSeen` starts at `start` instead.
    var pending: AutoLogPending?
}
struct AutoLogPending: Equatable, Codable, Sendable {
    var projectId: Int64
    var start: Date
    var lastSeen: Date
}
```

Make `AutoLogEntry` `Codable` too. Dates in UserDefaults JSON: use the default `JSONEncoder`/`Decoder`
date strategy (Double since reference date) so they round-trip exactly; a broken/unknown blob decodes to
an empty `AutoLogState()`.

### B. Use the state in `AutoTimeLogger`

- `init(..., store: any AutoLogStateStore = InMemoryAutoLogStateStore(), now: ...)`.
- `load()`: also read `entry = store.state.entry` and the pending run.
- Every place that assigns `entry` (create / setEnd / delete / restart) also writes it to the store.
  Simplest: make `entry` and `pending` computed-through properties or add a `didSet` that saves
  `store.state`. Keep writes cheap (one JSON encode per tick is fine at 5 s).
- **Pending runs:**
  - While a run exists and the planner returned `.nothing` because the run is still shorter than the
    minimum (i.e. there is no own entry grown in this run), set
    `pending = AutoLogPending(projectId: run.projectId, start: run.start, lastSeen: at)` on every
    `tick()` and in the final step (`finish`). This also covers a crash/kill: the last tick is stored.
  - When an entry is created or extended for the run, clear `pending`.
  - `sessionStarted(bundleIdentifier:at:)`: after `finish(at:)`, when the app is linked to project `P`
    and `pending?.projectId == P` and `at.timeIntervalSince(pending.lastSeen) <= TrackingSettings.autoLogMergeGap`
    (and `>= 0`), start the run at `pending.start` instead of `at`. Otherwise drop `pending` when it is
    for another project or too old.
  - The link-change path in `observe()` must not carry a pending run over to a different project
    (it starts a new run for the new project; drop `pending`).
- Continuing the **own entry across a restart** needs no planner change: with `entry` restored, the
  existing rule "written by an earlier run: continue it when the gap is small" applies, and
  `ownEntry(until:)` still verifies the entry is intact (not deleted/moved/re-projected by the user,
  nothing in the way). If it is not intact, behave as today (new entry, never touch the user's entry).
- A pending start may lie before the merge gap of the restored entry; the planner's order already
  handles it (extend when `run.start - entry.lastEnd <= autoLogMergeGap`, otherwise create from
  `run.start`). Make sure a created entry never overlaps the logger's own restored entry in a way that
  shrinks it: if `run.start < entry.lastEnd` for the same project, prefer extending (add a planner test).

Keep the invariant in the doc comments: the logger only changes the end of its own entry; never the
project of an entry, never time recorded by the user. Update the doc comments of `AutoTimeLogger`
and `AutoLogPlanner` to mention that their state survives restarts and that short runs of the same
project within the merge gap add up.

### C. Wiring

- `AppEnvironment.init(database:recordingTimerStore:autoLogStore:)` with
  `autoLogStore: any AutoLogStateStore = InMemoryAutoLogStateStore()`; pass it to `AutoTimeLogger`.
- `AppEnvironment.live()` passes `UserDefaultsAutoLogStateStore()`. `inMemory()` / `preview()` keep the
  in-memory default, so tests and previews never touch the user's defaults.
- No database migration, no schema change.

## Files

- `Timelane/Services/Tracking/AutoLogStateStore.swift` (new; protocol + 2 implementations, < 60 lines)
- `Timelane/Services/Tracking/AutoLogState.swift` (new; `AutoLogState`, `AutoLogPending`)
- `Timelane/Services/Tracking/AutoLogPlanner.swift` (`AutoLogEntry: Codable`; planner tweak only if a
  test shows it is needed)
- `Timelane/Services/Tracking/AutoTimeLogger.swift` (keep < 150 lines; move the persistence helpers to
  `AutoTimeLogger+State.swift` if it grows)
- `Timelane/App/AppEnvironment.swift`
- Tests: `TimelaneTests/AutoTimeLoggerTests.swift` (or a new `AutoTimeLoggerRestartTests.swift`),
  `TimelaneTests/AutoLogStateStoreTests.swift`, `TimelaneTests/AutoLogPlannerTests.swift` if the
  planner changes.
- Docs: `README.md` and `plans/PLAN.md` where automatic logging is described (one sentence: it
  continues across restarts of Timelane; short visits of the same project within 2 minutes add up).

## Tests (Swift Testing, in-memory DB, `InMemoryAutoLogStateStore`, fake clock as in `LoggerFixture`)

"Restart" = a **new** `AutoTimeLogger` instance on the same database and the same store, `await load()`.
Extend `LoggerFixture` with a shared store and a `restart()` helper that replaces `logger`.

1. **Restart continues the entry.** Session xcode 0→3 min (ticks), `sessionEnded` at 3:00 (quit).
   Restart; `sessionStarted` at 3:10; run 2 min. → exactly one entry, 0:00 → 5:10.
2. **Crash continues the entry.** Same as 1 but no `sessionEnded` before the restart (last tick at
   3:00, restart at 3:30). → one entry 0:00 → end of new run.
3. **Frequent restarts never lose time (the owner's bug).** 10× { restart; `sessionStarted`; 40 s of
   ticks (5 s steps); `sessionEnded` }, 5 s between iterations. → one entry from the first start to the
   last end. On the old code this test produces no entry at all (write it first, see it fail).
4. **Short runs add up without restart.** xcode 40 s, safari 20 s, xcode 40 s → one entry from the
   first xcode start to the end of the second xcode run.
5. **Gap too large.** Pending run, then the next run of the same project starts after
   `autoLogMergeGap + 1 s` → the pending start is not used.
6. **Other project.** Pending run of project A; next run is an app linked to project B → B's entry
   starts at B's own session start.
7. **User changed the entry while Timelane was closed.** Restart after deleting (or moving / changing
   the project of) the restored entry → the logger does not recreate or change it; a new run creates
   its own entry.
8. **Store.** `UserDefaultsAutoLogStateStore` with a throw-away suite
   (`UserDefaults(suiteName: "test-\(UUID())")`, removed afterwards): round-trip of a full state with
   sub-second dates is exact; garbage data decodes to an empty state.
9. All existing tests stay green (including the sub-second date test of PLAN-v1.22).

## Order of work

1. Write tests 1, 3 against the current code; confirm they fail.
2. `AutoLogState` + store + store tests.
3. Logger changes (persisted entry, pending runs) + wiring in `AppEnvironment`.
4. Remaining tests; planner tweak only if needed.
5. Docs (README, PLAN.md).
6. Full test run with the command from `AGENTS.md`; rebuild + relaunch the Debug app
   (never with `-resetDatabase YES`).
7. Commit on `fix/auto-log-across-restarts` (message ends with the Co-Authored-By line).

## Definition of done

- Tests 1 and 3 fail on the old code and pass on the new code; all tests pass.
- No migration, no new dependency, no `import GRDB` outside `Database/` and `Repositories/GRDB/`.
- Manual check for the owner: with a linked app frontmost, quit and relaunch Timelane a few times
  within a few minutes (switching back to the linked app each time). The Logged-hours lane shows one
  automatic entry that starts at the first session start and keeps following the session.
