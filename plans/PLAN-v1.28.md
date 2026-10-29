# PLAN v1.28 — Automatic entry keeps pace when you return to a linked app

Follow-up on PLAN-v1.13 / v1.15 / v1.24 / v1.26 (automatic logged hours for a tracked app linked to a project).
Branch `fix/auto-log-resume-sync` (from `main`).

## Context

v1.26 made the running automatic entry draw up to the same `now` as the open app session
(`LiveAutoEntry` + `LiveEntryProjection`). The owner still sees the entry lag behind the app block:
the app block keeps growing while the logged-hours block stands still for about a minute and then
jumps. It happens after a short switch away from a linked app (⌘-Tab to another app and back),
and after a restart of Timelane.

## Cause

Coming back to the linked app starts a **new run** (`AutoTimeLogger.sessionStarted`). The run
continues the logger's own entry when the gap is small (`AutoLogPlanner`, "written by an earlier run"
branch), but:

1. **`AutoLogPlanner.plan` checks the one-minute minimum first.**
   `guard now.timeIntervalSince(run.start) >= TimeEntryEditor.minimumDuration else { return .nothing }`
   runs before the continuation branch, so for the first 60 s of the new run the entry is **not
   extended at all**. The minimum exists so that short visits (a quick ⌘-Tab) never *create* an entry.
   Continuing an entry that already exists is not a short visit and should not be held back.
2. **The live projection is off during that minute.** `AutoTimeLogger.publishLive()` only publishes the
   entry when `entry.lastEnd > run.start`. A continued entry still ends *before* the new run's start,
   so `LiveAutoEntry.entryId` is nil and the timeline draws the stored (old) end.
3. Meanwhile `AppSessionMerger` joins the two same-app sessions across the short gap, so the app block
   grows without a break. Result: up to ~65 s (60 s + one 5 s tick) of visible lag after every return.

Two smaller mismatches between the lanes:

4. **Different merge gaps.** `AppSessionMerger.mergeGap` (display) is 60 s; `TrackingSettings.autoLogMergeGap`
   (logger) is 2 min. A 90 s visit to another app shows as two app blocks with the other app in
   between, while the entry runs straight through it (and counts those 90 s for the project).
5. **Two copies of the one-minute minimum** (`AppSessionMerger.minimumDuration` and
   `TimeEntryEditor.minimumDuration`, both 60 s) with nothing tying them together.

Known and accepted (out of scope): when a brand-new entry is created, it appears at the logger's next
5 s tick after the app block reaches one minute, so at most one tick later.

## Design

Principle stays as in v1.26: the logger writes the stored row; the timeline draws the running
automatic entry up to its own `now`. What changes is *when* the logger considers an entry "running".

1. **One merge gap for both lanes.**
   - In `TrackingSettings` replace `autoLogMergeGap` with
     `static let mergeGap: TimeInterval = 60`, documented as: "Same-app sessions closer than this are
     drawn as one block, and an automatic entry of the same project continues across a gap this small."
   - `AppSessionMerger.mergeGap` becomes `TrackingSettings.mergeGap` (keep the static so call sites and
     tests keep working, or replace its uses — whichever keeps the diff small).
   - Update every `autoLogMergeGap` reference (`AutoLogPlanner`, `AutoTimeLogger`, `AutoLogState` doc,
     tests). Note in the README that a gap of more than one minute (also a restart of Timelane that takes
     longer than a minute) now starts a new automatic entry; it was two minutes.
2. **Tie the minimums together.** A pure layout type should not depend on `TimeEntryEditor`, so add
   `TrackingSettings.minimumBlockDuration: TimeInterval = 60` and use it for `AppSessionMerger.minimumDuration`.
   Leave `TimeEntryEditor.minimumDuration` as it is (it also validates manual entries) and add a test that
   both are equal, so changing one without the other fails.
3. **Planner: continuing is never held back** (`AutoLogPlanner.plan`). Move the "written by an earlier run"
   continuation *before* the one-minute guard:
   ```swift
   // Continuing the own entry across a small gap is not a short visit: extend it right away.
   if let entry, entry.projectId == run.projectId, entry.lastEnd <= run.start, entryIsIntact,
      run.start.timeIntervalSince(entry.lastEnd) <= TrackingSettings.mergeGap {
       return extend(entry, to: now)
   }
   guard now.timeIntervalSince(run.start) >= TimeEntryEditor.minimumDuration else { return .nothing }
   ```
   The final/idle branch at the top stays first and unchanged. The "grown during this run" branch
   (`entry.lastEnd > run.start`) stays after the guard, as today (`nonFinalTickWithinFirstMinuteStillDoesNothing`
   must keep passing). The `extend` helper already refuses `end == lastEnd`.
   **Correction found while implementing:** the continuation branch must also cover an entry that was already
   extended by this run (`entry.lastEnd > run.start`), otherwise it stalls after the first tick until the run is
   one minute old. So the pre-guard condition is: same project, `entry.start < run.start`, `entryIsIntact`,
   `run.start - entry.lastEnd <= mergeGap` (negative allowed) and `now > entry.lastEnd`. Entries created by the
   run itself (`entry.start >= run.start`) still wait for the minute.
   Consequence (intended): a short return (say 10 s) to the linked app followed by leaving again extends
   the entry to the moment of leaving (final step), exactly like the app lane merges those sessions.
