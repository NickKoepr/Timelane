# PLAN v1.31 — App Store screenshots

## Context

Timelane goes to the Mac App Store, which needs marketing screenshots (16:10, up to 2880 × 1800 px, max. 10).
The owner wants every screen (Timeline, the entry form, Projects, Overview, Tracked Apps, Settings) plus the
menu bar panel, each on a background in the app icon's style (flat blue `#2F6BEA`, white clock) with one small
title. Light appearance, sample data about software / app development. No heavy marketing text.

Agents cannot take screenshots of other apps (no Screen Recording permission), and cannot click through the UI.
An app *can* capture its own windows with `CGWindowListCreateImage` without that permission, so the app captures
itself in a DEBUG-only screenshot mode.

## Design

### Screenshot mode (DEBUG only, `Timelane/Debug/Screenshots/`)

Launch argument `-screenshotScene <scene> -screenshotOutput <dir>` (both required). Everything is `#if DEBUG`;
release builds contain none of it.

- `ScreenshotScene` — `timeline`, `entryForm`, `menuBar`, `projects`, `overview`, `trackedApps`, `settings`.
- `ScreenshotMode` — reads the arguments; `isActive` is false in normal runs.
- `ScreenshotSampleData` — fills an in-memory database: six development projects (one archived), tracked apps
  (Xcode, Simulator, Figma, Visual Studio Code, Terminal, Postman, Safari — icons come from the installed apps),
  a detailed showcase day (the last weekday before today) with app sessions and entries, and logged hours on
  every working day since 1 January (with a summer holiday) so Projects and Overview are full.
- `AppEnvironment.screenshot()` — that database, iCloud backup shown as enabled and backed up a few minutes ago
  (in-memory store, nothing leaves the Mac).
- `ScreenshotDirector` — after launch: light appearance, fixed main window size, selects the screen, opens the
  form / settings / panel, waits for rendering, captures, writes `<scene>.png`, quits.
- `WindowSnapshot` — captures one window (`CGWindowListCreateImage`, looked up with `dlsym` because the Swift
  overlay marks it obsolete) without the system shadow; combines several windows (main window + sheet, main
  window + Settings) at their screen positions into one transparent PNG, with a shadow under the upper windows.
- `ScreenshotPanelWindow` — the menu bar panel content in a borderless rounded window (a real `MenuBarExtra`
  panel can't be opened from code).

Hooks in existing code (all `#if DEBUG`, no behaviour change otherwise):
- `AppEnvironment.shared` uses `screenshot()` when the mode is active.
- `AppDelegate` starts neither tracking nor backup in the mode, and starts the director.
- `TimelaneApp` hides the menu bar item in the mode (`MenuBarExtra(isInserted:)`) and adds the director view
  (needed for `openSettings`).
- `TimelineScreen` opens the new-entry form for a range the director asks for.
- `MenuBarContentView` gets an extra init that takes an existing `MenuBarViewModel`, so the director can show
  the showcase day in the panel.

### Capture + compose (`Tools/`)

- `Tools/make-app-store-screenshots.sh` builds an **unsandboxed, ad-hoc signed** Debug copy into
  `build/ScreenshotData` with its own bundle id `nl.nickkoepr.timelane.screenshots` (so the app may write to the
  output folder and the user's own app, database and defaults stay untouched), runs every scene with `-ApplePersistenceIgnoreState YES` and fixed zoom levels in the argument
  domain, then runs the composer.
- `Tools/compose-app-store-screenshots.swift` draws each 2880 × 1800 image: flat icon blue, the icon's clock
  + one short title at the top, the captured window(s) below with a soft shadow. The menu bar image puts the
  panel under a slim menu bar strip with the clock icon.

Output: `build/AppStoreScreenshots/raw/*.png` (captures) and `build/AppStoreScreenshots/*.png` (final).

## Files

New: `Timelane/Debug/Screenshots/{ScreenshotScene, ScreenshotMode, ScreenshotSampleData, AppEnvironment+Screenshot,
ScreenshotDirector, ScreenshotDirectorView, WindowSnapshot, ScreenshotPanelWindow, ScreenshotFormRequest}.swift`, `Tools/make-app-store-screenshots.sh`, `Tools/compose-app-store-screenshots.swift`.
Changed: `AppEnvironment` (+ `isIsolatedRun`), `AppDelegate`, `TimelaneApp`, `TimelineScreen`,
`MenuBarContentView` (optional `viewModel` in init), README (how to regenerate), AGENTS.

## Tests

`ScreenshotSampleDataTests`: the sample database has the projects, no overlapping entries on the showcase day, and
hours in every month up to now. The capture itself is checked by looking at the PNGs.

## Lessons from the first run

- An unknown scene must not fall back to the live environment (it then tracks into a stray database): the app
  `fatalError`s on incomplete screenshot arguments, and the script passes scenes one by one.
- The pointer can trigger hover cards; the director sets `ignoresMouseEvents` on every captured window.
- The panel's `PanelOpenObserver` jumps to today on every key change, so the showcase day is set last.

## Definition of done

All tests pass; `Tools/make-app-store-screenshots.sh` produces seven 2880 × 1800 PNGs in light appearance;
release build unaffected; README/AGENTS describe how to regenerate them.
