# PLAN v1.14 — Project links only affect new time + idle-shrink fix

Follow-up on PLAN-v1.13 (same branch `feature/app-project-link`, PR #2).

## Context

The owner's rule, in their words: hours of an app are written to the project it is linked to,
**but only new hours**. Example: use Xcode 10 minutes linked to project A, change the link to B,
use it 10 more minutes → the timeline shows **A 10 min + B 10 min**, never 20 min on B.
"Keep previously registered data exactly as it was."

Current state (v1.13 code, `AutoTimeLogger` + `AutoLogPlanner`):
- On a link change for the active app, `observe()` calls `finish(at: now)` (A's entry keeps
  project A and ends at the change) and starts a new run for B at that moment. The planner never
  merges across projects and `ownEntry` requires the same `projectId`, so the logger never changes
  the project of an existing entry. **This already matches the rule, but nothing tests or documents
  it.** This plan makes it an explicit, tested invariant.
- **Bug (related: it rewrites already-registered time wrongly).** `AutoLogPlanner.plan` returns
  `.nothing` whenever `now - run.start < 60 s`, also for the *final* step. Scenario: switch to a
  linked app, type 30 s, walk away. The app stays frontmost, so ticks create the entry at +60 s
  and keep growing it. ~5 min later the idle detector closes the session with
  `at = run.start + 30 s`. `finish(at:)` → planner sees 30 s < 60 s → `.nothing` → the entry stays
  ~5 minutes too long (idle time logged). Same for any final step with `at` within the first minute
  of a run while the entry was already grown in that run.

## Design

### 1. Invariant: links apply to new time only

Document it in the doc comment of `AutoTimeLogger` and `AutoLogPlanner`:
"The logger only ever changes the end of its own entry for the current run. It never changes the
project of an existing entry and never touches time recorded before the current run (except
continuing its own entry across a small gap of the same project)."

Check the code against it and keep it true:
- `observe()`: link change of the active app → finish the old run at `now` (old project), new run
  from `now` (new project, or none when unlinked). Already so — keep it.
- The merge rule only merges when the stored entry has the **same project** and is intact. Already
  so — keep it.
- Unlinking an app or removing it from the tracked list never deletes or changes existing entries.

### 2. Fix the final step (idle shrink)

Give the planner a final flag: `plan(run:entry:entryIsIntact:now:isFinal:)` (or a separate
`planFinish(...)`). Add an action `case delete` to `AutoLogAction`.

For the final step only, when the entry is intact and was grown during this run
(`entry.lastEnd > run.start`):
- If `now < entry.lastEnd` (session ended in the past, e.g. idle `at:`): shrink to `now`. The 60 s
  guard on the *run* does not apply here.
- If the shrunk entry would be shorter than `TimeEntryEditor.minimumDuration`
  (`now - entry.start < 60 s`) → `.delete` (only possible when the entry was created in this run,
  because a merged entry started before the previous gap).
- A merged entry (started in an earlier run) is never shrunk below `run.start`: since
  `now ≥ run.start`, shrinking to `now` only removes time from this run — previous data stays as
  it was. Assert that in a test.

Non-final ticks keep today's behaviour. `AutoTimeLogger.step` handles `.delete` with
`editor.delete(stored)` (its own editor) and clears `entry`.

### 3. UI text

Tracked Apps footer: "Only these apps are recorded. Pick a project to log hours for it
automatically while you use the app. Changing the project only affects new hours." Keep the
`lineLimit` / `fixedSize` as is (check it still fits; 3 lines max).

## Files

- `Timelane/Services/Tracking/AutoLogPlanner.swift`, `AutoTimeLogger.swift`
- `Timelane/Features/TrackedApps/Views/TrackedAppsScreen.swift` (footer)
- Tests: `TimelaneTests/AutoLogPlannerTests.swift`, `TimelaneTests/AutoTimeLoggerTests.swift`
- Docs: `README.md` + `plans/PLAN.md` (one sentence: changing a link only affects new hours;
  idle time at the end of a run is removed), this plan as `plans/PLAN-v1.14.md`.

## Tests

Planner:
- Final step, entry grown this run, `now` < 60 s after run start → `.delete`.
- Final step, `now` < `entry.lastEnd` and ≥ 60 s after entry start → `.setEnd(now)`.
- Final step for a merged entry: result never ends before `run.start`.
- Non-final tick < 60 s still `.nothing` (unchanged).

Logger (in-memory DB, fake clock):
- **Owner's example:** app linked to A, active 10 min with ticks; link changed to B; 10 more min
  with ticks → exactly two entries: A [0, 10 min], B [10, 20 min]. A's entry unchanged after the
  change (same id, project, start, end).
- Link changed while the app is **not** active: earlier A entries unchanged; next use logs to B.
- Change A → B → A within 2 minutes: the B part is kept as its own entry if ≥ 1 min; A's old entry
  is not merged across a B entry.
- Unlink / remove the tracked app: existing entries unchanged.
- **Idle bug:** run starts, ticks grow the entry to +5 min, session ends with `at = start + 30 s`
  → no entry left. With `at = start + 3 min` → entry ends at +3 min.
- Merged entry + idle: previous entry part before the gap is untouched.

## Order of work

1. Copy this plan to `plans/PLAN-v1.14.md`.
2. Planner change + tests, then logger `.delete` + tests (write the idle-bug test first, see it fail).
3. Invariant tests for link changes; fix anything they reveal.
4. Footer text, README, PLAN.md.
5. Full test suite + build. Commit on `feature/app-project-link`, push → PR #2 updates. Add a short
   comment on PR #2 summarising the follow-up.

## Definition of done

- All tests pass; build succeeds.
- Changing a link never changes hours already on the timeline; new hours go to the new project.
- Idle time at the end of a run is never left on the timeline; too-short leftovers are deleted.
- PR #2 updated with the new commit and a comment.
