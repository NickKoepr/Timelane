# TimeTracker v1.3 — Recorded sessions always stay visible

Context: v1–v1.2 are implemented on branch `feature/v1-implementation` (see PLAN.md and PLAN-v1.1/1.2). In v1.1 the timeline and menu bar were made to show only sessions of apps that are *currently* on the tracked-apps list (PLAN-v1.1.md §4.1: "Stored sessions of other apps are kept in the database but hidden; re-adding an app shows its history again").

User feedback: removing an app from the tracked list makes all its recorded sessions disappear, and re-adding it brings them back. The user wants: **once a session is recorded, it always stays on the timeline**, also after the app is removed from the tracked list.

New rule: the tracked-apps list only decides what is **recorded from now on**. Everything that was recorded is shown. The tracker (`AppActivityTracker`) is the only place that looks at the list.

Old data: v1 recorded all apps before the list existed; with the filter gone those sessions would reappear. The user is still testing and agreed to throw away the whole current database (projects, entries, sessions, tracked apps). The file is inside the app's sandbox container, which neither the shell nor Finder scripting may touch, so the app must delete it itself — see §1.5. No data migration is needed.

All conventions from PLAN.md §11 apply.

---

## 1. Changes

### 1.1 Timeline — `TimelineViewModel`
- Remove the filtering of sessions by the tracked-apps list (currently the computed set of tracked bundle ids around line 20 and its use before `AppSessionMerger`). `sessionBlocks` and `trackedTotal` are built from **all** stored sessions of the day.
- Keep observing the tracked-apps list only for `hasNoTrackedApps` (the banner). If nothing else needs the list, reduce the stored state to what the banner needs.
- The file must not grow; it should shrink.

### 1.2 Menu bar — `MenuBarViewModel`
- Remove the same filtering (the "Stored sessions of apps that are no longer tracked stay hidden" code). "Tracked today" sums all stored sessions of today.
- If the view model no longer needs the tracked-apps repository, remove that dependency (and its wiring in `MenuBarContentView` / `AppEnvironment`). "Not tracking: <App>" keeps working via `AppActivityTracker.isCurrentAppTracked`.

### 1.3 Tracked Apps screen
- Make the behaviour clear to the user: a short footer/caption under the list, e.g. "Only these apps are recorded. Removing an app stops recording it; time already recorded stays on the timeline." No confirmation dialog needed.

### 1.4 Tests
- Replace the test(s) that assert untracked sessions are hidden (in `TimelineViewModelTests` and/or `TrackedAppsTests`) with tests for the new rule:
  - a stored session of an app that is not (or no longer) on the tracked list is shown in `sessionBlocks` and counted in `trackedTotal`;
  - removing an app from the list while the timeline is observed does not change `sessionBlocks`;
  - menu bar "tracked today" includes sessions of removed apps.
- Tracker tests stay as they are: untracked apps still create no sessions.

### 1.5 Development reset of the database
- In `AppDatabase.live()`, **only in DEBUG builds** (`#if DEBUG`): when the launch argument `-resetDatabase YES` is present (`UserDefaults.standard.bool(forKey: "resetDatabase")`), delete `db.sqlite` and its `-wal` / `-shm` siblings (ignore "file not found") before opening the database. Log it with `os.Logger`.
- Release builds never contain this code. Document the argument in one line in PLAN.md.
- After the final build, launch the app once with it to wipe the user's test data:
  `open build/DerivedData/Build/Products/Debug/TimeTracker.app --args -resetDatabase YES`
  (Only that one launch; normal launches keep their data.)

### 1.6 Docs
- Update PLAN.md (tracked-apps section) and add a one-line note in PLAN-v1.1.md §4.1 that this rule was changed in v1.3, so the plans stay the source of truth.

---

## 2. Order of work
One commit on `feature/v1-implementation` (don't push) including this plan file, after `xcodebuild -project TimeTracker.xcodeproj -scheme TimeTracker -destination 'platform=macOS' -derivedDataPath build/DerivedData test` passes. Then make sure the app is not running (`osascript -e 'quit app "TimeTracker"'`), build into build/DerivedData and launch it **once with the reset argument** from §1.5. Verify through `log show --last 2m --predicate 'subsystem CONTAINS "TimeTracker"'` (or the bundle id) that the reset ran.

## 3. Definition of done
- [ ] Sessions recorded for an app stay on the timeline and in the totals after that app is removed from the tracked list.
- [ ] Untracked apps are still not recorded.
- [ ] Tracked Apps screen explains this.
- [ ] No unused tracked-apps code left in the timeline/menu bar view models.
- [ ] DEBUG-only `-resetDatabase YES` exists and the user's test database has been wiped once with it.
- [ ] All tests pass; plans updated.
