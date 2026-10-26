# TimeTracker v1.2 — Readable app sessions: zoom, adaptive labels, hover card

Context: v1 and v1.1 (PLAN.md, PLAN-v1.1.md) are implemented on branch `feature/v1-implementation`. User feedback: short app sessions on the timeline show no app name, so the user can't tell which app a small block is. At the current scale (`TimelineGeometry.defaultPointsPerHour = 80`, so 1 min ≈ 1.3pt) `AppSessionBlock` only shows the icon from 18pt (~14 min) and the name from 30pt (~23 min).

Agreed solution (three parts):
1. **Zoom** the timeline, down to a level where 10 minutes = 80pt.
2. **Adaptive labels** on app-session blocks: show as much as fits.
3. **Hover card**: hovering a block immediately shows icon, name, times and duration.

Explicitly NOT doing: a minimum block height (would overlap neighbours and distort time), and merging short interruptions (maybe later).

All conventions from PLAN.md §11 apply (MVVM, one type per file, files < 150 lines / hard limit ~250, pure logic unit-tested, no new dependencies). `TimelineViewModel.swift` is already ~196 lines — do NOT grow it; put zoom state in its own type.

---

## 1. Zoom

### 1.1 Model — `Features/Timeline/Layout/TimelineZoom.swift` (pure, tested)
```swift
enum TimelineZoom: Int, CaseIterable, Comparable, Sendable {
    case hour = 0        //  80 pt per hour  (overview, current behaviour)
    case halfHour        // 160 pt per hour
    case quarterHour     // 320 pt per hour
    case tenMinutes      // 480 pt per hour  (10 min = 80 pt)

    var pointsPerHour: CGFloat
    /// Interval between labelled grid lines: 60, 30, 15, 10 minutes.
    var labelIntervalMinutes: Int
    /// Interval between faint grid lines: 15, 15, 5, 5 minutes.
    var minorLineMinutes: Int
    func zoomedIn() -> TimelineZoom      // clamps at .tenMinutes
    func zoomedOut() -> TimelineZoom     // clamps at .hour
    var displayName: String              // "1 h", "30 min", "15 min", "10 min"
}
```
`TimelineGeometry` already takes `pointsPerHour`; build it from the zoom. Snapping (`snapMinutes`) stays 5 minutes at all levels (optionally 1 minute at `.tenMinutes` — your call, keep it simple and test it).

### 1.2 State — `Features/Timeline/ViewModels/TimelineZoomState.swift`
- `@Observable @MainActor final class TimelineZoomState` with `private(set) var zoom: TimelineZoom`, `zoomIn()`, `zoomOut()`, `set(_:)`, `canZoomIn`, `canZoomOut`.
- Persists the last level in `UserDefaults` (inject a small store protocol or `UserDefaults` instance so tests use a throw-away suite; wrap reads in a default of `.hour`).
- `TimelineViewModel` owns one `let zoomState: TimelineZoomState` and its `geometry` becomes `TimelineGeometry(day: day, pointsPerHour: zoomState.zoom.pointsPerHour)`. That is the only change needed in `TimelineViewModel` — everything else already reads `viewModel.geometry`.