4. **Logger: publish a continued entry immediately** (`AutoTimeLogger`).
   - Put the "this run owns/continues the entry" condition in **one** private helper, e.g.
     `private func continues(_ entry: AutoLogEntry, _ run: AutoLogRun) -> Bool`:
     `entry.projectId == run.projectId && run.start.timeIntervalSince(entry.lastEnd) <= TrackingSettings.mergeGap`
     (a negative gap — `lastEnd > run.start` — is included).
   - `publishLive()` uses it.
   - `sessionStarted` calls `publishLive()` at the end, so the projection starts in the same moment the
     session starts instead of at the first tick.
   - `notePending` keeps its current meaning ("this run has not written anything yet"): leave its
     condition `entry.lastEnd > run.start`. After the first step of a continuing run the entry has been
     extended, so that condition holds then anyway.
   - If the user has changed or deleted the entry, the projection may draw the stale id for at most one
     tick; `LiveEntryProjection` ignores ids that are not in the list, and the next step's `.restart` /
     `.create` publishes the correct state. That is acceptable; no extra database read in `sessionStarted`.
5. No changes to `LiveEntryProjection`, `TimelineViewModel` or the views.

## Files

- `Timelane/Services/Tracking/TrackingSettings.swift` — `mergeGap`, `minimumBlockDuration`.
- `Timelane/Services/Tracking/AutoLogPlanner.swift` — continuation before the guard; doc comment.
- `Timelane/Services/Tracking/AutoTimeLogger.swift` — `continues` helper, `publishLive`, `sessionStarted`.
- `Timelane/Services/Tracking/AutoLogState.swift` — doc reference to the renamed constant.
- `Timelane/Features/Timeline/Layout/AppSessionMerger.swift` — use the shared constants.
- `README.md`, `plans/PLAN.md` — behaviour notes (merge gap one minute; entry keeps pace on return).

## Tests (Swift Testing)

`AutoLogPlannerTests`:
- `mergesWithinGapOfSameProject` / `doesNotMergeOtherProjectOrLargerGapOrChangedEntry`: express the gaps
  with `TrackingSettings.mergeGap` (`at(-mergeGap)` merges, `at(-mergeGap - 1)` does not) instead of literal 120/121.
- New `continuationExtendsWithinFirstMinute`: previous entry ends `at(-30)`, run starts at 0,
  `now = at(5)` → `.setEnd(at(5))` (today: `.nothing`).
- New `continuationOfChangedEntryWaitsForTheMinute`: same but `entryIsIntact: false`, `now = at(5)` → `.nothing`.
- Existing `lessThanAMinuteCreatesNothing` and `nonFinalTickWithinFirstMinuteStillDoesNothing` unchanged and green.

`AutoTimeLoggerTests` (use the existing fakes / fake clock):
- New: run 2 min on a linked app (entry exists), switch to an unlinked app for 20 s, back to the linked app,
  advance 5 s and `tick()` → the stored entry end equals the new now (no one-minute wait), and
  `LiveAutoEntry.entryId` is the entry id right after `sessionStarted` (before any tick).
- New: same, but the return lasts 10 s and then `sessionEnded` → entry ends at that session end.
- New: gap larger than `TrackingSettings.mergeGap` → a second entry is created after one minute, the first
  entry is unchanged, and `entryId` is nil until the new entry exists.

`AppSessionMergerTests`: keep green; if a test uses a literal 60 s gap, express it with `TrackingSettings.mergeGap`.

New small test (e.g. in `AppSessionMergerTests`): `AppSessionMerger.minimumDuration == TimeEntryEditor.minimumDuration`.

`AutoTimeLoggerRestartTests`: already relative to the constant; update the name only.

## Order of work

1. Constants + renames (`TrackingSettings`, merger, all references); build and run tests.
2. Planner change + planner tests.
3. Logger helper / `publishLive` / `sessionStarted` + logger tests.
4. README and `plans/PLAN.md`.
5. Full test run.

## Definition of done

- All unit tests pass (`xcodebuild ... test`, see AGENTS.md).
- After returning to a linked app within one minute, the logged-hours block keeps growing with the app block
  from the first moment (stored end at most one 5 s tick behind, drawn end identical).
- A gap of more than one minute shows as separate blocks in both lanes.
- README and `plans/PLAN.md` describe the one-minute merge gap.
