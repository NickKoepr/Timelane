# Timelane v1.10 — Make the two timeline lanes self-explanatory

Context: Timelane is on `main` (repo folder `/Users/nickk/iosProjects/TimeTracker`, project `Timelane.xcodeproj`, sources `Timelane/`, tests `TimelaneTests/`, scheme `Timelane`), pushed to github.com/NickKoepr/Timelane. Work directly on `main`; the main session reviews and pushes — **do not push**.

All conventions from PLAN.md §11 apply.

User feedback: on the timeline the left and right side aren't distinguishable. It isn't clear that the **left lane is recorded automatically (tracked apps)** and that on the **right lane you register time yourself**. Wanted: a simple, clear separation that explains what happens where. Keep it simple — no tutorial, no onboarding flow.

---

## 1. Design

```
 ┌───────┬──────────────────────┬┬──────────────────────────────┐
 │       │ ⏺ Tracked apps       ││ ✎ Your time                  │  ← sticky lane header
 │       │ Recorded automatically││ Drag to register             │    (stays visible while scrolling)
 ├───────┼──────────────────────┼┼──────────────────────────────┤
 │ 09:00 │ ▓ Xcode               ││ ███ Website                  │
 │       │ ▒ Slack               ││                              │
 │ 10:00 │ ▓ Xcode               ││   (subtly tinted background) │
```

1. **Sticky lane header** above the scrolling timeline, aligned exactly with the two lanes:
   - Left: SF Symbol `record.circle` (secondary) + **"Tracked apps"**, caption "Recorded automatically".
   - Right: SF Symbol `hand.draw` (or `pencil`) + **"Your time"**, caption "Drag to register" (in the menu bar panel just "Drag to register" is fine too).
   - Caption line in `.caption` secondary; header in `.subheadline.weight(.semibold)`. Single-line texts; drop the caption line when a lane is too narrow (e.g. < 140 pt) — never truncate the title to "…".
   - It does not scroll with the timeline (place it above the `ScrollView`, not inside it).
2. **A clear divider between the lanes**: a 1 pt vertical separator line (`Color(nsColor: .separatorColor)` or `.separator`) running the full height of the timeline, centred in `TimelineMetrics.laneSpacing`, and continuing through the header.
3. **Different lane backgrounds**: keep the app lane neutral; give the time-entry lane a very subtle tint (e.g. `Color.accentColor.opacity(0.04)`, readable in light and dark) so it reads as "your area". Hour grid lines must remain visible on top of / through the tint.
4. **Empty-lane hint**: when the shown day has no time entries yet, show a faint centred hint in the entry lane near the visible area, e.g. "Drag here to register time" with a small `hand.draw` icon (`allowsHitTesting(false)`, secondary, `.callout`). It must not block dragging. Same idea for an empty app lane only if there are no sessions: "Apps you use appear here". Replace the existing "No activity tracked yet" empty-state overlay in `TimelineScrollArea`/`TimelineScreen` with these two lane hints (don't show both systems).

## 2. Implementation notes
- The lane geometry is computed in `TimelineColumn` (label width, `appLaneFraction`, spacing, insets from `TimelineMetrics`). Extract that width calculation into a small pure helper (e.g. `TimelineLaneLayout` in `Features/Timeline/Layout/`: given total width → label width, app lane x/width, entry lane x/width, divider x) with unit tests, and use it in both `TimelineColumn` and the new `TimelineLaneHeader`, so header and lanes can never drift apart.
- The header must match the scroll content width: the `ScrollView` may show a vertical scroll bar (overlay style normally takes no width, but legacy "always show scroll bars" does). Measure the scroll content width (e.g. `onScrollGeometryChange` of `contentSize.width` / `containerSize.width`, or `onGeometryChange` on the column) and feed that to the header, rather than assuming equal widths.
- New views in `Features/Timeline/Views/`: `TimelineLaneHeader.swift`, `LaneDivider.swift` (if it's more than a line), `LaneEmptyHint.swift`. Keep `TimelineColumn`/`TimelineScrollArea` small.
- Applies to the main window **and** the menu bar panel automatically (both use `TimelineScrollArea`); verify it fits the 380 pt panel (lanes ~117 / ~176 pt → captions likely dropped on the left).
- Don't change hit-testing/gestures: the divider, tint and hints are `allowsHitTesting(false)`; dragging over both lanes, clicking sessions/entries, context menus and hover cards keep working.
- Accessibility: header labels are real text (VoiceOver reads "Tracked apps, recorded automatically" / "Your time, drag to register"); give the two lane containers accessibility labels.

## 3. Tests
- `TimelineLaneLayout` for a few widths (e.g. 380, 480, 900): lanes don't overlap, divider is between them, widths sum to the total.
- The rule for showing captions (pure function on lane width) if you make one.

## 4. Order of work
One commit on `main` (include this plan file) after `xcodebuild -project Timelane.xcodeproj -scheme Timelane -destination 'platform=macOS' -derivedDataPath build/DerivedData test` passes. Add a short note to PLAN.md (timeline section) and the README feature line (lanes are labelled). Then quit the running app (`osascript -e 'quit app "Timelane"'`), build into build/DerivedData and relaunch normally (`open build/DerivedData/Build/Products/Debug/Timelane.app`, never with `-resetDatabase`). Do not push.

## 5. Definition of done
- [ ] Each lane has a sticky header explaining it ("Tracked apps — Recorded automatically" / "Your time — Drag to register").
- [ ] A visible divider separates the lanes; the entry lane has a subtle tint.
- [ ] Empty lanes show a short hint; the old generic empty state is gone.
- [ ] Works in the main window (all widths down to the minimum) and in the menu bar panel; gestures unaffected.
- [ ] Tests pass; files small; docs updated; not pushed.
