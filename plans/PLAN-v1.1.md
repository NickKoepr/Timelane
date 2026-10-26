# TimeTracker v1.1 — Fixes and features after first user test

Context: v1 (PLAN.md) is implemented on branch `feature/v1-implementation`. The user tested it and reported four problems. This plan fixes them. All conventions from PLAN.md §11 still apply (MVVM, one type per file, files < 150 lines / hard limit ~250, ViewModels don't import GRDB or SwiftUI view types, pure logic unit-tested, no new dependencies, every schema change is a NEW migration).

User reports (paraphrased):
1. "I can't register which applications I want to track; I don't want to track all apps."
2. "I can only select time on the timeline after the red line (now), not before it. I want to register time in the past too."
3. "When I select a time window I get no popup to link a project. I want a popup window where I can pick the project, adjust the time block, and give the block a title."
4. "Make sure created time blocks are saved in the timeline — I think that doesn't work yet."

---

## 0. Findings from reading the v1 code (verify, don't trust blindly)

- **Popovers are anchored to offset views.** `SelectionOverlay` and `TimeEntryBlock` are positioned with `.offset(y:)` inside a `ZStack`, and the `.popover` is attached to them. `.offset` only moves the rendering, not the layout frame, so the popover anchors at the layout position (the top of the 24h column, usually scrolled out of view) or doesn't present at all. `SelectionOverlay` additionally has `.allowsHitTesting(false)` and only exists while `selection != nil`. This is the most likely cause of report 3, and report 4 is most likely a consequence of it (no popup → `TimeEntryEditor.create` is never called).
- **Drag only exists on the entry lane.** The selection `DragGesture` sits on the `Color.clear` background of `TimeEntryLane` (right ~60%). The left app lane (40%) has no drag gesture and is filled with tappable `AppSessionBlock`s in the past, and empty after "now". The root cause of report 2 is not proven yet — find it (see §2) before fixing. Candidates: the drag being started on the app lane, hit-testing of overlays (`NowIndicatorView`, the empty-state overlay in `TimelineScreen`, `HourGridView`), or the ScrollView/focus handling eating the drag.
- **`AppDatabase.stream` swallows errors silently.** If an observation fails, the timeline just stops updating and nobody knows. This could hide report 4.
- The SQLite file lives in the sandbox container (`~/Library/Containers/<bundle id>/Data/Library/Application Support/TimeTracker/db.sqlite`), which the shell cannot read (macOS container protection). Verification must therefore go through tests and logging, not by inspecting the file.

---

## 1. Schema migration `v2`

Add to `Migrations.swift` (new migration, do not touch `v1`):

```swift
migrator.registerMigration("v2") { db in
    try db.alter(table: "timeEntry") { t in t.add(column: "title", .text) }
    try db.create(table: "trackedApp") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("bundleIdentifier", .text).notNull().unique()
        t.column("name", .text).notNull()
        t.column("addedAt", .double).notNull()
    }
}
```

- `TimeEntry` gets `var title: String?` (in init with default `nil`). Empty/whitespace titles are stored as `nil` (same as `note`).
- New model `Models/TrackedApp.swift`: `id: Int64?`, `bundleIdentifier`, `name`, `addedAt`. GRDB conformance in `Database/Records/TrackedApp+Record.swift` (same date strategy as the others).
- Migration test: a database migrated to v1 with data, then to v2, keeps its entries and has `title == nil`.

---

## 2. Fix: selecting time anywhere on the day (report 2)

1. **Find the root cause first.** Add temporary `Logger` (os) output in `TimelineViewModel.updateSelection` / `finishSelection` and in the gesture's `onChanged`, run the app (`open` the built .app), and reason about which views receive hits. Remove temporary logging afterwards. If you cannot interact with the UI yourself, still apply the structural fix below — it removes all candidate causes — and describe in the report what you found.
2. **Structural fix:** move the selection drag from `TimeEntryLane` to the whole lanes area in `TimelineColumn`, so dragging works over **both** lanes and over empty and filled areas alike, before and after "now":
   - One full-size gesture layer (`Color.clear.contentShape(Rectangle())`) behind the lanes, plus the same `DragGesture(minimumDistance: 4)` attached with `.simultaneousGesture` to `AppSessionBlock`s, so that a *click* on an app block still assigns the whole session but a *drag* starting on it selects a range. Simplest acceptable alternative: put the drag on a container that wraps both lanes with `.gesture` and keep `onTapGesture` on the blocks (taps and drags are distinguished by `minimumDistance`).
   - `TimeEntryBlock` keeps its own move/resize gestures; those must win on top of an existing entry.
   - Every pure overlay (`NowIndicatorView`, `SelectionOverlay`, the empty-state text, `HourGridView`) must have `.allowsHitTesting(false)` on its outermost view.
3. Selection may cover any part of the shown day (past, present or future). No clamping to "now" anywhere — check `TimelineGeometry`, `TimelineSelection`, `TimelineViewModel`, `TimeEntryEditor` and the overlap resolver for any such limit.
4. Test: `TimelineViewModel.updateSelection` + `finishSelection` with a y-position before the clock's "now" produces a valid selection and opens the form (see §3).

---

## 3. Fix + feature: time entry form window (reports 3 and 4)

Replace both popovers (`ProjectPickerPopover` for new entries, `TimeEntryDetailPopover` for existing ones) with **one modal sheet** that is independent of view positions: `TimeEntryFormSheet`, presented with `.sheet(item:)` from `TimelineScreen`.

### 3.1 Behaviour
- **Opens when:** a drag selection ends (≥ 5 min) → "New time entry" with the selected range; a click on an app-session block → "New time entry" with the session's range; a click (or double-click) on an existing entry → "Edit time entry".
- **Fields:**
  - **Title** (text field, optional, focused first). Placeholder: "What did you work on?".
  - **Project** (required): searchable list of non-archived projects with color dots; last used project preselected for new entries; "New project “…”" row to create one inline (reuse the logic from `ProjectPickerViewModel`; move/rename it rather than duplicating).
  - **From / To**: `DatePicker(displayedComponents: .hourAndMinute)` for start and end on the shown day, plus the computed duration. Validation: end > start, duration ≥ 1 min; show an inline error and disable Save otherwise.
  - **Note** (optional, multi-line `TextField(axis: .vertical)`).
- **Buttons:** Cancel (Esc), Save (⌘↩ / Enter when valid). In edit mode also **Delete** (destructive, left aligned).
- Saving goes through `TimeEntryEditor` (create/update), so overlap resolution stays the same. On success the sheet closes and the selection overlay is cleared; on failure the error is shown inside the sheet and the sheet stays open.
- Cancel clears the selection overlay.
- The selection overlay stays visible behind the sheet while it is open, so the user sees which range they're registering.

### 3.2 Structure (suggested files)
```
Features/Timeline/
  ViewModels/
    TimeEntryForm.swift               // value type: mode (.create/.edit(id)), title, projectId, start, end, note; validation
    TimeEntryFormViewModel.swift      // @Observable: holds the form, project search, save/delete via TimeEntryEditor
    ProjectSearch.swift               // pure: filtering, highlight movement, inline-create name (extracted from ProjectPickerViewModel)
  Views/
    TimeEntryFormSheet.swift          // layout + buttons
    TimeEntryFormTimeFields.swift     // From / To / duration
    ProjectSearchList.swift           // search field + list + "New project" row
```
- `TimelineViewModel` exposes `var form: TimeEntryFormViewModel?` (Identifiable) and creates it in `finishSelection`, `assign(_:)` and `select(_:)`/open-entry. Remove `picker`, the detail state in `EntryEditingViewModel` that is no longer used, `ProjectPickerPopover`, `TimeEntryDetailPopover`, `TimeEntryDetailViewModel` and `ProjectPickerViewModel` (after moving their logic). Delete-key handling for a selected entry keeps working.
- `TimeEntryEditor.create` gets a `title` parameter; `update` already takes the whole entry.
- `TimeEntryBlock` shows `title` when present (bold), otherwise the project name; the project name moves to the second line when a title exists. Tooltip includes title, project, time range and note.

### 3.3 Persistence (report 4)
- Make sure saving actually reaches SQLite and the timeline updates:
  - `AppDatabase.stream` must log errors with `os.Logger` (subsystem = bundle id, category "database") instead of swallowing them.
  - Add a persistence test: create a file-based `AppDatabase` in a temporary directory, save an entry through `TimeEntryEditor`, close it, reopen a new `AppDatabase` on the same file, and assert the entry (including `title`) is there.
  - Add a ViewModel-level test: `TimelineViewModel` (in-memory DB, running `task()` in a child `Task`) → `finishSelection` → set project + title on the form → `save()` → `viewModel.entries` contains the new entry (await the observation with a short polling helper/timeout).
- When the app is run during development, check (via temporary logging if needed) that a created entry survives an app restart.

---

## 4. Feature: choose which apps are tracked (report 1)

### 4.1 Behaviour
- Only apps on the **tracked apps list** create app sessions. When the frontmost app is not on the list, the current session is closed and nothing is recorded until a tracked app becomes frontmost again (same as a pause).
- The list starts **empty** → nothing is tracked until the user adds apps. The timeline then shows a hint: "No apps are tracked yet. Add apps in Tracked Apps." with a button that switches to the Tracked Apps screen.
- Changes to the list apply immediately: adding the current frontmost app starts a session right away; removing it closes the open session.
- **Changed in v1.3: all stored sessions are always shown; this filter was removed (see PLAN-v1.3.md).** The timeline only shows sessions of currently tracked apps (filter in `TimelineViewModel` before `AppSessionMerger`). Stored sessions of other apps are kept in the database but hidden; re-adding an app shows its history again. The tracked total follows the same filter. Do the same in `MenuBarViewModel`.
- Menu bar: when the frontmost app is untracked show "Not tracking: <App name>" instead of the current app.

### 4.2 Tracked Apps screen
- New sidebar item `SidebarItem.trackedApps` ("Tracked Apps", SF Symbol `app.badge.checkmark`, ⌘3).
- List of tracked apps: icon (`AppIconProvider`), name, bundle id (secondary), remove button / context menu "Remove" / Delete key.
- **"Add App"** toolbar button opens a sheet `AddTrackedAppSheet` listing candidate apps with icon + name and a search field, multi-select with checkboxes, "Add" button. Candidates = union (deduplicated by bundle id, minus already tracked, minus TimeTracker itself) of:
  1. currently running apps with `activationPolicy == .regular` (`NSWorkspace.shared.runningApplications`),
  2. apps seen before in `appSession` (distinct bundle id + latest name) — this lets the user pick from the apps v1 already recorded.
  Below the list a button "Choose from Applications…" opens an `NSOpenPanel` (`allowedContentTypes = [.application]`, `directoryURL = /Applications`, multiple selection); read `Bundle(url:)?.bundleIdentifier` and the display name (`FileManager.default.displayName(atPath:)`). The open panel works in the sandbox without extra entitlements.
- Empty state: "No apps tracked. Add the apps you work in, e.g. Xcode, Terminal, your browser."

### 4.3 Structure (suggested files)
```
Models/TrackedApp.swift
Database/Records/TrackedApp+Record.swift
Repositories/TrackedAppRepository.swift              // protocol
Repositories/GRDB/GRDBTrackedAppRepository.swift
  - observeTrackedApps() -> AsyncStream<[TrackedApp]>
  - add(_ apps: [TrackedApp]) async throws            // ignores duplicates
  - remove(id: Int64) async throws
Repositories/AppSessionRepository.swift              // + knownApps() async throws -> [ForegroundApp] (distinct bundle id, latest name)
Services/Tracking/ActivityEvent.swift                // + case trackedAppsChanged(Set<String>)
Services/Tracking/AppActivityTracker.swift           // keeps `trackedBundleIds`; switchSession only opens a session for tracked apps
Services/AppCandidates.swift                          // pure: merge running + known, dedupe, exclude tracked/self, sort by name
Features/TrackedApps/
  ViewModels/TrackedAppsViewModel.swift
  ViewModels/AddTrackedAppViewModel.swift
  Views/TrackedAppsScreen.swift
  Views/TrackedAppRow.swift
  Views/AddTrackedAppSheet.swift
  Views/ApplicationOpenPanel.swift                    // small wrapper around NSOpenPanel returning [TrackedApp]
```
- The tracker gets a `TrackedAppRepository` in its init (wired in `AppEnvironment`), observes it in `start()`, and feeds changes into its existing event stream as `.trackedAppsChanged(...)` so all state changes stay serial and testable. Expose `isCurrentAppTracked` for the menu bar. Keep `AppActivityTracker` under the size limit — extract helpers if needed.
- Tests:
  - tracker with a fake clock: untracked app activation → no session; tracked → session; `.trackedAppsChanged` adding the frontmost app → session starts; removing it → session closed; pause/resume still only opens sessions for tracked apps.
  - `AppCandidates` merge/dedupe/exclude/sort.
  - `GRDBTrackedAppRepository` add (with duplicates) / remove / observe.
  - `AppSessionRepository.knownApps()`.
  - `TimelineViewModel` hides sessions of untracked apps.

---

## 5. Order of work

Each step must build and pass all tests (`xcodebuild -project TimeTracker.xcodeproj -scheme TimeTracker -destination 'platform=macOS' test`) and is committed separately on `feature/v1-implementation`. Don't push.

1. Migration v2 + `TimeEntry.title` + `TrackedApp` model/record + migration test.
2. Persistence hardening and tests (§3.3, logging in `AppDatabase.stream`).
3. Time entry form sheet replacing both popovers (§3.1–3.2), including title on blocks.
4. Selection anywhere on the day (§2).
5. Tracked apps: repository, tracker integration, filtering in timeline/menu bar (§4.1, §4.3 without UI).
6. Tracked Apps screen + add sheet + open panel + timeline hint (§4.2).
7. Update PLAN.md where v1.1 changed decisions (popovers → sheet, tracked-apps list) so the plan stays the source of truth.

## 6. Definition of done

- [ ] Dragging anywhere on the shown day (before or after now, over either lane) shows the selection, and releasing opens the time entry window.
- [ ] Clicking an app-session block opens the window prefilled with that session's range; clicking an entry opens it in edit mode.
- [ ] The window lets the user set title, project (incl. inline new project), start/end and note, and save, cancel or delete.
- [ ] Saved entries appear immediately on the timeline, survive an app restart, and show their title.
- [ ] Only apps on the tracked list are recorded and shown; the list is managed in the Tracked Apps screen with candidates from running apps, previously seen apps and an open panel.
- [ ] All tests pass; no file above ~250 lines; temporary debug logging removed.
- [ ] Report lists anything that could only be verified by hand.
