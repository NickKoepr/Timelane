# PLAN v1.28 — Fix Swift 6 concurrency and unused-result warnings

Branch `fix/xcode-warnings` (from `main`). No behaviour change; only compiler warnings.

## Context

Xcode reports four warnings:

| # | Location | Warning |
|---|----------|---------|
| 1 | `Features/Overview/Views/ActivityHeatmap.swift:38` | Call to main actor-isolated instance method `heatmapSizing(for:)` in a synchronous nonisolated context |
| 2 | `Features/Projects/Views/MonthNavigationBar.swift:48` | Call to main actor-isolated initializer `init(title:shortTitle:...)` in a synchronous nonisolated context |
| 3 | `Features/TrackedApps/Views/TrackedAppRow.swift:27` | Converting non-Sendable function value to `@isolated(any) @Sendable (Int64?) -> Void` may introduce data races |
| 4 | `Repositories/GRDB/GRDBTrackedAppRepository.swift:33` | Result of call to `write` is unused |

## Causes and fixes

### 1. `ActivityHeatmap` — alignment guide closure

`View` is `@MainActor`, so the private helper `heatmapSizing(for:)` is main-actor isolated. The
`.alignmentGuide` compute closure is nonisolated (SwiftUI may call it during layout off the main
actor's static isolation), so calling the helper from it warns.

Fix: make the helper `nonisolated`. It only reads `let` properties of a value-type view
(`layout.columnCount`, `labelWidth`, `spacing`, `cellRange`) and builds a pure `ActivityHeatmapSizing`.
If the compiler then complains about reading `layout` from a nonisolated context (non-Sendable
`ActivityHeatmapLayout`), instead capture the plain values in `body` before the modifier
(e.g. `let columnCount = layout.columnCount`) and compute the sizing inside the closure from those
captured `Sendable` values via a small `nonisolated static func`. Keep the existing comment above
the modifier — the guide must still be computed from `d.width`, not the `width` state.

### 2. `MonthNavigationBar` — preview helper

`barPreview(width:)` is a file-level free function, so it is nonisolated, and it calls the
main-actor initializer of the view. Fix: annotate it `@MainActor`.

### 3. `TrackedAppRow` — `Binding(get:set:)` with a stored closure

`Binding`'s `set` parameter is `@isolated(any) @Sendable`. Passing the stored, non-Sendable
`onProjectChange` value directly triggers the conversion warning. Fix: pass a closure literal
instead, `set: { onProjectChange($0) }` (formed in the main-actor `body`, so it is inferred as
main-actor isolated). If that still warns, mark the property type `@MainActor (Int64?) -> Void`
and check the call site in `TrackedAppsView` (or wherever the row is built) still compiles.

### 4. `GRDBTrackedAppRepository.setProject` — unused `write` result

The single-expression closure returns `updateAll`'s `Int`, so `write` returns it and the result is
dropped. Fix like `remove(id:)` in the same file: `_ = try TrackedApp.filter(key: id).updateAll(...)`.

## Out of scope

Other warnings that may appear in a clean build are not part of this plan; list them in the PR
description if seen, but don't fix them here.

## Order of work

1. Apply fixes 4, 2, 3, 1 (simplest first).
2. Build with `xcodebuild ... build 2>&1 | grep -E "warning:"` and confirm none of the four remain
   (do a clean build or touch the files so they are recompiled).
3. Run the unit tests.

## Definition of done

- The four warnings are gone; no new warnings or errors.
- All unit tests pass; behaviour unchanged (heatmap still switches to scrolling on narrow widths,
  project picker in Tracked Apps still saves the selection).
