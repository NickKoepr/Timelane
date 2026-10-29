# PLAN v1.21 — Hover card for a day in the Overview heatmap

Branch: `feature/activity-overview` (same branch and PR as PLAN-v1.20, NickKoepr/Timelane#7).
Commit on this branch; do **not** merge into `main`.

## Goal

Hovering a square in the Overview heatmap shows a **hover card** (the same look as the Timeline's
hover card) with:

- the full date, e.g. "Tuesday 3 March 2026" (header, `.headline`);
- the total registered that day, e.g. "6h 30m registered" or "No hours registered"
  (`.caption`, `.secondary`);
- **per project**: color dot, project name (+ "Archived" in `.secondary` when archived) and its
  hours right-aligned (`.monospacedDigit()`), sorted by hours desc, then name. At most 5 rows; the
  rest is folded into one row "+N more" with their summed hours.

The card shows the day's **full** breakdown regardless of the project filter; when a filter is
active, that project's row is shown **bold** (so the square's brightness is still explainable).
Future days and days without hours show only the date and "No hours registered".

The current plain `.help(...)` tooltip on the squares is **removed** (otherwise the system tooltip
appears on top of the card). Keep the `accessibilityLabel`s.

Non-goals: entry times (first/last entry of the day), clicking inside the card, a card in the menu bar.

## Constraints

Same as PLAN-v1.20 (MVVM, pure logic unit-tested, one type per file, < 150 lines, `#Preview` for
every view, English UI, no new dependencies). Known trap: **no `.popover`** — draw the card as an
overlay that never takes hits, exactly like `TimelineHoverCard`.

## Design

### 1. Pure data — `Timelane/Features/Overview/ViewModels/OverviewDayDetail.swift`

```swift
/// What the hover card of one heatmap day shows.
struct OverviewDayDetail: Hashable, Sendable {
    struct Row: Hashable, Sendable {
        let projectId: Int64?        // nil for the "+N more" row
        let name: String             // project name, "Unknown project", or "+3 more"
        let colorHex: String?        // nil for the "+N more" row
        let isArchived: Bool
        let seconds: TimeInterval
        let isHighlighted: Bool      // the filtered project
    }
    let day: Date
    let totalSeconds: TimeInterval   // all projects, ignores the filter
    let rows: [Row]

    static let maximumRows = 5
    /// Builds the detail from one day's per-project seconds. Projects missing from `projects` become
    /// "Unknown project" (gray). More than `maximumRows` projects → first 4 + one "+N more" row.
    init(day: Date, secondsByProject: [Int64: TimeInterval], projects: [Project], highlightedProjectId: Int64?)
}
```
(If "first 4 + more" vs. "5 + more" feels ambiguous: show up to 5 project rows when there are
exactly 5; with 6 or more, show 4 + "+N more" so the card never exceeds 5 rows.)

### 2. View model

`OverviewViewModel+Derived.swift`: `func dayDetail(for day: Date) -> OverviewDayDetail`, using
`activity.secondsByDay[day] ?? [:]`, `projects` and `effectiveProjectId`.

### 3. Hover state + card — `Timelane/Features/Overview/Views/`

- `ActivityHeatmap` gets `dayDetail: (Date) -> OverviewDayDetail` as an extra input.
- Hovered day and its frame live in `@State` inside `ActivityHeatmap` (a small
  `@MainActor @Observable final class HeatmapHoverState` with `enter(day:frame:)` /
  `leave(day:)` that only clears when leaving the shown day — same rule as `TimelineHoverState`, so
  moving from one square straight to the next never flickers).
- Each square reports hover like `HoverReporting` does: `.onHover` + `.onGeometryChange` of its
  frame in a named coordinate space `"heatmap"` declared on the **outer** view of `ActivityHeatmap`
  (outside the horizontal `ScrollView`, so the frame stays correct while scrolled). To keep 371
  geometry observers cheap, only read the frame on hover enter if possible
  (e.g. store the frame per square only while hovered), otherwise the plain approach is fine.
- `HeatmapDayHoverCard` draws the card as an `.overlay(alignment: .topLeading)` on the outer
  view of `ActivityHeatmap`: `.padding(10)`, width 220, `.regularMaterial` background, 8 pt corner,
  stroke `Color.primary.opacity(0.12)`, shadow — copy the styling of `TimelineHoverCard`.
  `.allowsHitTesting(false)`, `.accessibilityHidden(true)`.
- `HeatmapDayHoverCardContent` renders an `OverviewDayDetail` (header, total, rows as described).
- **Placement**: reuse `HoverCardPlacement.origin(...)` with `block` = square frame,
  `opensToLeft = square.midX > heatmapWidth / 2`, `columnWidth` = heatmap width, `minX = 0`,
  `visibleTop = 0`, `visibleBottom = .infinity`/`columnHeight` = a large value so the card may hang
  below the heatmap rather than being squeezed. Estimate card height from the row count
  (≈ 44 + 18 × rows) like `HoverTarget.estimatedCardHeight`.
- The card must be drawn above the sections below the heatmap: give the heatmap section in
  `OverviewScreen` `.zIndex(1)`.
- Clear the hover on scroll of the horizontal heatmap scroll view and on `onDisappear`.

### 4. Screen

`OverviewScreen` passes `dayDetail: viewModel.dayDetail(for:)` to `ActivityHeatmap`.

## Files

New: `OverviewDayDetail.swift`, `HeatmapHoverState.swift`, `HeatmapDayHoverCard.swift`,
`HeatmapDayHoverCardContent.swift`; tests `TimelaneTests/OverviewDayDetailTests.swift`.
Changed: `ActivityHeatmap.swift`, `OverviewScreen.swift`, `OverviewViewModel+Derived.swift`,
`OverviewViewModelTests.swift`, `plans/PLAN.md` / `README.md` (one line about the hover card).

## Tests

- `OverviewDayDetail`: empty day; sort by seconds then name; exactly 5 projects → 5 rows;
  7 projects → 4 rows + "+3 more" with the summed seconds; unknown project id → "Unknown project";
  highlight only on the filtered project; total ignores the filter; archived flag carried.
- `OverviewViewModel.dayDetail(for:)`: with the in-memory environment, two projects on one day →
  correct rows; with a filter set, total unchanged and the filtered row highlighted.
- `HeatmapHoverState`: leaving a day that is not the shown one does not clear it.

## Definition of done

- All tests pass; no new warnings; files within limits; previews for the new views
  (content preview with literal `OverviewDayDetail`s: empty, 2 projects, 7 projects).
- No system tooltip anymore on the squares; the card appears next to the hovered square, flips to
  the left in the right half, is never clipped by the horizontal scroll view, and sits above the
  stat tiles.

### Manual check for the owner

1. Hover squares across the year: card with date, total and per-project hours; moving across
   squares updates it without flicker; leaving the grid hides it.
2. Squares near the right edge → card opens to the left. Bottom rows → card hangs over the tiles.
3. Set the project filter → that project is bold in the card; the total is still the whole day.
4. Narrow window (heatmap scrolls) → card still positioned at the hovered square.
