# PLAN v1.22 — Automatic entry lags behind / stops growing

Follow-up on PLAN-v1.13/v1.14 (same branch `feature/app-project-link`, PR #2).

## Context

Owner's report (Claude.app linked to a project, in use from 21:37):
- The app session shows 21:37 → 21:40 (and keeps growing, 21:41 a minute later).
- The automatic time entry shows 21:38 → 21:39: it starts a minute late, ends a minute early and
  **stops growing** while the app is still in use.
- Requirement: the automatic entry must match the app usage exactly (same start, end follows the
  live session end).

## Cause

### 1. Dates do not survive the database round trip (main bug)

All records store dates as Unix `Double` (`databaseDateEncodingStrategy = .timeIntervalSince1970`).
`Date` stores `timeIntervalSinceReferenceDate`; converting a real `Date()` (sub-second fraction) to
`timeIntervalSince1970` and back changes it by one ULP in about **50 % of cases**
(verified: `Date(timeIntervalSince1970: d.timeIntervalSince1970) != d` for 4 992 of 10 000 samples).
Unit tests use whole-second dates, which round-trip exactly, so they never saw it.

`AutoTimeLogger` relies on exact `==` on stored dates:
- After `.create`, it finds its entry with `$0.start == range.start` → often not found → `entry = nil`.
- `ownEntry(until:)` requires `mine.start == own.start && mine.end == own.lastEnd` → often nil →
  the planner sees "changed by the user" → `.restart` → the run restarts **at now** (entry start
  moves later, nothing is written for another 60 s), and the old entry stops growing.

This gives exactly the symptoms: start ~1 min late, end frozen, entry not following the session.

### 2. Tick interval

`TrackingSettings.autoLogInterval = 30` s, so even when it works the end can be up to 30 s behind
the live session end (visible as "a minute behind" on the minute grid). The session itself only
gets its final end on close; the timeline draws an open session up to now.

## Design

### A. Tolerant date comparison in the logger

Add a small pure helper, e.g. `Date.isSameInstant(as:)` in `Timelane/Utilities/Date+SameInstant.swift`
(tolerance 1 ms — far below anything a user can produce by editing, which works in whole minutes),
and use it everywhere `AutoTimeLogger` compares a stored date with a remembered one:
- the lookup of the just-created entry (`start` match),
- `ownEntry(until:)` (`start` and `end` match).

Also remember the dates **as stored**: after create/update, take `start`/`end` from the entry read
back from the repository when available, so later comparisons start from the stored value.

Do not change the storage format or migrations (keep `v1`–`v3` as they are).

### B. Follow the session closely

Lower `TrackingSettings.autoLogInterval` to **5 s**. The planner already skips a write when the end
did not change; writes are a single small transaction. The final step on session end (switch,
idle, sleep, lock) already sets the exact session end — keep that.

### C. Start = session start

No planner change needed: the run starts at `session.start` and the entry is created with
`run.start`. With A fixed there is no spurious `.restart`, so the entry starts at the session start.

## Files

- `Timelane/Utilities/Date+SameInstant.swift` (new)
- `Timelane/Services/Tracking/AutoTimeLogger.swift`
- `Timelane/Services/Tracking/TrackingSettings.swift`
- Tests: `TimelaneTests/AutoTimeLoggerTests.swift` (+ a tiny test for the helper)
- Docs: `README.md` / `plans/PLAN.md` only if they mention the 30 s interval; this plan.

## Tests

- Helper: dates 0.5 ms apart are the same instant; 2 ms / 1 s apart are not.
- Logger with **sub-second dates** (e.g. base `Date(timeIntervalSinceReferenceDate: 783_000_000.123_456_7)`,
  pick values that do not round-trip — assert that in the test setup) and the real in-memory GRDB
  database (`AppDatabase.inMemory()` + GRDB repositories, as the existing logger tests do):
  - session start → ticks at +60 s, +65 s, +120 s → exactly one entry, start == session start
    (within 1 ms), end == last tick time; no restart.
  - session end at +150 s → entry ends at +150 s.
  - existing behaviour tests (user edit → restart, idle shrink, merge gap) still pass.
- All existing tests green.

## Order of work

1. Helper + test. 2. Logger changes + sub-second regression tests (write the test first, see it
fail). 3. Interval to 5 s. 4. Full test run, rebuild + relaunch the Debug app. 5. Commit.

## Definition of done

- The regression test with sub-second dates fails on the old code and passes on the new code.
- All tests pass with the command from `AGENTS.md`.
- Manual check for the owner: use a linked app for 3+ minutes; the logged-hours block starts at the
  same minute as the app session and its end follows the session within ~5 s; switching away ends
  both at the same moment.
