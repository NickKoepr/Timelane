# PLAN v1.16 — Trackpad pinch zoom in the menu bar panel

## Context

The timeline can be zoomed with the zoom controls, ⌘+/⌘−/⌘0 and a trackpad pinch (PLAN-v1.2, PLAN.md §Zoom).
In the **main window** pinch works. In the **menu bar panel** (`MenuBarExtra`, `.menuBarExtraStyle(.window)`)
pinching does nothing; the zoom buttons in `MenuBarDayBar` do work.

Both windows use the same code: `TimelineScrollArea` → `.timelineZoom(...)` (`TimelineZoomBehavior`), which attaches
`.simultaneousGesture(MagnifyGesture())` to the `ScrollView` and turns the magnification into steps with
`PinchZoomStepper`. So the zoom logic is fine; the gesture never fires in the panel.

## Cause

The panel is a non-activating `NSPanel`: Timelane stays the *inactive* app while it is open (see the AGENTS.md
traps: a sheet from the panel makes the inactive app bounce in the Dock). Keyboard input still reaches the panel
because it can become key without activating the app, but SwiftUI's `MagnifyGesture` does not recognise the
trackpad magnify events in that window. Scroll events, clicks and drags do work, so the window does receive
pointer input.

We cannot drive the UI from the agent, so the fix must not depend on SwiftUI's gesture recogniser in that window,
and it must log enough for the owner to confirm by hand where the events end up.

## Design

Replace the SwiftUI `MagnifyGesture` with an AppKit-level magnify handler, used by **both** windows (one code path,
so the main window cannot zoom twice per pinch).

1. **`PinchZoomStepper`** (pure, `Layout/`): add an AppKit-friendly entry point. `NSEvent.magnification` is a
   *delta* per event (e.g. `0.02`), not the total scale. Add
   `mutating func step(forDelta delta: CGFloat) -> Int` that keeps a running total (`total *= 1 + delta`, start 1)
   and returns `step(for: total)`. `reset()` also resets the total. Keep the existing `step(for:)` API and
   behaviour (existing tests must still pass).

2. **`MagnifyEventMonitor`** (new, `Features/Timeline/Views/MagnifyEventMonitor.swift`): an `NSViewRepresentable`
   placed as a `.background` of the timeline scroll view. Its `NSView`:
   - In `viewDidMoveToWindow`, (re)installs `NSEvent.addLocalMonitorForEvents(matching: .magnify)`; removes the
     monitor when the window becomes nil and in `deinit` / `dismantleNSView`.
   - For each event: only handle it when `event.window === self.window` and the pointer
     (`convert(event.locationInWindow, from: nil)`) is inside `bounds`. Then call
     `onMagnify(event.magnification, event.phase)`. Always **return the event** (never swallow it).
   - Logs at `.debug` with `Logger(subsystem: Bundle.main.bundleIdentifier ?? "Timelane", category: "zoom")`
     when the monitor is installed (with the window class name) and on each `.began` phase, so the owner can check
     with `log show` whether magnify events reach the panel.
   - `updateNSView` refreshes the closure (like `PanelOpenObserver`).

3. **`TimelineZoomBehavior`**: remove the `.simultaneousGesture(MagnifyGesture()...)`. Add
   `.background { MagnifyEventMonitor { delta, phase in ... } }`:
   - `phase.contains(.began)` → `stepper.reset()` before using the delta.
   - `let step = stepper.step(forDelta: delta)`; `> 0` → `apply { $0.zoomIn() }`, `< 0` → `apply { $0.zoomOut() }`.
   - `phase.contains(.ended) || phase.contains(.cancelled)` → `stepper.reset()`.
   The anchored scrolling (`onScrollGeometryChange` / `onChange(of: pointsPerHour)`) stays exactly as it is.
   Update the type's doc comment (it no longer talks about a simultaneous gesture; the selection drag and entry
   drags are unaffected because the monitor never consumes events).

4. **If magnify events never reach the app while it is inactive** (the owner will see no `zoom` log lines when
   pinching in the panel): do NOT activate the app automatically (it would bring the main window forward and
   bounce the Dock). Report this in the PR description as an open point instead; the owner decides.

## Files

- `Timelane/Features/Timeline/Layout/PinchZoomStepper.swift` — `step(forDelta:)`, reset of the total.
- `Timelane/Features/Timeline/Views/MagnifyEventMonitor.swift` — new.
- `Timelane/Features/Timeline/Views/TimelineZoomBehavior.swift` — use the monitor instead of `MagnifyGesture`.
- `TimelaneTests/PinchZoomStepperTests.swift` — new (or extend `TimelineZoomAnchorTests` where the stepper test
  lives now; a separate file is preferred).
- `plans/PLAN.md` (§Zoom line mentioning `MagnifyGesture`) and `README.md` only if the wording becomes wrong.

## Tests

- `step(forDelta:)`: a series of small positive deltas yields exactly one `+1` once the product passes 1.25, then
  `0`s, then another `+1` after a further 25 %; negative deltas yield `-1` symmetrically; one big jump never returns
  more than one step per call; `reset()` starts from 1 again; deltas ≤ −1 (total ≤ 0) return 0 and don't crash.
- Existing `step(for:)` tests unchanged and green.
- No UI test is possible; `MagnifyEventMonitor` stays thin (no logic beyond filtering and forwarding).

## Order of work

1. Stepper + tests. 2. `MagnifyEventMonitor`. 3. Wire into `TimelineZoomBehavior`, remove `MagnifyGesture`.
4. Run the full test suite (command in AGENTS.md, `-derivedDataPath build/DerivedData` inside this worktree).
5. Update `PLAN.md` / README wording. 6. Commit on branch `fix/menu-bar-pinch-zoom`.

## Definition of done

- All unit tests pass; the app builds without warnings introduced by this change.
- Pinch zooms one level per ~25 % in the main window (unchanged feel) and in the menu bar panel, anchored on the
  centre of the visible area; selection drag, entry move/resize and scrolling still work in both.
- Manual check for the owner (written in the PR): open the panel, pinch over the timeline, verify the level
  changes; run `/usr/bin/log show --last 5m --info --debug --predicate 'subsystem == "nl.nickkoepr.timelane" && category == "zoom"'`
  if it does not.
