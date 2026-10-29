# PLAN v1.26 — Automatic entry grows in step with the app session

Follow-up on PLAN-v1.13 / v1.15 / v1.24 (automatic logged hours for a tracked app linked to a project).
Branch `fix/auto-log-live-sync` (from `main`). PLAN-v1.25 is used on `feature/tracked-apps-project-column`.

## Context

The owner keeps a linked app (Claude) in the foreground. The app lane shows the Claude block at
"24m", but the automatic time entry next to it only reaches "24m" near the end of that minute, just
before the session goes to 25. After two earlier fixes (v1.15 tolerance + 5 s ticks, v1.24 restarts)
the two blocks are still not in sync.

## Cause

The two lanes are fed by two independent clocks and two different writers:

- **App lane**: the open session has no end in the database. `TimelineViewModel` draws it until its own
  `now`, which it refreshes on a 30 s loop (`tick()`) and whenever a session row changes
  (`AppSessionMerger.blocks(..., now:)`, `DayTotals.tracked(..., now:)`).
- **Logged-hours lane**: the automatic entry only grows when `AutoTimeLogger` writes a new `end`
  (`AppActivityTracker.runAutoLogTicks`, nominally every 5 s) and the GRDB observation delivers it.
  Timelane is a background app while the linked app is frontmost, so these `Task.sleep` ticks can be
  delayed/coalesced by macOS (timer coalescing, App Nap); the stored end can be tens of seconds old.
  On top of that the block's start comes from `AppSessionMerger` (merge gap 60 s, drops < 60 s
  fragments) while the entry's start comes from the logger's own rules (`autoLogMergeGap` 2 min,
  pending short runs), so they are not guaranteed to be equal either.

Any lag in either path shows up as a minute label flipping at a different moment. Tuning intervals
cannot make this exact; the display must use **one clock** for both.

## Design

Principle: the *stored* automatic entry is still written by the logger as today (it is the source of
truth for totals, exports, undo-free automatic writes). The *displayed* running automatic entry ends at
the timeline's `now` — the very same value that ends the open session block — so both labels change
in the same frame.

1. **`LiveAutoEntry` state** (new, `Services/Tracking/LiveAutoEntry.swift`):
   `@MainActor @Observable final class LiveAutoEntry { private(set) var entryId: Int64? }` with an
   internal setter used by the logger. Created once in `AppEnvironment` and passed to the
   `AutoTimeLogger` and to every `TimelineViewModel` (window + menu bar; previews/tests get a fresh
   instance via a default argument). View models depend on this small type, not on the logger.

2. **`AutoTimeLogger` publishes its running entry**: `entryId` is the id of `entry` while a run is
   active *and* that entry belongs to the run (the same condition `notePending` uses:
   `entry.projectId == run.projectId && entry.lastEnd > run.start`, i.e. created or continued in this
   run). Set it after every `step` and clear it in `finish(at:)` (session end, idle, link change),
   on `.restart` and `.delete`. Keep this in one private helper (`publishLive()`), called at the end of
   `step` and after `run = nil`. No behaviour change of what is written.

3. **Pure projection** (new, `Features/Timeline/Layout/LiveEntryProjection.swift`):
   `static func displayed(_ entries: [TimeEntry], liveEntryId: Int64?, now: Date) -> [TimeEntry]` —
   for the entry with `id == liveEntryId` and `end < now`, return a copy with `end = now`, but never
   past the start of the next stored entry that starts after it (entries never overlap on screen).
   Everything else unchanged. Pure, no side effects, unit-tested.

