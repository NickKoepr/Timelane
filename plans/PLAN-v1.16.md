# PLAN v1.16 — Fix drag snap-back and the failing repository test (undo/redo branch)

Branch: `feature/undo-redo` (open PR NickKoepr/Timelane#1). Builds on PLAN-v1.15 (undo/redo).
Work on this branch, commit, and push to `origin feature/undo-redo` (do **not** merge into `main`).

## Problems

### A. Dragged entry briefly jumps back to its old place on release

Repro: drag a logged-hours block (move or resize) on the timeline and release. The block flashes at
its *old* position for a moment, then appears at the new position.

**Cause.** `EntryEditingViewModel.dragEnded(_:)` does

```swift
defer { self.preview = nil }
...
await perform { try await editor.update(changed) }
```

so the live drag preview is cleared as soon as the editor's `update` returns. But the timeline
draws entries from `TimelineViewModel.entries`, which only changes when the GRDB
`ValueObservation` (→ `AsyncStream`, `observeEntries(in:)`) delivers the new rows. That delivery is
asynchronous and can arrive *after* `update` returns. In between, `displayRange(for:)` has no
preview and falls back to the stale `entry.range` → the block jumps back.

On `main` the race was (mostly) won by luck. PLAN-v1.15 added two extra suspension points to
`TimeEntryEditor.apply` / `delete` (`repository.entries(ids:)` before the save and
`await onChange(...)` — a hop to the main actor for `TimeEntryHistory.record` — after it), which
makes the window between "update returned" and "observation delivered" reliably visible.

Do **not** "fix" this by removing the undo bookkeeping or by reordering awaits; the view must not
depend on timing at all.

### B. Failing test `TimeEntryRepositoryTests.saveReturnsIdsAndEntriesByIdAndReinsertsDeletedId`

```
Expectation failed: try await entries.entries(ids: [id, 999]) == saved      (line 23)
Expectation failed: try await entries.entries(ids: [id]) == saved           (line 27)
```

**Cause.** `GRDBTimeEntryRepository.save` returns the in-memory copies it wrote. `createdAt` /
`updatedAt` default to `Date.now` (sub-second precision). Dates are stored as
`timeIntervalSince1970` Doubles; `Date` internally uses `timeIntervalSinceReferenceDate`, so the
round trip loses the last bits and the fetched `Date`s are not `==` to the originals. Hence the
returned rows differ from what `entries(ids:)` reads back.

This is not only a test problem: `TimeEntryChange.after` (returned by `save`) and `before` (read
via `entries(ids:)`) should both be exactly what the database holds, so a change and its inverse are
symmetric.

## Design

### B. `save` returns the stored rows

In `GRDBTimeEntryRepository.save(_:deleting:)`, after writing all entries **inside the same write
transaction**, re-fetch them by id and return those, in the same order as the input:

```swift
return try await database.writer.write { db in
    _ = try TimeEntry.deleteAll(db, ids: ids)
    var savedIds: [Int64] = []
    for entry in entries {
        var copy = entry
        try copy.save(db)
        savedIds.append(copy.id!)   // set by save / didInsert
    }
    let byId = Dictionary(uniqueKeysWithValues: try TimeEntry.fetchAll(db, ids: savedIds).map { ($0.id!, $0) })
    return savedIds.compactMap { byId[$0] }
}
```

(Use `try #require`-free code; a `guard let id = copy.id` with a thrown `RepositoryError` is fine
instead of `!` if you prefer — match the file's style.) Update the doc comment in
`TimeEntryRepository.swift` ("Returns the saved rows with ids, as stored"). Keep the test unchanged:
it should now pass. Do not loosen the test with tolerances.

Also check `entries(ids:)` returns rows in a deterministic order; the test compares with a
one-element array so order does not matter there, but add `.order(Column("start"))` only if needed
— don't change behaviour otherwise.

### A. Keep the preview until the new rows are observed

Make the drag preview survive until the timeline actually shows the committed range.

`EntryEditingViewModel`:

- Add a private flag/state for "committed, waiting for observation", e.g.
  `private var awaitingCommit = false` (or put a `isCommitting: Bool` on `EntryDragPreview`).
- `dragEnded(_:)`:
  - no preview / different entry → return (unchanged);
  - `preview.range == entry.range` → clear preview, return (unchanged);
  - otherwise mark the preview as committing, run `editor.update(changed)`;
    - on **error**: clear the preview immediately and set `errorMessage` (block returns to its old
      place, which is correct);
    - on **success**: leave the preview in place.
  - Remove the `defer { self.preview = nil }`.
- Add `func entriesDidChange(_ entries: [TimeEntry])`: if the preview is committing and the entry
  with `preview.entryId` is either missing from `entries` or its range equals the preview range
  (compare start/end with a small tolerance, e.g. `abs(a.timeIntervalSince(b)) < 1`, because of the
  Double round trip described in B — add a tiny helper, e.g. `DateRange.isApproximatelyEqual(to:)`
  or a private func), clear the preview.
  A preview that is still being *dragged* (not committing) must never be cleared by this.
- `dragChanged` starting a new drag replaces the preview as today (also clears the committing flag).
- `reset()` keeps clearing everything (day change etc.).

`TimelineViewModel.observeEntries(in:)`:

```swift
for await value in timeEntries.observeEntries(in: range) {
    entries = value
    entryEditing.entriesDidChange(value)
}
```

(Keep `TimelineViewModel.swift` ≤ ~205 lines; this is a one-line change.)

Edge cases to reason about (and cover in tests where noted):
- The overlap resolver never changes the dragged entry itself (newest action wins), so the observed
  range equals the preview range after a successful save.
- An observation that arrives while the save is still running carries the *old* range → preview
  must stay (tolerance compare fails) ✔.
- Undo right after a drop: by then the observation has arrived and the preview is gone; undo changes
  `entries` normally.
- The menu bar panel has its own `TimelineViewModel` with the same code path → fixed too.

## Files

- `Timelane/Repositories/GRDB/GRDBTimeEntryRepository.swift` — return re-fetched rows.
- `Timelane/Repositories/TimeEntryRepository.swift` — doc comment.
- `Timelane/Features/Timeline/ViewModels/EntryEditingViewModel.swift` — committing preview,
  `entriesDidChange`.
- `Timelane/Features/Timeline/ViewModels/TimelineViewModel.swift` — forward observed entries.
- Possibly `Timelane/Features/Timeline/Layout/EntryDragPreview.swift` (wherever it lives) if the
  flag goes there.
- Tests: `TimelaneTests/EntryEditingViewModelTests.swift`, maybe `TimelineViewModelTests.swift`.
- `plans/PLAN.md`: one line under the iteration list for v1.16 (match existing format).

## Tests

1. `TimeEntryRepositoryTests.saveReturnsIdsAndEntriesByIdAndReinsertsDeletedId` passes unchanged.
2. Update `EntryEditingViewModelTests.movingCommitsSnappedRangeAndResolvesOverlap` (and any other
   test asserting `preview == nil` right after a successful `dragEnded`): after `dragEnded` the
   preview is **still set** and `displayRange(for: moving)` is the new range; after
   `vm.entriesDidChange(try await repo.entries(in: day))` the preview is `nil`.
3. New: `previewSurvivesStaleObservation` — after a successful `dragEnded`, calling
   `entriesDidChange([moving])` (old range) keeps the preview and `displayRange` stays the new range.
4. New: `failedCommitClearsPreview` — make the save fail (e.g. a fake `TimeEntryRepository` that
   throws, or an editor error such as a too-short range if reachable) → preview `nil`,
   `errorMessage` set.
5. New: `observationDoesNotClearActiveDrag` — during `dragChanged` (no `dragEnded`), calling
   `entriesDidChange` keeps the preview.
6. New: committing preview is cleared when the entry disappears from the observed list.
7. All existing tests (incl. `TimeEntryHistoryTests`, `TimeEntryEditorTests`) stay green.

## Order of work

1. Fix B, run the tests (expect only drag tests possibly unaffected / the repo test green).
2. Implement A + tests.
3. Full test run:
   `xcodebuild -project Timelane.xcodeproj -scheme Timelane -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
4. Rebuild and relaunch the Debug app (see AGENTS.md; never `-resetDatabase YES`).
5. Commit on `feature/undo-redo` ("Fix drag snap-back after drop and stored-row return of save"
   + Co-Authored-By line) and push to `origin feature/undo-redo`.

## Definition of done

- All unit tests pass (0 issues).
- Dropping a dragged/resized block leaves it at the new place with no flash back (manual check by
  the owner — the agent cannot see the UI).
- A failed drop returns the block to its original place and shows the error.
- Undo/redo of a drag still works (⌘Z puts it back, ⇧⌘Z moves it again).
- Changes committed and pushed to the PR branch; no changes to `main`.
