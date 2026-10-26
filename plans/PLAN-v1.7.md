# TimeTracker v1.7 — Project highlight fix, README, app icon, publish to GitHub

Context: v1–v1.6 and the menu bar popup are on `main` (see PLAN.md and PLAN-v1.x.md). Work directly on `main`. The code will be pushed to `https://github.com/NickKoepr/TimeTracker.git` (an existing, empty, private repository) — the push itself is done by the main session after reviewing your work, **not by you**.

All conventions from PLAN.md §11 apply.

---

## 1. Bug: stale highlight in the project list

User report: when registering time, if you click a different project in the project list, the project that was preselected when the form opened keeps a light grey background. Looks odd.

Cause (verified by reading the code): `ProjectSearchList.row` has two visual states — `chosen` (accent background + checkmark, follows `form.projectId`) and `highlighted` (grey `Color.primary.opacity(0.08)`, follows `ProjectSearch.highlightedId`, the keyboard cursor for ↑/↓/Enter). `TimeEntryFormViewModel.init` sets `highlightedId` to the preselected project; `choose(_:)` (mouse click) only changes `form.projectId`, so the keyboard highlight stays on the initial project.

Fix:
- Add `mutating func highlight(_ id: Int64?)` to `ProjectSearch` and call it from `TimeEntryFormViewModel.choose(_:)` (and after `createProject()` it already moves via `add`), so the keyboard cursor follows the chosen project.
- In `ProjectSearchList.row`, don't draw the grey highlight on the chosen row (chosen style wins), so there is never a chosen + separately highlighted look for the same intent.
- Optional, if simple: ↑/↓ also chooses the highlighted project (like a native picker). Only do this if it keeps Enter/typing behaviour intact; otherwise skip.
- Tests: `ProjectSearch.highlight`, and `TimeEntryFormViewModel.choose` moves `search.highlightedId` to the chosen project.

## 2. README.md (English)

Create `README.md` at the repo root. Clear and concise, written for a developer who finds the repo. Sections:
1. **TimeTracker** — one-paragraph description: native macOS app (SwiftUI) for developers to register working hours per project; it records which (chosen) apps are in the foreground and shows them on a day timeline, where you drag to assign time to projects. Add the app icon image at the top (from §3, e.g. `docs/icon.png` 256 px).
2. **Features** — timeline with tracked app sessions and registered entries (drag to select, click a session, edit/move/resize, right-click Edit/Delete, zoom down to 10-minute detail, hover cards); projects with monthly totals and month navigation; tracked-apps list (only chosen apps are recorded; idle/sleep/lock pause tracking); menu bar panel with live status and the same timeline + popup form; local SQLite storage.
3. **Requirements** — macOS version (deployment target from the project: 27.0), Xcode version used, Swift 6. Note the App Sandbox; no special permissions needed.
4. **Getting started** — clone, open `TimeTracker.xcodeproj`, SPM resolves GRDB, run the `TimeTracker` scheme; command-line build/test commands (`xcodebuild ... build` / `test`).
5. **Architecture** — MVVM: Models (plain value types) → Repositories (protocols + GRDB implementations) → ViewModels (`@Observable @MainActor`, no GRDB/SwiftUI view types) → Views. Composition root `AppEnvironment`. Tracking service (`AppActivityTracker`, event stream). Database migrations (`Migrations.swift`, never edit an existing migration). Pure layout logic in `Features/Timeline/Layout`.
6. **Project structure** — an annotated tree of the actual folders (generate from the real tree; folders + the most important files, not every file), e.g. `App/`, `Models/`, `Database/`, `Repositories/`, `Services/` (incl. `Tracking/`), `Utilities/`, `Features/Root|Timeline|Projects|TrackedApps` (with `ViewModels/`, `Views/`, `Layout/`), `MenuBar/`, `TimeTrackerTests/`, `PLAN*.md`.
7. **Data & privacy** — where the database lives (`~/Library/Containers/<bundle id>/Data/Library/Application Support/TimeTracker/db.sqlite`), what is stored (app name + bundle id + start/end; no window titles, no keystrokes, no screenshots), nothing leaves the machine.
8. **Development** — tests (Swift Testing, 140+), the DEBUG-only `-resetDatabase YES` launch argument, the `PLAN*.md` files as design history / source of truth, coding conventions in short (one type per file, small files).
Keep it factual: verify every claim against the code (versions, paths, shortcuts).

## 3. App icon

The asset catalog has no `AppIcon` yet (`Assets.xcassets` only contains `AccentColor`), and there is no `ASSETCATALOG_COMPILER_APPICON_NAME` build setting.

- Design (simple, recognisable, fits macOS): rounded-rectangle macOS icon shape (Apple macOS icon grid: ~824×824 body centred on a 1024×1024 canvas, transparent outside, subtle drop shadow), a blue→teal (or indigo→blue) vertical gradient background, a white clock face with two hands, and on the right side of the clock 2–3 short horizontal coloured bars suggesting timeline blocks. No text.
- Generate it with a small, committed script so it is reproducible: `Tools/generate-app-icon.swift` (Swift + AppKit/CoreGraphics, run with `swift Tools/generate-app-icon.swift <output-dir>`), drawing at 1024 px and writing all macOS sizes: 16, 32, 64, 128, 256, 512, 1024 px (1x/2x pairs per `Contents.json`).
- Create `TimeTracker/Assets.xcassets/AppIcon.appiconset/` with the PNGs and a correct macOS `Contents.json` (idiom `mac`, sizes 16/32/128/256/512 at 1x and 2x).
- Set `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` for the app target (Debug and Release) in `project.pbxproj` (back it up first; verify with a build).
- Also export `docs/icon.png` (256 px) for the README.
- Check the built app bundle contains the icon (`AppIcon.icns` or `Assets.car` with the icon, and `CFBundleIconName` in the built Info.plist). Look at the generated 1024 px PNG yourself (Read tool can show images) and fix anything that looks off.

## 4. Repository hygiene before publishing

- `TimeTracker.xcodeproj/xcuserdata/` is tracked in git (personal Xcode state, changes all the time). Untrack it with `git rm -r --cached TimeTracker.xcodeproj/xcuserdata` (the local files stay) and add `xcuserdata/` to `.gitignore`.
- Make sure nothing personal or generated is committed: `build/`, `DerivedData/`, `.DS_Store` are already ignored; check `git ls-files` for anything else odd.
- Do not add a LICENSE (the repository is private; the owner decides).

## 5. Order of work
Commit each part separately on `main` (include this plan with the first commit), each after `xcodebuild -project TimeTracker.xcodeproj -scheme TimeTracker -destination 'platform=macOS' -derivedDataPath build/DerivedData test` passes:
1. Highlight fix + tests.
2. App icon (script, asset catalog, build setting, docs/icon.png).
3. README.
4. Repository hygiene (xcuserdata).
Then quit the running app, build into build/DerivedData and relaunch normally (`open build/DerivedData/Build/Products/Debug/TimeTracker.app`, never with `-resetDatabase`). Do **not** add a remote or push.

## 6. Definition of done
- [ ] Clicking another project leaves no grey highlight on the initially selected one.
- [ ] README.md in English with description, features, requirements, getting started, architecture, project structure, data & privacy, development.
- [ ] The app has an icon (Dock, Finder, menu bar app window), generated by a committed script.
- [ ] xcuserdata untracked and ignored.
- [ ] All tests pass; nothing pushed.
