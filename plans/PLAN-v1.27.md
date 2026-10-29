# PLAN v1.27 — Info popover text is cut off on the Tracked Apps screen

## Context

The Tracked Apps screen has a "Project" column header with an info icon
(`InfoHoverIcon`, `Timelane/Features/TrackedApps/Views/InfoHoverIcon.swift`, used in
`TrackedAppsColumnHeader.swift`). Hovering the icon opens a `.popover` with the text
"Hours are logged automatically to this project while you use the app. Changing it only
affects new hours." (added in v1.26 / PR #11).

## Bug

The text inside the popover is cut off: the last line(s) are not visible, so the
explanation can't be read in full.

## Cause

The popover content is

```swift
Text(text)
    .font(.callout)
    .fixedSize(horizontal: false, vertical: true)
    .frame(width: 240, alignment: .leading)
    .padding(10)
```

The first guess was popover sizing (the popover is sized from the hosting view's ideal
size). Making the size definite was not enough: on screen the popover still showed one
line ending in "…". The real cause: `TrackedAppsColumnHeader` is the header of a `List`
`Section`, and on macOS a section header sets `lineLimit(1)` in the environment. A popover's
content inherits the environment of the view it is attached to, so the explanation was
limited to one line and truncated.

Fix: set `.lineLimit(nil)` on the popover text explicitly (in addition to the definite
sizing below). The unit test hosts the content under `.lineLimit(1)` to reproduce this.

## Design

Make the popover content report a definite, correct size for the wrapped text:

1. Give the text a fixed width and let it take its ideal height at that width, with the
   size fixed on the *outermost* view that the popover hosts (after the padding), e.g.

   ```swift
   Text(text)
       .font(.callout)
       .multilineTextAlignment(.leading)
       .frame(width: 240, alignment: .leading)
       .fixedSize(horizontal: false, vertical: true)
       .padding(10)
       .fixedSize()
   ```

   or an equivalent arrangement. The essential points: the width is fixed (240pt), the
   height comes from the wrapped text at that width, and nothing can compress it.
2. Keep `lineLimit` unlimited (no truncation) — do not shorten the explanation text.
3. Keep the instant-on-hover behaviour and `arrowEdge: .bottom`; keep the accessibility label.

If (1) still clips, the fallback is to measure the needed height explicitly: compute the
text height with `NSAttributedString.boundingRect(with:options:)` for
`NSFont.preferredFont(forTextStyle: .callout)` at width 240 and set
`.frame(width: 240, height: measured)` — put that measurement in a small pure helper only if
it is really needed.

## Verification (the agent cannot see the UI)

- Add a focused unit test if it's cheap and meaningful: host the popover content view in an
  `NSHostingView` (or `NSHostingController` with `sizingOptions = .preferredContentSize`),
  read `fittingSize` / `preferredContentSize`, and assert the height is at least the height
  of the text measured with `boundingRect` at width 240 + 20pt padding. To make the content
  testable, extract it into its own small view (e.g. `InfoPopoverText`, in its own file,
  with a `#Preview`). If such a test turns out to be flaky or meaningless in the test host,
  skip it and say so.
- Run the full test suite.

## Files

- `Timelane/Features/TrackedApps/Views/InfoHoverIcon.swift` — fix the popover sizing.
- Optionally `Timelane/Features/TrackedApps/Views/InfoPopoverText.swift` (+ a test in `TimelaneTests/`).
- `plans/PLAN-v1.27.md` — this plan.

No README / PLAN.md change needed (behaviour is unchanged, only a visual bug).

## Order of work

1. Copy this plan to `plans/PLAN-v1.27.md` (update the Cause section if needed).
2. Fix the sizing; optionally extract + test.
3. Run tests:
   `xcodebuild -project Timelane.xcodeproj -scheme Timelane -destination 'platform=macOS' -derivedDataPath build/DerivedData test`
4. Commit, push the branch, open a PR to `main`.

## Definition of done

- Hovering the info icon shows the full explanation, wrapped at ~240pt, nothing clipped.
- All tests pass.
- PR open against `main` with a short description and what to check by hand.
