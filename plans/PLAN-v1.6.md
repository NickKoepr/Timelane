# TimeTracker v1.6 — Context menu on entries, readable menu bar form

Context: v1–v1.5 are implemented and merged on `main` (see PLAN.md and PLAN-v1.x.md). From now on work directly on `main` (no feature branches). There is no git remote, so "push" = commit on `main`.

User reports:
1. Right-clicking a registered time entry on the timeline does nothing. It should offer **Edit** and **Delete**.
2. In the menu bar panel, the form to register time (pick project etc.) has a **transparent background**, so the text is unreadable. Same for editing an entry.

All conventions from PLAN.md §11 apply.

---

## 1. Context menu on time entries

- Add `.contextMenu` to `TimeEntryBlock` (`Features/Timeline/Views/TimeEntryBlock.swift`) with:
  - **Edit…** → same as a click: `TimelineViewModel.select(entry)` (selects it and opens the form in edit mode — sheet in the main window, inline form in the menu bar panel).
  - Divider
  - **Delete** (`role: .destructive`) → deletes the entry via `EntryEditingViewModel.delete(_:)` (through `TimeEntryEditor`, as the Delete key does).
- Pass the actions in as closures like `onTap` (e.g. `onEdit`, `onDelete`) from `TimeEntryLane`, so the block stays a dumb view. Add a small `TimelineViewModel.delete(_ entry:)` (or reuse `deleteSelectedEntry` logic) so the view doesn't start tasks on the editing view model directly — keep `TimelineViewModel.swift` within its current size (move code if needed).
- No confirmation dialog for Delete (the Delete key doesn't have one either); errors surface the same way as other entry errors (alert in the main window, `MenuBarErrorBanner` in the panel).
- Right-click must not start a drag, change the selection overlay, or show the hover card on top of the menu (hide/ignore the hover card while the context menu is open if it overlaps; at minimum make sure it doesn't block the menu).
- Works in both the main window and the menu bar panel (the block is shared).
- Optional, only if trivial: the same context menu on app-session blocks with **Register…** (same as click). Skip if it adds complexity.

## 2. Opaque form background in the menu bar panel

Cause (from reading the code — verify): `MenuBarFormView` uses `.background(.background)`. Inside a `MenuBarExtra` `.window` panel the `background` shape style resolves to the panel's translucent material (or clear), so the timeline layer underneath (in the `ZStack` of `MenuBarContentView`) shows through. v1.5 already fixed the panel itself with `Color(nsColor: .windowBackgroundColor)` in `MenuBarContentView`.

Fix:
- `MenuBarFormView`: use `.background(Color(nsColor: .windowBackgroundColor))` and make it fill the whole timeline area (`.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)`), so nothing of the timeline shows through around or below the form.
- Check the inner parts of the form for translucent backgrounds too (`ProjectSearchList` list/rows, text fields, `TimeEntryFormTimeFields`): everything must be readable on the opaque background in light and dark mode.
- Consider a shared constant/modifier (e.g. `View.panelBackground()` in `MenuBar/`) used by both `MenuBarContentView` and `MenuBarFormView`, so the color is defined once.
- The main window's sheet (`TimeEntryFormSheet`) is unaffected; verify it still looks the same.

## 3. Tests
- `TimelineViewModel.delete(_:)` (or whatever API the context menu uses) removes the entry (in-memory DB) and clears the selection; "Edit" opens the form in edit mode for that entry (existing `select` test may already cover it — extend if needed).
- No UI tests; describe what to check by hand.

## 4. Order of work
One or two commits directly on `main` (include this plan file), after `xcodebuild -project TimeTracker.xcodeproj -scheme TimeTracker -destination 'platform=macOS' -derivedDataPath build/DerivedData test` passes. Update PLAN.md where relevant (entry editing / menu bar sections). Then quit the running app, build into build/DerivedData and relaunch it normally (`open build/DerivedData/Build/Products/Debug/TimeTracker.app`, never with `-resetDatabase`).

## 5. Definition of done
- [ ] Right-click on an entry shows Edit… and Delete, in the main window and in the menu bar panel; both work.
- [ ] The menu bar form (new and edit) has an opaque background and is fully readable in light and dark mode.
- [ ] Main window sheet unchanged; all tests pass; no file above ~250 lines.
