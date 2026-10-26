# TimeTracker v1.8 — New app icon, honest tracking indicator in the menu bar

Context: v1–v1.7 are on `main` and pushed to `origin` (https://github.com/NickKoepr/TimeTracker). Work directly on `main`. The main session reviews and pushes afterwards — **do not push**.

All conventions from PLAN.md §11 apply.

---

## 1. New app icon

User feedback: the current icon (purple→teal gradient, clock + coloured bars) is not nice. Wanted: **a solid background colour (no gradient) with simply a clock icon**. It must also be the icon shown in the **Dock**.

### 1.1 Design
- Standard macOS icon shape: rounded rectangle body ~824×824 centred on a 1024×1024 transparent canvas (corner radius ≈ 185), with the usual soft drop shadow under the body (shadow only — no gradients, no inner shading, no gloss).
- **Solid background colour**: one flat colour. Use a calm, saturated blue such as `#2F6BEA` (pick one, keep it a named constant at the top of the script so it's easy to change).
- **Clock** centred, drawn in white, flat, clearly readable at 16 px:
  - a thick white ring (or a white filled disc with the clock drawn in the background colour — choose whichever reads best at 16 and 32 px),
  - hour and minute hands with round caps (e.g. 10:10 or 12:45 — something balanced), a centre dot,
  - optionally 4 small tick marks at 12/3/6/9; drop them if they muddy the small sizes.
  - No timeline bars, no text, no extra elements.
- Do **not** use an SF Symbol glyph in the icon (Apple's SF Symbols licence forbids symbols in app icons); draw the clock with CoreGraphics paths.

### 1.2 Implementation
- Rewrite `Tools/generate-app-icon.swift` for the new design (same usage: `swift Tools/generate-app-icon.swift <output-dir>`), regenerate all PNGs in `TimeTracker/Assets.xcassets/AppIcon.appiconset/` (keep `Contents.json` valid) and `docs/icon.png` (256 px, used by the README).
- Look at the 1024 px result **and** at the 16/32 px PNGs yourself (Read tool shows images); iterate until it is clean and the clock is recognisable at 16 px.

### 1.3 Dock
- The app is a regular app (Window scene + MenuBarExtra, no `LSUIElement`), so the Dock shows the bundle icon. The built bundle already has `CFBundleIconName = AppIcon` and `AppIcon.icns`; verify this is still true after rebuilding.
- macOS caches app icons. After the rebuild: `touch` the built `.app`, re-register it with LaunchServices (`/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f <path to .app>`), then quit and relaunch the app so the Dock shows the new icon. Do not kill the Dock or Finder. In the report, tell the user what to do if the Dock still shows an old/generic icon (e.g. remove the app from the Dock if it is pinned and launch again, or log out/in).

## 2. Tracking indicator in the menu bar panel

User report: the status line in the menu bar panel shows "Not tracking: X" when the frontmost app is not on the tracked list, but the icon in front of it is still the **red recording dot**, which wrongly signals that time is being recorded.

Current code: `MenuBar/MenuBarStatusLine.swift` picks the icon only from `tracker.isPaused` (`pause.circle` grey vs. `record.circle` red); the text uses `isCurrentAppTracked`.

### 2.1 States
Introduce a pure value type, e.g. `Services/Tracking/TrackingStatus.swift`:
```swift
enum TrackingStatus: Equatable {
    case tracking(appName: String)        // frontmost app is tracked and a session is being recorded
    case notTracked(appName: String?)     // frontmost app is not on the list (or no app)
    case paused                           // idle, sleep, screen lock
    init(isPaused: Bool, currentApp: ForegroundApp?, isCurrentAppTracked: Bool)
    var text: String                      // "Xcode" / "Not tracking: Safari" / "Not tracking" / "Paused"
}
```
(Put the SF Symbol / colour mapping in the view layer, not in this type.)

| State | Icon (SF Symbol) | Colour | Text |
|---|---|---|---|
| tracking | `record.circle` | red | app name |
| notTracked | `eye.slash` (or `circle.slash`) | secondary (grey) | "Not tracking: <App>" / "Not tracking" |
| paused | `pause.circle` | secondary (grey) | "Paused" |

- Expose `var status: TrackingStatus` on `AppActivityTracker` (computed from existing state; keep the file within its size limit) or compute it in the view from the tracker — whichever keeps MVVM clean.
- `MenuBarStatusLine` uses the status for icon, colour and text. Add an accessibility label ("Recording Xcode", "Not tracking Safari", "Tracking paused").
- Optional, only if simple and reliable: reflect the same state in the menu bar item itself (`MenuBarExtra` label), e.g. `clock` normally and a variant (`clock.badge.xmark` / dimmed) when not tracking. If `MenuBarExtra`'s label doesn't update reliably, skip it and say so.

### 2.2 Tests
- `TrackingStatus` init for all combinations (paused wins over everything; no current app → notTracked(nil); tracked/untracked app) and `text`.

## 3. Docs
- README: update the icon description if it mentions the gradient; mention the three tracking states in the menu bar feature line.
- PLAN.md: short note in the menu bar section about the status states.

## 4. Order of work
Two commits on `main` (include this plan with the first), each after `xcodebuild -project TimeTracker.xcodeproj -scheme TimeTracker -destination 'platform=macOS' -derivedDataPath build/DerivedData test` passes:
1. New app icon (script, PNGs, docs/icon.png) + Dock refresh.
2. Tracking status indicator + tests + docs.
Then quit the running app, build into build/DerivedData, refresh LaunchServices as in §1.3 and relaunch normally (`open build/DerivedData/Build/Products/Debug/TimeTracker.app`, never with `-resetDatabase`). Do not push.

## 5. Definition of done
- [ ] Icon: flat solid-colour background with a white clock, readable at 16 px, no gradient; shown in the Dock and Finder.
- [ ] Menu bar status line: red dot only while actually recording; grey "not tracking" icon for untracked apps; grey pause icon when paused.
- [ ] Tests pass; README/PLAN updated; committed on main, not pushed.
