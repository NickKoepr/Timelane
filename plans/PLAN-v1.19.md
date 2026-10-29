# PLAN v1.19 — Export a month of logged hours (JSON / Excel)

Branch: `feature/month-export` (branched from `origin/main`). A PR to `main` is opened for it.
Commit on this branch; do **not** merge into `main`.

## Goal

On the **Projects** screen the user can export all hours registered in the month that is shown
(the month of `ProjectsViewModel.month`) to a file. After choosing *Export…* the app asks which
format to use, then shows a save panel. Supported formats now: **JSON** and **Excel (.xlsx)**.
Adding a format later (CSV, PDF, …) must be a matter of adding one type and registering it —
no changes to the view model, the screen or the other formats.

Non-goals: import, exporting arbitrary date ranges, exporting app sessions, settings for columns.

## Constraints (from AGENTS.md / PLAN.md §11)

- MVVM: models are plain structs; view models are `@MainActor @Observable final class`, no
  SwiftUI views and no `import GRDB`; views contain no business logic and never call repositories.
- Pure logic (building the export, JSON/XLSX encoding, ZIP, CRC-32) lives in side-effect-free
  types and is unit-tested.
- **No third-party dependencies.** The `.xlsx` file is written by hand (Office Open XML in a
  ZIP archive). Foundation has no ZIP API, so we write a small *stored* (uncompressed) ZIP writer.
  Excel, Numbers and LibreOffice all open stored-only `.xlsx` files.
- One type per file, file name = type name, files < 150 lines (hard limit ~250).
- Every view has a `#Preview` using `AppEnvironment.preview()`.
- UI text in English.
- Default actor isolation is nonisolated; mark main-actor types explicitly. Pure types should be
  `Sendable` structs/enums.

## Sandbox: allow writing user-selected files

The app is sandboxed with `ENABLE_USER_SELECTED_FILES = readonly` (there is no `.entitlements`
file; entitlements come from build settings in `Timelane.xcodeproj/project.pbxproj`, app target,
Debug **and** Release). Change both to `readwrite`. Without this, writing to the URL from the
save panel fails with a permission error. Do not touch any other build setting.

## Design

### 1. Data: `MonthExport` (read model) — `Timelane/Services/Export/`

```swift
/// Everything one export contains, independent of the file format.
struct MonthExport: Sendable, Hashable {
    struct ProjectTotal: Sendable, Hashable {
        var name: String
        var colorHex: String
        var isArchived: Bool
        var totalSeconds: TimeInterval
    }
    struct Entry: Sendable, Hashable {
        var projectName: String
        var start: Date        // clipped to the month
        var end: Date          // clipped to the month
        var title: String?
        var note: String?
        var duration: TimeInterval { end.timeIntervalSince(start) }
    }
    var month: DateRange
    var generatedAt: Date
    var timeZone: TimeZone
    var projects: [ProjectTotal]   // only projects with hours this month, sorted by total desc, then name
    var entries: [Entry]           // sorted by start
    var totalSeconds: TimeInterval { projects.reduce(0) { $0 + $1.totalSeconds } }
}
```

