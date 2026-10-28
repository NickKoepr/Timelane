# PLAN v1.15 — Undo / Redo for time entries (⌘Z / ⇧⌘Z)

## Context

The user wants to undo (⌘Z) and redo (⇧⌘Z) changes to **logged hours** (time entries) only:
creating an entry, editing it (form, drag-move, drag-resize), and deleting it. Projects, tracked
apps, settings etc. are out of scope.

All time-entry changes already go through `TimeEntryEditor` (`create` / `update` / `delete`) →
`TimeEntryOverlapResolver` → one `TimeEntryRepository.save(_:deleting:)` transaction. One user
action can therefore touch several rows (the new entry plus trimmed / split / deleted neighbours).
Undo must restore **all** of them.

Callers of the editor: `TimeEntryFormViewModel` (create/update/delete from the form, also used by
the Record/Stop timer and the menu bar popup) and `EntryEditingViewModel` (drag move/resize,
delete). The editor instance is `AppEnvironment.timeEntryEditor`, shared by the main window and the
menu bar panel.

## Design (keep it simple)

### 1. `TimeEntryChange` (Models or Services, pure value type)

```swift
/// One user action on time entries: the affected rows before and after it.
struct TimeEntryChange: Equatable, Sendable {
    var before: [TimeEntry]   // rows (with ids) as they were; empty for a pure create
    var after: [TimeEntry]    // rows (with ids) as they are now; empty for a pure delete
    var inverted: TimeEntryChange { TimeEntryChange(before: after, after: before) }
}
```

Applying a change "forward" means: delete every id in `before` that is not in `after`, then save
(upsert) every row of `after` **with its id**. Undo = apply `change.inverted`; redo = apply
`change`. Because ids are kept, undo → redo → undo keeps working. (GRDB `save` on a record with an
id updates, or inserts with that explicit id when the row no longer exists — verify this in a
test.)

### 2. Repository changes (`TimeEntryRepository` + `GRDBTimeEntryRepository`)

- `save(_:deleting:)` becomes `@discardableResult ... -> [TimeEntry]` and returns the saved rows
  with their (new) ids. Existing callers keep compiling.
- Add `func entries(ids: [Int64]) async throws -> [TimeEntry]` (needed to capture "before": an
  edited entry may have moved completely out of the range the resolver looked at).

### 3. `TimeEntryEditor` changes

- Add `var onChange: @Sendable (TimeEntryChange) async -> Void = { _ in }` (default no-op, so all
  existing `TimeEntryEditor(repository:)` call sites and tests keep working).
- In `apply(_:)` (and `delete`): before saving, collect the ids that will be touched
  (`resolution.toDelete` + ids in `resolution.toSave`) and read them with `entries(ids:)` → `before`.
  The saved rows returned by `save` → `after`. Call `await onChange(change)`.
  For `delete`: `before = [current row]`, `after = []`.
- Add `func revert(_ change: TimeEntryChange) async throws` / or put the "apply a change" logic
  in the history (below) using the repository directly. It must **not** call `onChange`
  (otherwise undo would record itself).
- Keep `create/update/delete` signatures unchanged (another branch — PLAN-v1.13 auto logging — uses
  them; avoid merge conflicts).

### 4. `TimeEntryHistory` (`Features/Timeline/ViewModels/TimeEntryHistory.swift`)

`@MainActor @Observable final class`, created once in `AppEnvironment` and shared by the main window
and the menu bar.

- `private(set) var undoStack: [TimeEntryChange]`, `redoStack`, `var canUndo`, `var canRedo`,
  `var errorMessage: String?`.
- `func record(_ change: TimeEntryChange)` — push on undo stack, clear redo stack, cap at 50.
- `func undo() async` — pop, apply `change.inverted` via the repository (`save(change.before,
  deleting: ids only in after)`), push the change on the redo stack. On error: set `errorMessage`,
  don't push.
- `func redo() async` — mirror image.
- Put the pure stack bookkeeping in a small pure struct (e.g. `UndoStack<Element>`) so it is
  unit-tested without a database.

Wiring in `AppEnvironment.init`: create `timeEntryHistory` first, then
`TimeEntryEditor(repository: timeEntries, onChange: { [history] change in await history.record(change) })`.
Watch the init order / `self` capture (history must exist before the editor; capture the local,
not `self`).

