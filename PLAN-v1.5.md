# TimeTracker v1.5 — Register hours from the menu bar

Context: v1–v1.4 are implemented and merged on `main` (see PLAN.md and PLAN-v1.x.md). The app has a `MenuBarExtra` (`.menuBarExtraStyle(.window)`, `MenuBar/MenuBarContentView.swift` + `MenuBarViewModel.swift`) that shows the live tracking status (red dot + current app / "Paused" / "Not tracking: X"), today's registered and tracked totals, "Open TimeTracker" and "Quit".

User request: register hours from the menu bar. The menu bar panel gets **the same timeline logic as the main window**: see which apps were tracked automatically and register time on a project by dragging, clicking an app session, or editing existing entries. **Keep the live tracking status** at the top — the user likes it. Managing projects and tracked apps stays in the main app only.

All conventions from PLAN.md §11 apply (MVVM, one type per file, files < 150 lines / hard limit ~250, pure logic unit-tested, no new dependencies). Reuse the existing timeline code; do not fork/copy it.

---

## 1. What the panel looks like

```
┌──────────────────────────────────────────┐
│ ● Xcode                         (live)  │  status line — unchanged behaviour
├──────────────────────────────────────────┤
│ ‹  Today  ›   Mon 26 Oct      − 30m +    │  compact day + zoom bar
│ Registered 3:15        Tracked 5:40      │  totals
├──────────────────────────────────────────┤
│ 09:00 │ ▓ Xcode      │ ███ Website      │
│       │ ▒ Slack      │                  │  the real timeline (TimelineColumn),
│ 10:00 │ ▓ Xcode      │                  │  scrollable, drag / click / hover /
│  ...  │              │                  │  move / resize all work
├──────────────────────────────────────────┤
│ Open TimeTracker                  Quit   │  footer
└──────────────────────────────────────────┘
```
- Panel size: about **380 × 600 pt** (fixed width, fixed height; the timeline scrolls inside).
- On open it shows **today**, scrolled to "now − 1 h" (same as the main window).
- When the time entry form is open it replaces the timeline area inside the panel (see §3); the status line stays visible.

## 2. Reuse the timeline

### 2.1 Extract a shared scroll area
`TimelineScreen` currently owns the `ScrollView` + `TimelineColumn` + empty state + scroll position + zoom behaviour (`.timelineZoom`) + delete-key handling + initial scroll. Extract that into one reusable view, e.g. `Features/Timeline/Views/TimelineScrollArea.swift`, that takes a `TimelineViewModel` (and the hover state / anchor it needs). `TimelineScreen` then becomes: `DayNavigationBar` + banner + `TimelineScrollArea` + sheet. The main window must look and behave exactly as before.

### 2.2 Narrow width
`TimelineColumn` must work at ~360 pt wide:
- Check `TimelineMetrics` (label width 54, app lane 40%). At 360 pt the lanes are ~120 / ~180 pt — acceptable; make the label width/lane fraction a parameter only if needed (e.g. a `TimelineMetrics.compact` variant), not a copy of the views.
- `SessionLabelStyle` already degrades by width; verify names still show at ~120 pt.
- The hover card (`TimelineHoverCard`, 220 pt wide, `HoverCardPlacement`) must stay inside the panel: verify the placement clamps horizontally for a narrow column; adjust `HoverCardPlacement` (pure, tested) if it doesn't.

### 2.3 Its own view model instance and zoom
- The menu bar creates its own `TimelineViewModel` (both instances observe the same database, so changes in one show up in the other immediately).
- Zoom: give the menu bar its own `TimelineZoomState` with a **separate UserDefaults key** (add an init parameter for the key, default stays `"timelineZoomLevel"`; menu bar uses e.g. `"menuBarTimelineZoomLevel"`, default level `.halfHour`). Zoom buttons in the compact bar; pinch works via the shared scroll area.

## 3. Registering in the panel

### 3.1 Inline form instead of a sheet
Sheets/popovers attached to a `MenuBarExtra` window are unreliable (wrong window, panel closing). Present the form **inline**:
- Extract the body of `TimeEntryFormSheet` into `TimeEntryFormContent` (fields + buttons, no fixed width/padding decisions that only fit a sheet). `TimeEntryFormSheet` wraps it for the main window (unchanged look); the menu bar shows `TimeEntryFormContent` in place of the timeline area while `viewModel.form != nil`, with a header "‹ Back" (= Cancel).
- Save / Cancel / Delete behave exactly as in the main window (they go through `TimeEntryFormViewModel` → `TimeEntryEditor`). After save/cancel the timeline is shown again at the same scroll position (keep the scroll area alive, e.g. hide it with `opacity`/`overlay` rather than removing it, or restore the position).
- Keyboard: Esc = Cancel, Return/⌘↩ = Save, as in the sheet. Text fields must accept typing in the panel (MenuBarExtra window panels become key when clicked; verify the title field gets focus).

