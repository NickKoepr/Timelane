# TimeTracker v1.4 — Proper layout of the empty Projects screen

Context: v1–v1.3 are implemented on branch `feature/v1-implementation` (see PLAN.md and PLAN-v1.x.md). User feedback: when the Projects screen is empty, all UI elements are packed closely together in the middle of the window, which looks ugly. The elements should be spread over the screen the normal way: month navigation at the top, the empty state in the middle, the footer at the bottom.

All conventions from PLAN.md §11 apply.

---

## 1. Cause (from reading the code — verify)

`ProjectsScreen.body` is a `VStack(spacing: 0)` with `MonthNavigationBar`, a `Divider`, `list` and `ProjectsTotalFooter`. When there are rows, `list` is a `List`, which is flexible and takes all remaining height, so the bar is pushed to the top and the footer to the bottom. When there are no rows, `list` is a `ContentUnavailableView`, which only takes its ideal height. The whole `VStack` then has only its ideal size and the detail column centers it: the bar, empty state and footer end up stacked together in the middle. `MonthNavigationBar` and the footer also don't explicitly fill the width.

## 2. Changes

### 2.1 `ProjectsScreen`
- Give the empty state all remaining space: `.frame(maxWidth: .infinity, maxHeight: .infinity)` on the `ContentUnavailableView` (or on the `list` container, so both branches behave the same).
- Make the root of the screen fill the detail area: `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)` on the `VStack`.
- Result in both states: month bar pinned at the top, content filling the middle, footer pinned at the bottom.

### 2.2 Empty state content
Distinguish two situations (the view model already has `allTotals` / `rows`; add a small computed property if needed, e.g. `hasAnyProjects`):
- **No projects at all:** "No projects yet" / "Create a project to start registering hours." plus a prominent **"New Project"** button (`.borderedProminent`) inside the `ContentUnavailableView` `actions:` that opens the same form as the toolbar + / ⌘N.
- **Projects exist but none to show this month** (e.g. all archived without hours): "No hours in <Month Year>" / "Hours you register on the timeline show up here." No button needed. Make sure this case isn't reached accidentally for a normal empty month — check how `rows` is filtered in `ProjectsViewModel` (projects with 0 hours are listed unless archived) and keep that behaviour.

### 2.3 Month bar and footer
- `MonthNavigationBar`: fill the width (`.frame(maxWidth: .infinity, alignment: .leading)`), keep the current controls left-aligned, consistent padding with the footer.
- `ProjectsTotalFooter`: fill the width; when there are no projects at all, keep it visible (showing Total 0:00) but it must stay at the bottom.

### 2.4 Same check on the other screens
- `TrackedAppsScreen` empty state: also add `.frame(maxWidth: .infinity, maxHeight: .infinity)` and an **"Add App"** button in the `ContentUnavailableView` actions that opens the add sheet (same as the toolbar button).
- `TimelineScreen`: check it fills the detail area when the day is empty (it uses a fixed-height timeline in a `ScrollView`, so it probably does); only change it if it doesn't.

### 2.5 Tests and previews
- Unit test for the new view-model property that decides which empty state is shown (no projects vs. projects but nothing to show).
- Add `#Preview`s for the empty Projects screen (in-memory environment without data) and the empty Tracked Apps screen, sized like a normal window (e.g. `.frame(width: 800, height: 600)`), so the layout can be checked in Xcode's canvas.

## 3. Order of work
One commit on `feature/v1-implementation` (don't push) including this plan file, after `xcodebuild -project TimeTracker.xcodeproj -scheme TimeTracker -destination 'platform=macOS' -derivedDataPath build/DerivedData test` passes. Then quit the running app (`osascript -e 'quit app "TimeTracker"'`), build into build/DerivedData and relaunch it normally (`open build/DerivedData/Build/Products/Debug/TimeTracker.app`, WITHOUT the reset argument).

## 4. Definition of done
- [ ] Empty Projects screen: month bar at the top, empty state centered in the remaining space with a "New Project" button, footer at the bottom.
- [ ] Projects screen with data looks the same as before.
- [ ] Empty Tracked Apps screen fills the window and has an "Add App" button.
- [ ] Tests pass; previews for the empty states exist.
