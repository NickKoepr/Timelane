# PLAN v1.25 — Project column header in Tracked Apps

Follow-up on PLAN-v1.13 (tracked app linked to a project). Branch `feature/tracked-apps-project-column`.

## Context

Every row in the Tracked Apps list showed a caption "Log hours automatically to" above its project
picker. Repeated in every row it looks cluttered. The owner wants one column header instead: a title
("Project") with a short subtext that explains what the selection does.

## Design

- `TrackedAppRow`: drop the per-row caption; the picker (accessibility label "Project", tooltip kept)
  gets a fixed width `TrackedAppRow.projectColumnWidth` (200 pt) and the remove button a fixed width
  `removeColumnWidth`, so every row's picker starts at the same x position.
- New `TrackedAppsColumnHeader`: "App" on the left and "Project" over the picker column, on one baseline.
  Next to "Project" an `info.circle` icon whose tooltip (`.help`) explains the picker: hours are logged
  automatically to this project while you use the app; changing it only affects new hours. (A visible
  caption under "Project" was tried first, but it pushed "Project" out of line with "App".) It uses the
  same widths and spacing as the row, so it lines up with the pickers.
- `TrackedAppsScreen`: the list becomes `List { Section { ForEach rows } header: { TrackedAppsColumnHeader() } }`
  (selection, tags, context menu and ⌫ delete unchanged). The bottom footnote no longer repeats the
  explanation: "Only these apps are recorded. Changing the project only affects new hours."

No model, view model or database changes.

## Tests

Pure view change; existing tests must stay green. Check by hand: header aligns with the pickers, the
info tooltip shows on hover, "App" and "Project" share a baseline, the list still selects/deletes, narrow window (detail ≥ 480 pt) fits.

## Definition of done

Tests pass, app rebuilt and relaunched, README updated, PR opened.