### 1.3 Controls
- **Toolbar / `DayNavigationBar`**: a compact control with "−" and "+" buttons (`minus.magnifyingglass` / `plus.magnifyingglass`) and the current level name in between (or a small menu to pick a level). Disabled at the ends.
- **Keyboard**: ⌘+ (also ⌘=) zoom in, ⌘− zoom out, ⌘0 back to `.hour`. Put these in the app's `Commands` or as hidden keyboard-shortcut buttons like `RootView.sidebarShortcuts` does; only active while the timeline is shown.
- **Trackpad pinch**: `MagnifyGesture` on the timeline `ScrollView`; step one level per ~25% magnification change during the gesture (accumulate, don't jump several levels at once). Must not break the selection drag or the entry move/resize gestures — use `.simultaneousGesture` and verify by reasoning about gesture priority; mention in the report if it can't be verified.

### 1.4 Keep the view anchored
When the zoom changes, the time at the **center of the visible area** must stay at the center:
- Track the visible rect of the scroll view (`onScrollGeometryChange(for:)` → `contentOffset.y` and `containerSize.height`); compute the center date with the *old* geometry.
- After changing zoom, `scrollPosition.scrollTo(y: newGeometry.y(for: centerDate) - containerHeight / 2)` (clamped ≥ 0).
- Put the math in a pure helper `TimelineZoomAnchor` (`static func offset(keeping date: Date, centeredIn height: CGFloat, geometry: TimelineGeometry) -> CGFloat`) with tests.
- For pinch, anchoring on the center is fine (anchoring on the cursor is a nice-to-have, skip).

### 1.5 Grid
`HourGridView` uses the zoom's `labelIntervalMinutes` and `minorLineMinutes`: labelled lines with a time label at every label interval (e.g. 10:00, 10:10, 10:20 at `.tenMinutes`), slightly stronger lines on full hours, faint minor lines. Hour labels stay the most prominent (e.g. full-hour labels in `.caption` primary-secondary, intermediate labels in `.caption2` tertiary). Extract the "which lines/labels for this geometry + zoom" calculation into a pure `HourGridLayout` with tests, keep the view dumb. The `Canvas` approach can stay; make sure performance is fine at 480pt/h (24h = 11,520pt of content — still fine for Canvas and a `ForEach` of ~145 labels).

### 1.6 Other places that depend on the scale
- `initialScrollDate` / initial scroll keeps working at every zoom level.
- `EntryDragCalculator`, resize handles, minimum selection, `SelectionOverlay` labels: all use `geometry` already — verify and add a test for `EntryDragCalculator` at a non-default `pointsPerHour`.
- `TimeEntryBlock` should also benefit from the adaptive label rules where it makes sense (title/project on one line when small), but do not restructure it beyond that.

---

## 2. Adaptive labels on app-session blocks

### 2.1 Pure rule — `Features/Timeline/Layout/SessionLabelStyle.swift` (tested)
```swift
enum SessionLabelStyle: Equatable {
    case full          // icon + name + duration (two lines)   height ≥ 32
    case singleLine    // icon + name on one line, small font   height ≥ 15
    case iconOnly      // 12–14pt icon                          height ≥ 10
    case colorOnly     // just the colored bar                  height < 10
    static func style(forHeight height: CGFloat, width: CGFloat) -> SessionLabelStyle
}
```
Tune thresholds to the real fonts (`.caption` / `.caption2`) so text is never clipped mid-glyph; also degrade when the lane is very narrow (e.g. < 60pt wide → no name). Unit-test the boundaries.

### 2.2 View
- `AppSessionBlock` switches on the style; split into small subviews if it grows (e.g. `AppSessionBlockLabel.swift`).
- In `.singleLine`: icon (12pt) + name in `.caption2.weight(.medium)`, truncating tail; vertical padding reduced to fit.
- Accessibility label unchanged (always name + duration).

With zoom at `.tenMinutes` (8pt/min) a one-line name fits from ~2 minutes; at `.hour` a single line fits from ~11 minutes and the icon from ~8 minutes.

---

## 3. Hover card

### 3.1 Behaviour
- Hovering an app-session block shows a small card **immediately** (no system tooltip delay): app icon (24pt), app name (headline), time range "10:12 – 10:14", duration, and — when the displayed block was merged from several raw sessions — nothing extra (keep it simple).
- Card disappears when the pointer leaves the block. It never takes focus and never blocks clicks or drags (`allowsHitTesting(false)`).
- Also add the same card for `TimeEntryBlock` (title, project with color dot, time range, duration, note) — cheap once the component exists. Not shown while an entry is being dragged/resized or while a selection drag is in progress.
- Remove the old `.help(...)` tooltips on these blocks (they'd show on top of the card).

### 3.2 Implementation
- State: `TimelineViewModel` must not grow — add `@Observable @MainActor final class TimelineHoverState` (`private(set) var hovered: HoverTarget?` where `HoverTarget` is an enum `.session(AppSessionBlockModel)` / `.entry(TimeEntry)`, plus the block's frame in the "timeline" coordinate space). Own it next to `zoomState` (e.g. on `TimelineViewModel` as a `let`, or as `@State` in `TimelineScreen`).
- Blocks report hover with `.onHover` / `.onContinuousHover`, using their frame from `geometry.frame(for:)` and the lane's x-position (pass in or read via `GeometryReader`/`onGeometryChange` in the "timeline" coordinate space).
- A `TimelineHoverCard` view is drawn once, in an overlay on `TimelineColumn` (above lanes, `allowsHitTesting(false)`), positioned next to the hovered block: to the right of an app block (over the entry lane), to the left of an entry block (over the app lane), vertically aligned with the block's top and clamped so it stays inside the visible area as much as reasonable. Use `.position`/padding, not `.popover` (popovers on offset views were the v1 bug).
- Small fade-in (`.transition(.opacity)`, ~0.1s). No delay timers.
- Files: `ViewModels/TimelineHoverState.swift`, `ViewModels/HoverTarget.swift`, `Views/TimelineHoverCard.swift`, `Views/SessionHoverCardContent.swift`, `Views/EntryHoverCardContent.swift`.

---

## 4. Order of work

Each step builds, passes all tests (`xcodebuild -project TimeTracker.xcodeproj -scheme TimeTracker -destination 'platform=macOS' test`) and is committed separately on `feature/v1-implementation` (don't push; commit PLAN-v1.2.md with the first commit).

1. `TimelineZoom` + `TimelineZoomState` (persistence) + geometry wiring + tests.
2. Zoom controls (buttons, keyboard, pinch) + anchored zooming (`TimelineZoomAnchor`) + tests.
3. `HourGridLayout` + grid per zoom level + tests.
4. `SessionLabelStyle` + adaptive `AppSessionBlock` (+ light touch on `TimeEntryBlock`) + tests.
5. Hover card for sessions and entries; remove `.help` tooltips.
6. Update PLAN.md (timeline section) with zoom, labels and hover card so it stays the source of truth.

## 5. Definition of done
- [ ] Four zoom levels, from 1 h = 80pt to 10 min = 80pt, via buttons, ⌘+/⌘−/⌘0 and pinch; the last level is remembered.
- [ ] Zooming keeps the time in the middle of the view in place.
- [ ] Grid labels match the zoom level (every 10 min at the most detailed level).
- [ ] App blocks show the most information that fits; at the most detailed level a ~2-minute session shows its name.
- [ ] Hovering any app or entry block immediately shows a card with what it is; it never interferes with clicking or dragging.
- [ ] Selection drag, entry move/resize and the entry sheet work at every zoom level.
- [ ] All tests pass; no file above ~250 lines; `TimelineViewModel` not larger than before.
- [ ] Report lists what could only be verified by hand.