4. **`TimelineViewModel`** (it is ~205 lines: put the new code in
   `TimelineViewModel+LiveEntry.swift`, only minimal edits in the main file):
   - Store the raw observed rows privately (e.g. `storedEntries`) and expose `entries` as the projected
     list (`LiveEntryProjection.displayed(storedEntries, liveEntryId: liveAutoEntry.entryId, now: now)`),
     only when `isToday`. `registeredTotal`, `hasActivity` and `TimeEntryLane` then use the same
     projected values, so the day totals ("Registered") also move in step with "Tracked".
   - `entryEditing.entriesDidChange` keeps receiving the **stored** rows (drag preview logic).
     Edit/drag/delete of the live entry start from the stored row (look up by id) so the user never
     saves a projected end by accident — check `TimeEntryLane`, hover card, form and context menu paths.
   - One clock: the `tick()` loop refreshes `now` every `TrackingSettings.autoLogInterval` (5 s)
     instead of 30 s, and only does so while `isToday` (other days need no refresh). `now` is the
     single value used by sessions, totals and the projection.

5. **Wiring**: `AppEnvironment` gets `let liveAutoEntry = LiveAutoEntry()`, passes it to
   `AutoTimeLogger(..., live: liveAutoEntry)` and to the `TimelineViewModel` inits in
   `TimelineScreen`, `MenuBarViewModel` and the `DayNavigationBar` preview. Default arguments keep
   tests and previews compiling.

Out of scope: changing what the logger writes, the merge gap values, or the session merger.

## Files

- new `Timelane/Services/Tracking/LiveAutoEntry.swift`
- new `Timelane/Features/Timeline/Layout/LiveEntryProjection.swift`
- new `Timelane/Features/Timeline/ViewModels/TimelineViewModel+LiveEntry.swift`
- `Timelane/Services/Tracking/AutoTimeLogger.swift`
- `Timelane/Features/Timeline/ViewModels/TimelineViewModel.swift` (minimal)
- `Timelane/App/AppEnvironment.swift`, `Timelane/Features/Timeline/Views/TimelineScreen.swift`,
  `Timelane/MenuBar/MenuBarViewModel.swift`, `Timelane/Features/Timeline/Views/DayNavigationBar.swift`
  (preview), possibly `TimeEntryLane.swift` / editing paths for the stored-row lookup
- tests: new `TimelaneTests/LiveEntryProjectionTests.swift`, additions to
  `TimelaneTests/AutoTimeLoggerTests.swift` and the existing `TimelineViewModel` tests
- `README.md`, `plans/PLAN.md` (one line: the running automatic entry is shown live, in step with
  the app session)

## Tests

- `LiveEntryProjectionTests`: extends the live entry to `now`; leaves it when `now <= end`; leaves
  everything when `liveEntryId` is nil or not found; stops at the next entry's start; other entries
  untouched.
- `AutoTimeLoggerTests`: `entryId` is nil before the first minute, set after the entry is created,
  kept while extending, set when an earlier entry is continued across a small gap, cleared on
  `sessionEnded`, on a link change and when the user deleted/changed the entry (`.restart`).
- `TimelineViewModel` (fake clock, in-memory repositories): an open session started at T and a live
  automatic entry stored until T+60 s; at `now = T+23m40s` the session block and the displayed entry
  both have duration 23m40s and `DurationFormatter.short` gives the same label; the stored row passed
  to `entryEditing` still ends at T+60 s; on another day nothing is projected.
- All existing tests stay green.

## Order of work

1. `LiveEntryProjection` + tests.
2. `LiveAutoEntry` + logger publishing + tests.
3. Timeline view model extension, wiring, editing paths use stored rows; tests.
4. 5 s refresh for today.
5. README / PLAN.md, run the full test suite, build the Debug app.

## Definition of done

- Running the tests passes (`xcodebuild ... test` with `-derivedDataPath build/DerivedData`).
- With a linked app in front, the session label and the automatic entry label in the timeline (window
  and menu bar panel) and the Registered/Tracked totals change minute at the same moment (check by
  hand; the owner does this).
- Dragging/editing the running automatic entry behaves as before (uses the stored row).
- One commit on `fix/auto-log-live-sync` with this plan, code, tests and docs.