### 3.2 No project management in the menu bar
- `TimeEntryFormViewModel` / `ProjectSearchList` get an option `allowsCreatingProjects` (default `true`; menu bar passes `false`) that hides the inline "New project “…”" row and makes Return with no match do nothing.
- No projects at all → the form shows "No projects yet" with a button **"Open TimeTracker to add projects"** (opens the main window on the Projects screen if easy, otherwise just the main window).
- No "Add apps" in the menu bar: when the tracked-apps list is empty, show the existing `NoTrackedAppsBanner`, but its action opens the main window (Tracked Apps screen if easy).

### 3.3 What keeps working exactly like the main window
Drag over either lane to select a range (before or after now), click an app session to assign the whole session, click an entry to edit, move/resize entries, Delete key on a selected entry, hover cards, overlap resolution, minimum durations.

## 4. Menu bar view structure (suggested files)

```
MenuBar/
  MenuBarContentView.swift        // composition: status, compact bar, totals, timeline-or-form, footer
  MenuBarStatusLine.swift         // the existing live status line, extracted unchanged
  MenuBarDayBar.swift             // ‹ Today ›, short date, zoom − / level / +
  MenuBarFooter.swift             // Open TimeTracker, Quit
  MenuBarViewModel.swift          // owns the menu bar TimelineViewModel + zoom state; "show today" on open
```
- `MenuBarViewModel` keeps only what the menu bar adds on top of `TimelineViewModel` (creating it with the right zoom state, resetting to today when the panel opens). Totals come from `TimelineViewModel.registeredTotal/trackedTotal`; remove the now-duplicate observation code from `MenuBarViewModel`.
- Opening the panel: SwiftUI's `onAppear`/`task` on `MenuBarExtra` window content may only run the first time. Make sure that every time the panel opens it jumps to today and scrolls to now (e.g. observe `NSWindow.didBecomeKeyNotification` for the panel's window, or `scenePhase`, whichever works; put the AppKit bit in a tiny view helper). Verify and describe what you used.
- Opening the main window from the panel: keep using `openWindow(id: "main")` + `NSApp.activate()`. For "open on a specific screen" either pass a value through a small shared `@Observable` navigation state on `AppEnvironment` (e.g. `requestedSidebarItem`) that `RootView` reads, or skip it if it complicates things — opening the main window is enough.
- `TimeTrackerApp`: keep `MenuBarExtra("TimeTracker", systemImage: "clock")` with `.window` style; set the content frame to the panel size.

## 5. Tests
- `TimelineZoomState` with a custom key does not share its level with the default key.
- `TimeEntryFormViewModel` / `ProjectSearch` with `allowsCreatingProjects == false`: no new-project name offered, confirm with no match does nothing.
- `HoverCardPlacement` stays inside a narrow column (e.g. column width 360, card 220) for blocks on both lanes.
- `MenuBarViewModel`: opening resets the day to today (with an injected clock) and its timeline view model uses the menu-bar zoom state.
- Existing tests keep passing; update them where code moved.

## 6. Order of work
Commit each step on a new branch `feature/menu-bar-timeline` created from `main` (don't push), after `xcodebuild -project TimeTracker.xcodeproj -scheme TimeTracker -destination 'platform=macOS' -derivedDataPath build/DerivedData test` passes. Commit this plan file with the first commit.
1. Extract `TimelineScrollArea` and `TimeEntryFormContent`; main window unchanged.
2. Zoom state key parameter, `allowsCreatingProjects`, narrow-width fixes (metrics / hover placement) + tests.
3. Menu bar panel: status line (unchanged), day bar, totals, timeline, inline form, footer, "today on open".
4. Update PLAN.md (menu bar section) so it stays the source of truth.
Finally quit the running app, build into build/DerivedData and relaunch it normally (`open build/DerivedData/Build/Products/Debug/TimeTracker.app`, never with `-resetDatabase`).

## 7. Definition of done
- [ ] The menu bar panel shows the live tracking status exactly as before.
- [ ] Below it: today's timeline with tracked app sessions and registered entries, scrollable and zoomable.
- [ ] Registering works in the panel: drag a range or click an app session → inline form → pick project, title, times, note → Save; editing/deleting entries works too.
- [ ] No project or tracked-app management in the panel; links open the main app instead.
- [ ] Every time the panel opens it shows today around "now".
- [ ] The main window behaves exactly as before; changes made in one place show up in the other immediately.
- [ ] All tests pass; no file above ~250 lines.
