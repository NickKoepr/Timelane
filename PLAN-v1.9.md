# Timelane v1.9 — Fix layout when the window is made small

Context: the app (formerly TimeTracker, now Timelane — folders `Timelane/`, `TimelaneTests/`, project `Timelane.xcodeproj`, scheme `Timelane`) is on `main` and pushed to `origin` (github.com/NickKoepr/Timelane). Work directly on `main`. The main session reviews, commits if needed and pushes — **do not push**.

All conventions from PLAN.md §11 apply.

User report (with a screenshot of the main window at ~540 × 780 pt, sidebar visible):
1. **Timeline:** the top bar (`DayNavigationBar`) breaks down. The "Today" button becomes an empty pill, the day title and the Registered/Tracked totals disappear, and the bar takes a huge vertical height (the controls float in the middle of a ~600 pt tall area; the timeline starts far below).
2. **Projects:** the "This month" button disappears from `MonthNavigationBar`.
3. **Tracked Apps:** the window can be made very small, and the text is then laid out strangely.
User's wish: fix the bars so they adapt as far as possible; where it really can't fit any more, set a **minimum window size** so the user can't make the window smaller than what works.

---

## 1. Responsive top bar on the Timeline

Cause (from reading `Features/Timeline/Views/DayNavigationBar.swift` — verify): one `HStack` with chevrons, "Today", the title `Text`, a compact `DatePicker`, `Spacer`, zoom controls and `DayTotalsView`. Nothing has `lineLimit`/`fixedSize`/layout priority, so when it's narrow SwiftUI truncates buttons to nothing and the title text wraps into a very tall column, which makes the whole bar tall.

Fix:
- Every text in the bar is single-line: `.lineLimit(1)`; buttons and the totals get `.fixedSize()` so they never truncate to an empty pill.
- Use **`ViewThatFits(in: .horizontal)`** with progressively more compact variants (each variant in a small subview / file to keep `DayNavigationBar` short):
  1. **Wide:** as now — ‹ Today › · full title ("Monday 26 October 2026") · date picker · spacer · zoom · totals (2 rows).
  2. **Medium:** ‹ Today › · short title ("Mon 26 Oct") · date picker · spacer · zoom · totals on one line compact ("3:15 / 5:40" with a tooltip "Registered / Tracked").
  3. **Narrow:** two rows — row 1: ‹ Today › · short title · spacer · zoom; row 2: date picker · spacer · compact totals.
- The bar must never be taller than its content (fixed vertical size); the timeline starts directly below it.
- Keep all keyboard shortcuts working in every variant. **Important:** `.keyboardShortcut` on buttons inside multiple `ViewThatFits` variants can register twice or not at all — put the shortcuts on one always-present place (e.g. hidden buttons like `RootView.sidebarShortcuts` / `TimelineZoomControls.hiddenShortcuts`) instead of on the visible buttons of each variant. Verify ⌘← ⌘→ ⌘T ⌘+ ⌘− ⌘0 still work (by reasoning; there are no UI tests).
- Title formats belong in `TimelineViewModel` (or a tiny pure formatter, tested), not in the view: `title` (full) and `shortTitle`.

## 2. Projects month bar
- `MonthNavigationBar`: same approach — single-line texts, `fixedSize` on buttons, and a compact variant via `ViewThatFits` (e.g. month title shortened "Oct 2026", "This month" becomes an icon button `calendar` with tooltip when there is no room). "This month" must never just disappear.

## 3. Tracked Apps and lists
- `TrackedAppRow`: name and bundle id `lineLimit(1)` with `.truncationMode(.middle)` for the bundle id; icon and remove button `fixedSize`. Same check for `ProjectRow` (name truncates, total never truncates) and the Tracked Apps footer caption (wraps nicely, max 3 lines).
- Empty states (`ContentUnavailableView`s) are fine as long as the window has a sensible minimum size (§4).

## 4. Minimum window size
- Determine the smallest size at which every screen still looks right **with the sidebar visible** (the narrow variants above included). Expected roughly: detail area min ~480 pt wide, window min ~700 × 520 pt — measure/estimate from the actual controls rather than guessing, and document the numbers in a constant (e.g. `WindowMetrics.minimumSize` in `App/`).
- Enforce it: `.frame(minWidth:minHeight:)` on the window content (`RootView`) plus `.windowResizability(.contentMinSize)` on the `Window` scene in `TimelaneApp.swift`; give the detail column a minimum via `.navigationSplitViewColumnWidth(min:ideal:)` on the detail views if needed so the sidebar can't squeeze it.
- Keep `.defaultSize(width: 900, height: 750)`.
- The menu bar panel has a fixed size already (380 × 600) — don't change it, but check `MenuBarDayBar` has single-line, non-truncating texts too.

## 5. Tests and checks
- Unit test for the short/full title formatting (fixed locale/calendar in the test).
- `#Preview`s of `DayNavigationBar` and `MonthNavigationBar` at several widths (e.g. 900, 600, 480) so the variants can be checked in Xcode's canvas.
- You can't take screenshots: reason about each variant's minimum width from its contents, and state in the report which widths you designed for.

## 6. Order of work
One or two commits on `main` (include this plan file), after `xcodebuild -project Timelane.xcodeproj -scheme Timelane -destination 'platform=macOS' -derivedDataPath build/DerivedData test` passes. Update PLAN.md briefly (responsive bars, minimum window size). Then quit the running app (`osascript -e 'quit app "Timelane"'`), build into build/DerivedData and relaunch normally (`open build/DerivedData/Build/Products/Debug/Timelane.app`, never with `-resetDatabase`). Do not push.

## 7. Definition of done
- [ ] At any allowed window size, the Timeline bar shows all controls (maybe in compact form), never empty buttons, never a tall bar.
- [ ] "This month" is always reachable on the Projects screen.
- [ ] Tracked Apps / Projects rows truncate cleanly.
- [ ] The window cannot be made smaller than the documented minimum.
- [ ] Keyboard shortcuts still work; all tests pass; files stay small.
