# Timelane v1.11 — Record / Stop timer

Context: Timelane is on `main` (repo folder `/Users/nickk/iosProjects/TimeTracker`, project `Timelane.xcodeproj`, sources `Timelane/`, tests `TimelaneTests/`, scheme `Timelane`), pushed to github.com/NickKoepr/Timelane. Work directly on `main`; the main session reviews and pushes — **do not push**.

All conventions from PLAN.md §11 apply (MVVM, one type per file, small files, pure logic unit-tested, no new dependencies).

User request: a **Record** button to start timing the work on a task, and a **Stop** button to end it. On Stop, the existing time-entry form opens (the sheet in the main window, the popup in the menu bar panel) prefilled with the recorded period, so the user picks project/title/note and saves as usual. Keep it simple. The button must be in the **main window and the menu bar panel**.

---

## 1. Behaviour

- **Idle:** a "Record" button (SF Symbol `record.circle`, red tint) is visible.
- **Record:** starts a timer at *now*. The button becomes **"Stop"** (`stop.circle.fill`, red) with the live elapsed time next to it ("0:12:34", monospaced digits, updated every second).
- **Stop:** ends the timer at *now* and opens the new-entry form with `start…end` (start rounded down, end rounded up to whole minutes, so the entry is ≥ 1 minute and lines up with the minute grid). Title focused, last used project preselected — exactly like registering via drag.
  - **Save** → entry created through `TimeEntryEditor` (overlap rules unchanged).
  - **Cancel** → nothing is registered; the recorded period is discarded (the timer is already stopped).
  - If the period is shorter than 1 minute even after rounding (practically impossible after rounding, but guard it) or the form can't open, show the existing error banner/alert "Recording too short to register."
- **One timer for the whole app:** starting in the main window shows it running in the menu bar panel and vice versa; stopping in one place opens the form *in that place*.
- **Survives restarts:** the start time is persisted, so closing the window, closing the panel or quitting/relaunching the app keeps the timer running.
- **Crossing midnight:** the form edits times on one day. If the recording crosses midnight, prefill the form for the **start day** with end = 23:59 of that day (end of day), and show an inline note in the form "Recording continued past midnight — the rest was not included." Keep this simple; no automatic split.
- **Shown day:** when Stop opens the form, the timeline switches to the recording's start day (usually today) so the selection overlay is visible.
- **Live block on the timeline:** while recording and the shown day contains the start, draw a non-interactive "recording" block in the **Logged hours** lane from start to now: red outline, light red fill (or diagonal stripes), label "Recording · 0:12" (when tall enough). It is `allowsHitTesting(false)` and never blocks dragging. It updates at least every 30 s (the timeline already ticks; the elapsed text in the button ticks every second).
- **Keyboard:** ⌘R toggles Record/Stop in the main window (register it once, like the other shortcuts in `DayNavigationShortcuts`).
- Independent from app tracking (tracked apps keep being recorded as before).

## 2. Model / state

- `Services/Timer/RecordingTimer.swift` — `@Observable @MainActor final class RecordingTimer`:
  - `private(set) var startedAt: Date?`, `var isRunning: Bool`, `func elapsed(at now: Date) -> TimeInterval`
  - `func start()` (no-op if running), `func stop() -> RecordedPeriod?` (clears state, returns the period).
  - Injected clock `() -> Date` and a small persistence protocol (`RecordingTimerStore`, UserDefaults implementation with key `recordingTimer.startedAt`; in-memory one for tests/previews). Restores `startedAt` on init.
- `Services/Timer/RecordedPeriod.swift` — pure value type + logic: from raw start/end → rounded `DateRange` for the form, clamped to the start day with a `continuedPastMidnight: Bool` flag (use `DateRange.day(of:calendar:)`). Unit-tested (rounding, < 1 min, midnight).
- `AppEnvironment` owns one `RecordingTimer` (live store), shared by main window and menu bar.
- `TimelineViewModel`: add one entry point, e.g. `func register(_ period: RecordedPeriod)` → shows the period's day, sets the selection overlay to the range and opens the form (reuse the existing private `openForm(.new(...))` path used by drag/assign). The note for `continuedPastMidnight` goes through the form view model (e.g. an optional `notice: String?` on `TimeEntryFormViewModel` shown above the buttons in `TimeEntryFormContent`). Keep `TimelineViewModel.swift` ≤ ~200 lines (it's at ~198) — move code into an extension file (e.g. `TimelineViewModel+Recording.swift`) if needed.
- The record/stop action logic for the UI lives in a tiny view model or in `RecordingTimer` itself: `toggle(on timeline: TimelineViewModel)` = start, or stop + `timeline.register(period)`.

## 3. UI

- `Features/Timeline/Views/RecordButton.swift` — shared button view (takes the `RecordingTimer` and an `onStop: (RecordedPeriod) -> Void`), shows Record or Stop + elapsed (`TimelineView(.periodic(from:by: 1))` for the elapsed text only). `.fixedSize()`, single line, `.help("Start recording (⌘R)")` / `.help("Stop and register (⌘R)")`, accessibility labels.
- **Main window:** put the button in `DayNavigationBar` in every `ViewThatFits` variant, to the left of the zoom controls (narrow variant: row 1 next to zoom, or row 2 left of the totals — pick what fits ≥ 480 pt detail width; re-check the variant widths). Shortcut ⌘R in `DayNavigationShortcuts` only.
- **Menu bar panel:** put the button in `MenuBarDayBar` (or directly under the live status line if the day bar is too full at 380 pt — your call, it must be clearly visible). Stop opens the form popup in the panel (`MenuBarFormPopup` already shows `timeline.form`).
- **Live recording block:** `Features/Timeline/Views/RecordingBlock.swift`, drawn in `TimelineColumn` in the entry lane using `TimelineLaneLayout` + `geometry.frame(for:end:)`, below the selection overlay and hover card, non-hit-testable. Pass the timer state via the timeline view model or the environment — keep `TimelineColumn` small.
- Optional (only if trivial): menu bar icon shows a red dot / filled variant while recording. Skip if `MenuBarExtra` label updates aren't reliable.

## 4. Tests
- `RecordedPeriod`: rounding (start down / end up), exactly-on-minute, shorter than a minute, crossing midnight (clamped + flag), DST day sanity.
- `RecordingTimer`: start/stop with fake clock, start while running is a no-op, persistence round trip (new instance restores `startedAt`), stop clears the store.
- `TimelineViewModel.register(_:)`: switches day, sets selection, opens a new form with the right range; the notice is set when `continuedPastMidnight`.

## 5. Docs
- README: feature line for Record/Stop (main window + menu bar, ⌘R).
- PLAN.md: short section about the recording timer.

## 6. Order of work
One or two commits on `main` (include this plan) after `xcodebuild -project Timelane.xcodeproj -scheme Timelane -destination 'platform=macOS' -derivedDataPath build/DerivedData test` passes. Then quit the running app (`osascript -e 'quit app "Timelane"'`), build into build/DerivedData and relaunch normally (`open build/DerivedData/Build/Products/Debug/Timelane.app`, never with `-resetDatabase`). Do not push.

## 7. Definition of done
- [ ] Record/Stop button with live elapsed time in the main window bar and the menu bar panel; ⌘R in the main window.
- [ ] Stop opens the existing new-entry form (sheet / panel popup) prefilled with the rounded period; Save registers, Cancel discards.
- [ ] One shared timer, persisted across window/panel close and app restart.
- [ ] Live recording block in the Logged hours lane while recording.
- [ ] Midnight case handled with a notice; all tests pass; files small; docs updated; not pushed.
