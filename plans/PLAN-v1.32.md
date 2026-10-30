# PLAN v1.32 — Remove the streak statistic from the Overview

## Context

The Overview screen (v1.20) shows five statistic tiles: Total hours · Active days · Average per active day ·
Longest streak · Busiest day. The "Longest streak" tile (with a "Current: N days" caption for the current year)
rewards logging hours every single day. Timelane is a tool to register *working* hours; days off and weekends
are normal, so a streak is the wrong incentive. The owner wants the statistic gone.

## Design

- Drop the "Longest streak" tile. The grid keeps its adaptive columns; four tiles remain:
  Total hours · Active days · Average per active day · Busiest day.
- Remove the streak logic from `ActivityStatistics` (`longestStreak`, `currentStreak`). Without it the type no
  longer needs the year, today or a calendar, so its initializer becomes `init(dailyTotals:)`.
- `OverviewStatTiles` loses its `showsCurrentStreak` parameter. `OverviewViewModel.isCurrentYear` stays (the
  year navigation still uses it).
- No schema, data or export change.

## Files

- `Timelane/Services/Activity/ActivityStatistics.swift` — remove streak properties and computation; simplify init.
- `Timelane/Features/Overview/ViewModels/OverviewViewModel+Derived.swift` — use `init(dailyTotals:)`.
- `Timelane/Features/Overview/Views/OverviewStatTiles.swift` — remove the tile, the parameter, `dayCount`; update
  doc comment and `#Preview`.
- `Timelane/Features/Overview/Views/OverviewScreen.swift` — stop passing `showsCurrentStreak`.
- `TimelaneTests/ActivityStatisticsTests.swift` — remove the streak tests and assertions.
- `README.md`, `plans/PLAN.md` — mention the four tiles and the removal (v1.32).

## Tests

- Delete `longestStreakAcrossMonthBoundary` and `currentStreak`; `emptyYear` no longer checks streaks.
- `busiestDayAndAverage` and `emptyYear` keep covering the remaining numbers.

## Order of work

1. Code changes above; build.
2. Update tests; run the full suite.
3. Update README and PLAN.md.
4. Rebuild and relaunch the app; commit on a branch and open a PR to `main`.

## Definition of done

- No "streak" left in app code, tests, README or PLAN.md (older plan files keep their history).
- The Overview shows four tiles that wrap neatly at the minimum window width.
- All tests pass; Release build compiles.
