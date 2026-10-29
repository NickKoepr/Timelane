# PLAN v1.23 — Overview screen fits narrow windows

## Context

The main window has a minimum size (`WindowMetrics`: window 700 × 520, detail column ≥ 480 pt) so every
screen still lays out correctly when the window is made small. The Timeline, Projects and Tracked Apps
screens respect this. The **Overview** screen (`Features/Overview/`, v1.20/v1.21) does not: when the owner
makes the window narrower, the Overview content no longer fits — it gets wider than the detail column, is
cut off on one or both sides, and looks broken. It should behave like the other screens: at every width
down to the minimum the content fits the column and nothing is clipped.

## Cause

`ActivityHeatmap` (`Features/Overview/Views/ActivityHeatmap.swift`) decides its square size from its own
measured width:

```swift
let fitted = (width - labelWidth) / CGFloat(layout.columnCount) - spacing
let cell = min(max(fitted, 9), 16)
if fitted < 9 { ScrollView(.horizontal) { grid } } else { grid }
...
.frame(maxWidth: .infinity, alignment: .leading)
.onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
```

`width` is read from a `.frame(maxWidth: .infinity)` *without* `minWidth`. A flexible frame without a
minimum is never narrower than its child, so when the grid (not in a scroll view) is wider than the space
offered, the frame — and therefore the measured `width` — grows to the grid's width instead of the
offered width. That is a feedback loop with hysteresis:

1. Wide window: `fitted ≥ 9` → plain grid with fixed-size squares (≈ 53–54 columns × 11–18 pt).
2. The window shrinks: the offered width drops below the grid's width, but the frame stays as wide as
   the grid, so `width` (and `fitted`) never drop below the threshold. The heatmap never switches to its
   horizontally scrolling variant and stays at ≈ 54 × 11 + 32 ≈ 626 pt.
3. The heatmap's width becomes the width of the whole `content` `VStack` inside the vertical `ScrollView`
   in `OverviewScreen`, so the entire screen (title, tiles, chart, project list, legend) is laid out
   wider than the detail column and gets clipped/misaligned.

(It only "works" if the screen happens to be first opened at a narrow width, because then the first
measurement is small.)

## Design

### 1. Measure the offered width, not the content width

The width the heatmap uses for its decision must be the width its parent offers, independent of the
grid's size. Change the outer frame to

```swift
.frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
```

so the frame always takes the proposed width (a flexible frame with `minWidth: 0` is not forced to the
child's size). Then the `onGeometryChange` reading reports the real available width, `fitted` drops below
the threshold as the window narrows, and the horizontally scrolling variant (already there, newest weeks
in view via `.defaultScrollAnchor(.trailing)`) takes over. Growing the window back makes the squares grow
again — no hysteresis in either direction.

Keep the hover card overlay behaviour (it uses `width` as `heatmapWidth`; with this fix that is the
visible width, which is what `HoverCardPlacement` wants).

### 2. Extract the sizing rule into a pure, tested type

Per the project rules (pure logic lives in side-effect-free types and is unit-tested), move the square
size decision out of the view into `Services/Activity/ActivityHeatmapSizing.swift`:

```swift
/// Square size of the heatmap for an available width: grows to fill (9–16 pt), scrolls below 9 pt.
struct ActivityHeatmapSizing: Equatable, Sendable {
    let cell: CGFloat
    let scrolls: Bool
    init(availableWidth: CGFloat, columnCount: Int, labelWidth: CGFloat, spacing: CGFloat,
         cellRange: ClosedRange<CGFloat>)
}
```

`ActivityHeatmap.body` uses it instead of the inline computation. Guard against `columnCount == 0` and
`availableWidth <= 0` (→ smallest cell, scrolls — same as today's first frame where `width == 0`).
`import CoreGraphics` / `Foundation` only, no SwiftUI.

### 3. Audit the rest of the Overview at 480 pt

After the heatmap fix, check every other Overview subview for anything that can force the content wider
than ~448 pt (480 detail − 2 × 16 padding), and fix only what actually overflows:

- `YearNavigationBar`: already a `ViewThatFits` with a compact variant; verify the compact variant fits
  480 with a long project name selected in the `.fixedSize()` picker. If a long project name can push it
  past the width, cap the picker (e.g. `.frame(maxWidth: 180)` instead of a fully fixed size, keeping the
  label truncating) — only if needed.
- `OverviewStatTiles`: adaptive grid (min 140) — fits; leave it.
- `OverviewMonthlyChart`: flexible width — fits; leave it.
- `OverviewProjectList`: name 80–200, bar flexible, hours ≥ 64, share 40 — fits at 448; leave it unless
  the audit shows otherwise.
- `ActivityLegend` and the `heading` text: small; leave them.
- `OverviewScreen`: the `content` `VStack` should take exactly the scroll view's width; adding
  `.frame(maxWidth: .infinity, alignment: .leading)` to `content` is fine if it helps alignment, but do
  not add fixed widths.

Do not change `WindowMetrics` — the screen must fit the existing minimum, not the other way round.

## Files

- `Timelane/Services/Activity/ActivityHeatmapSizing.swift` (new, pure)
- `Timelane/Features/Overview/Views/ActivityHeatmap.swift` (use the sizing type; `minWidth: 0` frame;
  update the doc comment if needed)
- Possibly `Timelane/Features/Overview/Views/YearNavigationBar.swift` (only if the audit finds overflow)
- `TimelaneTests/ActivityHeatmapSizingTests.swift` (new)
- `plans/PLAN-v1.23.md` (this file); `plans/PLAN.md`: add a line under the Overview requirement (R14)
  that the Overview fits the minimum window width and the heatmap scrolls horizontally when narrow.
  README only if it describes heatmap sizing (it currently doesn't — then leave it).

## Tests (`ActivityHeatmapSizingTests`, Swift Testing)

With `labelWidth 32`, `spacing 2`, `cellRange 9...16`, `columnCount 53`:
- wide width (e.g. 2000) → `cell == 16`, `scrolls == false` (clamped to max).
- width where fitted is in range (e.g. `32 + 53 × 14 = 774` → cell 12) → `cell == 12`, no scroll.
- exactly at the threshold (`32 + 53 × 11 = 615`) → `cell == 9`, no scroll.
- just below (`614`) and the minimum detail width minus padding (`448`) → `cell == 9`, `scrolls == true`.
- `availableWidth == 0` and `columnCount == 0` → `cell == 9`, `scrolls == true`, no crash / NaN.
- monotonic: shrinking then growing the width gives the same result for the same width (no state).

All existing tests stay green.

## Order of work

1. `ActivityHeatmapSizing` + tests (run them).
2. Use it in `ActivityHeatmap`, change the frame to `minWidth: 0`.
3. Audit the other Overview views at 480 pt (reason with the layout rules; previews `"480"` exist in
   `OverviewScreen` and `YearNavigationBar`); fix only real overflow.
4. Update `plans/PLAN.md`.
5. Full test run (command in `AGENTS.md`), rebuild and relaunch the Debug app.

## Definition of done

- All tests pass with the `AGENTS.md` command.
- No change to `WindowMetrics` or to other screens.
- Manual check for the owner: open Overview with a wide window, then drag the window to its minimum
  width — the heatmap switches to a horizontally scrollable strip (latest weeks visible), and the
  title, tiles, chart and project list all fit the column without being clipped. Make the window wide
  again — the squares grow back to fill the width. Hover cards and clicking a square still work, also
  while the heatmap is scrolled.