**Important:** only the shared `timeEntryEditor` records history. Any other editor instance
(e.g. the automatic logger from PLAN-v1.13) uses its own `TimeEntryEditor(repository:)` without
`onChange`, so automatic writes never land on the undo stack. Mention this in the doc comment on
`AppEnvironment.timeEntryEditor`.

### 5. Keyboard shortcuts

Follow the existing "hidden buttons" pattern (see AGENTS.md trap about `ViewThatFits` and
`RootView.sidebarShortcuts`, `DayNavigationShortcuts`):

- New view `TimeEntryUndoShortcuts` (in `Features/Timeline/Views/`) with two hidden buttons:
  "Undo" `.keyboardShortcut("z", modifiers: .command)` and "Redo"
  `.keyboardShortcut("z", modifiers: [.command, .shift])`, `.disabled(!canUndo / !canRedo)`, each
  running `Task { await history.undo() }`. Hidden the same way the existing shortcut views are
  (look at how `sidebarShortcuts` hides them and copy it).
- Add it as background of `RootView` (works on every main-window screen) and of
  `MenuBarContentView` (menu bar panel).
- Show `history.errorMessage`: `.errorAlert` in `RootView`; in the menu bar use the existing inline
  error banner pattern (never an alert there — see AGENTS.md).
- Form sheets are separate windows, so ⌘Z inside a sheet's text field keeps its normal text undo.

Note for the user to check by hand: the default Edit menu also has "Undo"; confirm ⌘Z in the main
window triggers our undo (window key equivalents normally win over the menu). If it doesn't, replace
the Edit menu's undo group in `TimelaneApp` with `.commands { CommandGroup(replacing: .undoRedo) {…} }`
that calls the history — only do that if the hidden buttons don't work; report it in the PR.

## Files

- New: `Timelane/Models/TimeEntryChange.swift` (pure), `Timelane/Features/Timeline/ViewModels/TimeEntryHistory.swift`,
  optional `UndoStack.swift` (pure), `Timelane/Features/Timeline/Views/TimeEntryUndoShortcuts.swift` (+ `#Preview`).
- Changed: `TimeEntryRepository.swift`, `GRDBTimeEntryRepository.swift`, `TimeEntryEditor.swift`,
  `AppEnvironment.swift` (+ `AppEnvironment+Preview.swift` if needed), `RootView.swift`,
  `MenuBarContentView.swift` (and `MenuBarViewModel` only if needed for the error banner).
- Docs: `README.md` (feature list: ⌘Z / ⇧⌘Z for logged hours), `plans/PLAN.md` (short note in the
  relevant section), this plan as `plans/PLAN-v1.15.md`.

## Tests (Swift Testing, in-memory DB, see existing `TimeEntryEditorTests`)

- `UndoStack`: record clears redo, cap of 50, undo/redo order.
- `TimeEntryChange.inverted`.
- Repository: `save` returns ids; `entries(ids:)`; saving a row with an explicit id after it was
  deleted re-inserts it with the same id.
- `TimeEntryHistoryTests` (editor + history + in-memory repo):
  - create → undo → entry gone → redo → entry back with same id.
  - create that **splits** an existing entry → undo restores the original single entry exactly
    (start/end/project/title/note) and removes the tail → redo splits again.
  - update that moves an entry to a completely different time → undo puts it back.
  - delete → undo → entry restored with same id and fields.
  - several actions → multiple undos in reverse order; a new action after undo clears redo.
  - an editor created **without** `onChange` does not add history.

## Order of work

1. `git checkout -b feature/undo-redo` from `main`. Copy this plan to `plans/PLAN-v1.15.md`.
2. `TimeEntryChange` + `UndoStack` + tests.
3. Repository changes + tests.
4. Editor `onChange` + before/after capture.
5. `TimeEntryHistory` + wiring in `AppEnvironment` + history tests.
6. Shortcuts view in `RootView` and menu bar, error display.
7. README / PLAN.md.
8. Run all tests, build. Commit (message ends with the Co-Authored-By line), push branch, open PR.

## Definition of done

- All tests pass (`xcodebuild ... test` from AGENTS.md); app builds.
- ⌘Z undoes the last create/edit/move/resize/delete of a time entry, including the neighbours the
  overlap resolver changed; ⇧⌘Z redoes it. Works in the main window and the menu bar panel.
- No change to projects/tracked apps undo. No new dependencies. Files stay small (< ~150 lines).
- PR open on GitHub from `feature/undo-redo` to `main` with a summary and a manual test checklist.