`MonthExportBuilder` (pure `enum` with a `static func build(month:projects:entries:generatedAt:calendar:) -> MonthExport`):
- Input: the month range, **all** projects (archived too — like `monthTotals`, the export includes
  archived projects' hours; hiding archived rows on screen is display only) and the entries
  overlapping the month.
- Clip each entry to the month (`DateRange.intersection(with:)`); drop entries with no overlap.
- Entries whose `projectId` has no project get project name `"Unknown project"` (defensive).
- Totals per project = sum of the clipped durations; projects without hours are left out.
- `title` / `note`: trim whitespace; empty → `nil`.

`MonthExportService` (`struct`, `Sendable`, deps through `init`: `any ProjectRepository`,
`any TimeEntryRepository`, `calendar`, `now`):
- `func makeExport(for month: DateRange) async throws -> MonthExport` — fetches all projects and
  `timeEntries.entries(in: month)` and calls the builder.
- `ProjectRepository` has no one-shot "all projects" fetch. Add
  `func projects(includeArchived: Bool) async throws -> [Project]` to the protocol and
  implement it in `GRDBProjectRepository` (same query as `observeProjects`). Add a repository test.
  Check that `TimeEntryRepository.entries(in:)` returns entries that *overlap* the range (not only
  ones fully inside it); if it doesn't, fix the builder input accordingly and cover it in a test.

### 2. Extensible formats — `Timelane/Services/Export/Formats/`

```swift
/// One export file format. To add a format: implement this protocol and add it to `ExportFormats.all`.
protocol MonthExportFormat: Sendable {
    var id: String { get }                // stable, e.g. "json", "xlsx" (used for the last-used choice)
    var displayName: String { get }       // "JSON", "Excel (.xlsx)"
    var summary: String { get }           // one line shown under the option in the format sheet
    var contentType: UTType { get }
    var fileExtension: String { get }
    func data(for export: MonthExport) throws -> Data
}

enum ExportFormats {
    static let all: [any MonthExportFormat] = [ExcelMonthExportFormat(), JSONMonthExportFormat()]
    static func format(id: String) -> (any MonthExportFormat)?
}
```

Nothing outside `ExportFormats.all` may switch on concrete formats. The view model and views only
see `any MonthExportFormat`.

`MonthExportFileName` (pure): `"Timelane 2026-10.\(ext)"` from the month start in the export's
calendar. Unit-test it.

#### 2a. JSON — `JSONMonthExportFormat`

Encode through private `Encodable` DTOs (don't make the models `Codable` for this). `JSONEncoder`
with `[.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]`. Dates as ISO 8601 strings **with
the local offset** (`ISO8601DateFormatter`, `timeZone = export.timeZone`), e.g.
`2026-10-03T09:00:00+02:00`. Hours as a number rounded to 2 decimals. Shape:

```json
{
  "schemaVersion": 1,
  "app": "Timelane",
  "month": "2026-10",
  "generatedAt": "2026-10-29T14:03:00+01:00",
  "timeZone": "Europe/Amsterdam",
  "totalSeconds": 151200,
  "totalHours": 42,
  "projects": [
    { "name": "Acme", "color": "#4F8EF7", "archived": false, "totalSeconds": 108000, "totalHours": 30 }
  ],
  "entries": [
    { "project": "Acme", "date": "2026-10-03", "start": "2026-10-03T09:00:00+02:00",
      "end": "2026-10-03T12:30:00+02:00", "durationSeconds": 12600, "durationHours": 3.5,
      "title": "Sprint review", "note": null }
  ]
}
```

`title`/`note` are `null` when absent (encode explicitly, so every entry has the same keys).
`schemaVersion` lets future versions change the shape.

#### 2b. Excel — `ExcelMonthExportFormat` (+ small generic writer)

Split in reusable, testable pieces (all pure):

- `CRC32` — `static func checksum(_ data: Data) -> UInt32`, table-based (polynomial `0xEDB88320`).
  Known vector: `"123456789"` → `0xCBF43926`.
- `ZipArchiveWriter` — builds a ZIP archive in memory from `[(path: String, data: Data)]` using
  method 0 (stored): local file headers, central directory, end-of-central-directory record;
  little-endian fields; UTF-8 names (general-purpose flag bit 11); a fixed DOS date/time
  (1980-01-01 00:00) so output is deterministic. No ZIP64 (exports are tiny; throw if > 4 GB).
- `SpreadsheetWorkbook` — format-neutral model: sheets with a name and rows of cells.
  `enum SpreadsheetCell { case text(String), number(Double, style: NumberStyle), date(Date), time(Date), empty, }`
  plus a `bold` flag for header rows (pick the simplest shape that works; keep it small).
- `XLSXWriter` — turns a `SpreadsheetWorkbook` into `.xlsx` `Data`:
  `[Content_Types].xml`, `_rels/.rels`, `xl/workbook.xml`, `xl/_rels/workbook.xml.rels`,
  `xl/styles.xml`, `xl/worksheets/sheetN.xml`. Strings as inline strings (`t="inlineStr"`, so no
  `sharedStrings.xml`); XML-escape `& < > " '` and strip characters illegal in XML 1.0.
  Dates/times as Excel serial numbers (days since 1899-12-30, computed in the export's time zone)
  with number formats in `styles.xml`: `yyyy-mm-dd`, `hh:mm`, `0.00` (hours). Bold font for
  headers. Set column widths (`<cols>`) and freeze the header row. Sheet names ≤ 31 chars, no
  `[]:*?/\`. Cell references `A1`, `B1`, … (`AA` after `Z`).
- `ExcelMonthExportFormat` — maps `MonthExport` → workbook with two sheets:
  - **Summary**: title row "Timelane — October 2026", blank row, header `Project | Hours | Archived`,
    one row per project (hours as number with `0.00`), then a bold `Total` row.
  - **Entries**: header `Date | Start | End | Hours | Project | Title | Note`, one row per entry.

  Hours = seconds / 3600 as a plain number so the user can sum in Excel.

### 3. View model — `Timelane/Features/Projects/ViewModels/MonthExportViewModel.swift`

Separate type (don't grow `ProjectsViewModel`).

```swift
@MainActor @Observable
final class MonthExportViewModel {
    let formats: [any MonthExportFormat]
    var selectedFormatID: String          // last used (UserDefaults, injected), default first format
    var isChoosingFormat = false
    var errorMessage: String?
    private(set) var isExporting = false

    init(service: MonthExportService, formats: [any MonthExportFormat] = ExportFormats.all,
         defaults: UserDefaults = .standard)

    func beginExport()                    // isChoosingFormat = true
    /// Builds the file for `month` in the selected format. Returns the bytes + suggested file name.
    func prepareFile(for month: DateRange) async -> ExportFile?
    func write(_ file: ExportFile, to url: URL)   // writes atomically, sets errorMessage on failure
}

struct ExportFile: Sendable { var data: Data; var fileName: String; var contentType: UTType }
```

- Remember the chosen format under a UserDefaults key (`"export.lastFormatID"`); in tests inject
  a throw-away suite (see the "Tests" trap in AGENTS.md). Unknown stored id → first format.
- An empty month (no entries) still exports (a file with zero rows); the sheet shows a note
  "No hours registered in October 2026." — but exporting stays allowed.
- Errors (repository, encoding, writing) → `errorMessage` (shown with `.errorAlert`).

### 4. Views — `Timelane/Features/Projects/Views/`

- `ProjectsScreen`: add a toolbar item **Export…** (`square.and.arrow.up`), shortcut ⇧⌘E,
  `.help("Export this month")`, next to "New project". It calls `exportModel.beginExport()`.
  Create the `MonthExportViewModel` in `init` like `ProjectsViewModel` (service built from
  `environment.projects` / `environment.timeEntries`).
  - Register the shortcut on the toolbar button only once (it is not inside a `ViewThatFits`).
- `ExportFormatSheet` (new): title "Export October 2026", a radio-style `Picker` (`.radioGroup`)
  over `formats` showing `displayName` + `summary`, buttons **Cancel** (`.cancelAction`) and
  **Export…** (`.defaultAction`, disabled while `isExporting`). On Export: `prepareFile(for:)`,
  dismiss the sheet, then present the save panel.
- `ExportSavePanel` (new, `enum`, like `ApplicationOpenPanel`): `@MainActor static func chooseURL(fileName:contentType:) -> URL?`
  using `NSSavePanel` (`allowedContentTypes = [contentType]`, `nameFieldStringValue = fileName`,
  `canCreateDirectories = true`, prompt "Export"). Present it **after** the sheet has dismissed
  (e.g. set a pending `ExportFile` and run the panel from `.onChange`/`sheet(onDismiss:)`), not
  while the sheet is still on screen.
- The menu bar panel gets no export (the save panel would make the panel lose key — see traps).
- `#Preview` for `ExportFormatSheet` using `AppEnvironment.preview()`.

### 5. Docs

- `README.md` → Features: one bullet for the month export (JSON / Excel); Data & privacy: exported
  files are written only where the user chooses.
- `plans/PLAN.md`: add the export to the Projects screen section and mention the
  `MonthExportFormat` extension point (where conventions/architecture are described).
- `AGENTS.md` project layout: add `Services/Export/` (builder, service, formats, ZIP/XLSX writer)
  and a one-line "how to add an export format" note.

## Files

New:
```
Timelane/Services/Export/MonthExport.swift
Timelane/Services/Export/MonthExportBuilder.swift
Timelane/Services/Export/MonthExportService.swift
Timelane/Services/Export/MonthExportFileName.swift
Timelane/Services/Export/Formats/MonthExportFormat.swift
Timelane/Services/Export/Formats/ExportFormats.swift
Timelane/Services/Export/Formats/JSONMonthExportFormat.swift
Timelane/Services/Export/Formats/ExcelMonthExportFormat.swift
Timelane/Services/Export/Spreadsheet/SpreadsheetWorkbook.swift   (+ SpreadsheetCell if separate)
Timelane/Services/Export/Spreadsheet/XLSXWriter.swift            (split XML parts out if > 150 lines)
Timelane/Services/Export/Zip/ZipArchiveWriter.swift
Timelane/Services/Export/Zip/CRC32.swift
Timelane/Features/Projects/ViewModels/MonthExportViewModel.swift
Timelane/Features/Projects/ViewModels/ExportFile.swift
Timelane/Features/Projects/Views/ExportFormatSheet.swift
Timelane/Features/Projects/Views/ExportSavePanel.swift
TimelaneTests/MonthExportBuilderTests.swift
TimelaneTests/JSONMonthExportFormatTests.swift
TimelaneTests/ZipArchiveWriterTests.swift      (incl. CRC32)
TimelaneTests/XLSXWriterTests.swift            (incl. ExcelMonthExportFormat)
TimelaneTests/MonthExportViewModelTests.swift
TimelaneTests/Support/ZipTestReader.swift      (or inside TestSupport-style file; test-only stored-ZIP reader)
```
Changed: `ProjectRepository.swift`, `GRDBProjectRepository.swift`, `ProjectsScreen.swift`,
`Timelane.xcodeproj/project.pbxproj` (`ENABLE_USER_SELECTED_FILES = readwrite`, 2×),
`ProjectRepositoryTests.swift`, `README.md`, `plans/PLAN.md`, `AGENTS.md`.
The `Timelane/` and `TimelaneTests/` folders are synchronized groups: new files are picked up
automatically — don't hand-edit the pbxproj for them. Check how existing tests are organised
(flat folder) and follow that; put the test ZIP reader where the other test helpers live.

## Tests (Swift Testing, fixed calendar/time zone — e.g. `Europe/Amsterdam`, Gregorian)

- **Builder**: entries clipped at month start and end; entry fully outside dropped; totals per
  project = sum of clipped durations; archived project with hours included; project without hours
  excluded; sort order of projects and entries; unknown project id → "Unknown project"; empty
  title/note → nil; empty month → no projects, no entries, total 0.
- **File name**: `"Timelane 2026-10.json"`, `.xlsx`.
- **JSON**: decode the output with `JSONSerialization`; check `schemaVersion`, `month`, totals,
  hours rounding (e.g. 1 h 20 m → 1.33), ISO date with offset across a DST change (an entry on
  2026-10-24 has `+02:00`, on 2026-10-26 `+01:00`), `title: null` present.
- **CRC32**: known vector; empty data → 0.
- **ZIP**: read the archive back with the test-only reader (parse end-of-central-directory →
  central directory → local headers, stored entries only) and get the same paths and bytes back;
  deterministic (two runs → identical `Data`); UTF-8 file name.
- **XLSX**: unzip with the test reader; required parts exist; `[Content_Types].xml` lists the
  sheets; sheet XML contains the header texts and an escaped string (`A & B <c>` →
  `A &amp; B &lt;c&gt;`); column letters (`Z`, `AA`); Excel serial for 2026-10-03 09:00 local
  (= 46298.375); the Summary total row equals the export total in hours.
- **View model**: with an in-memory environment and seeded entries, `prepareFile` returns data
  for the selected format and the expected file name; the selected format is persisted to the
  injected UserDefaults suite and restored; unknown stored id falls back to the first format;
  `write(_:to:)` writes into a temp directory; an unwritable URL sets `errorMessage`.
- **Repository**: `projects(includeArchived:)` with and without archived projects.

## Order of work

1. Build setting `readwrite`; `projects(includeArchived:)` + test.
2. `MonthExport`, `MonthExportBuilder`, `MonthExportFileName` + tests.
3. `MonthExportFormat`, `ExportFormats`, JSON format + tests.
4. `CRC32`, `ZipArchiveWriter`, test ZIP reader + tests.
5. `SpreadsheetWorkbook`, `XLSXWriter`, Excel format + tests.
6. `MonthExportService`, `MonthExportViewModel`, `ExportFile` + tests.
7. `ExportFormatSheet`, `ExportSavePanel`, toolbar item in `ProjectsScreen`.
8. README / PLAN.md / AGENTS.md.
9. Full test run, build, relaunch the Debug app, commit.

## Definition of done

- `xcodebuild … test` passes (all existing + new tests).
- Debug app builds and is relaunched (`osascript -e 'quit app "Timelane"'`, build, `open …`);
  never pass `-resetDatabase`.
- Projects screen has *Export…* (⇧⌘E) → format sheet → save panel → file written.
- Written `.xlsx` opens in Numbers/Excel with two sheets; `.json` is valid and pretty-printed.
  (The agent can't open the UI — verify the generated bytes in tests, and optionally write a
  sample `.xlsx` from a test-free scratch script and run `unzip -t` / `plutil`-free checks on it.)
- No new dependencies; no `import GRDB` outside `Database/` and `Repositories/GRDB/`.
- Committed on `feature/month-export` with a message ending in the session's Co-Authored-By line.

### Manual check for the owner

1. Projects → pick a month with hours → *Export…* (or ⇧⌘E).
2. Choose *Excel (.xlsx)* → Export… → save to Desktop → open in Excel/Numbers: Summary + Entries
   sheets, hours summable, dates/times formatted.
3. Repeat with *JSON*; the next export pre-selects the last format.
4. Export an empty month: file is created with no rows, no error.
