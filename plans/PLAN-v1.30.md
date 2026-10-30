# PLAN v1.30 — iCloud backup (opt-in)

Branch `feature/icloud-backup` (from `main`). Delivered as a pull request, not pushed to `main` directly.

## Context

All Timelane data lives in one SQLite file inside the sandbox container
(`Application Support/Timelane/db.sqlite`). If the Mac breaks, the container is deleted or the file gets
corrupted, every project and logged hour is gone. The owner wants the data kept in iCloud so it cannot be
lost, as an **opt-in** setting (off by default) in a **subtle place** that is not always in view.

## Decisions

1. **Snapshot backup, not record-level sync.** A consistent copy of the whole database is uploaded to the
   user's *private* CloudKit database as one `CKAsset`. Restoring replaces the local database with that copy.
   - Why not live multi-device merge (`CKSyncEngine`)? All tables use auto-increment `Int64` ids and foreign
     keys between them; record-level sync needs stable UUIDs on every row, tombstones, change tracking and
     conflict rules. That is a large, risky change, and a bug there loses exactly the data this feature
     should protect. A snapshot is small, easy to test and fully covers "never lose my data". Record-level
     sync can be a later iteration on top of this (out of scope here).
   - Why CloudKit and not an iCloud Drive file? No file-coordination or "file not downloaded yet" states,
     no user-visible file the user can break, and the asset upload/download is one API call.
2. **Place in the UI: a standard macOS Settings window** (`Settings { }` scene → *Timelane ▸ Settings…*, ⌘,).
   It is the conventional, out-of-the-way place; nothing is added to the sidebar, timeline or menu bar panel.
3. **Off by default.** Nothing touches CloudKit until the user turns the toggle on.
4. **Never overwrite a good backup with an empty database automatically** (see §Safety).
5. **Restore finishes on relaunch.** The downloaded copy is validated and staged as a *pending restore* file;
   it is swapped in by `AppDatabase.live()` before the database is opened. No live connection, observation,
   tracker or auto-log state has to be patched while running.

## Design

### CloudKit layout

- Container: `iCloud.nl.nickkoepr.timelane`, **private** database, default zone.
- One record, record type `DatabaseBackup`, fixed record name `latest` (saved with `.allKeys` save policy,
  i.e. overwrite). Fields:
  - `database` — `CKAsset` (the snapshot file)
  - `createdAt` — `Date`
  - `deviceName` — `String` (`Host.current().localizedName ?? "Mac"`)
  - `appVersion` — `String` (`CFBundleShortVersionString` + build)
  - `schemaVersion` — `String` (identifier of the last applied migration, e.g. `"v3"`)
  - `projectCount`, `timeEntryCount` — `Int64` (so the safety rule can be evaluated without downloading)
- No subscriptions, no push, no queries (fetch by record ID only → no queryable indexes needed in the schema).

### Types (one per file, small)

`Timelane/Services/Backup/` (new folder; Foundation/CloudKit only, **no GRDB** except where noted):

| File | Role |
|---|---|
| `BackupInfo.swift` | `struct BackupInfo: Sendable, Equatable` — `createdAt`, `deviceName`, `appVersion`, `schemaVersion`, `projectCount`, `timeEntryCount`; `var hasData: Bool { projectCount > 0 \|\| timeEntryCount > 0 }`. |
| `CloudBackupStore.swift` | `protocol CloudBackupStore: Sendable` — `func accountStatus() async throws -> CloudAccountStatus` (`.available`, `.noAccount`, `.restricted`, `.temporarilyUnavailable`, `.couldNotDetermine`); `func latestBackup() async throws -> BackupInfo?`; `func upload(_ file: URL, info: BackupInfo) async throws`; `func download() async throws -> (file: URL, info: BackupInfo)?` (file in a temp directory owned by the caller). |
| `CloudKitBackupStore.swift` | Live implementation with `import CloudKit`. **Creates `CKContainer(identifier:)` lazily on first call** (a container without the entitlement crashes; tests and ad-hoc CI builds must never reach it). Maps `CKError.unknownItem` → `nil`, `CKAccountStatus` → `CloudAccountStatus`. Copies the downloaded asset's `fileURL` to a temp file before returning (the asset file is deleted by CloudKit later). |
| `InMemoryCloudBackupStore.swift` | Fake for tests/previews: configurable account status, stored file `Data` + info, optional error to throw, call counters. Lives in the app target (like `InMemoryRecordingTimerStore`) so previews can use it. |
| `BackupSettingsStore.swift` | `@MainActor protocol BackupSettingsStore: AnyObject` with `isEnabled: Bool`, `lastBackupAt: Date?`; `InMemoryBackupSettingsStore` and `UserDefaultsBackupSettingsStore` (keys `iCloudBackup.isEnabled`, `iCloudBackup.lastBackupAt`), same shape as `RecordingTimerStore`. |
| `BackupSchedule.swift` | **Pure**, unit-tested. `struct BackupSchedule` with `minimumInterval: TimeInterval = 15 * 60` and `func shouldBackUp(now: Date, isEnabled: Bool, isDirty: Bool, lastAttempt: Date?) -> Bool` (enabled && dirty && (lastAttempt == nil \|\| now - lastAttempt >= minimumInterval)). |
| `BackupSafety.swift` | **Pure**, unit-tested. `enum BackupSafety { static func mayReplace(remote: BackupInfo?, with local: BackupInfo, isAutomatic: Bool) -> Bool }` — false only when `isAutomatic && remote?.hasData == true && !local.hasData`. A manual "Back Up Now" / explicit replace is always allowed (the UI confirms). |
| `CloudBackupService.swift` | `@MainActor @Observable final class`. Dependencies via `init`: `BackupSnapshotter`, `CloudBackupStore`, `BackupSettingsStore`, `PendingRestore`, a `now: () -> Date` clock, `BackupSchedule`. State: `isEnabled`, `lastBackupAt`, `isWorking`, `lastError: String?`, `skippedBecauseEmpty: Bool`. Methods: `backUpNow(automatic: Bool) async`, `latestRemoteBackup() async throws -> BackupInfo?`, `accountStatus() async`, `prepareRestore() async throws` (download → validate → stage), `markDirty()`, `tick() async` (called by the run loop: asks `BackupSchedule`, then `backUpNow(automatic: true)`), `run() async` (loop: listens to database changes → `markDirty()`; every 60 s → `tick()`; treat the first tick after launch as dirty). Errors are stored in `lastError` and logged with `os.Logger` (category `"backup"`), never thrown at the UI from automatic runs. |

`Timelane/Database/` (GRDB allowed here):

| File | Role |
|---|---|
| `BackupSnapshotter.swift` | `struct BackupSnapshotter: Sendable` holding `AppDatabase`. `func makeSnapshot(in directory: URL) throws -> (file: URL, info: BackupInfo)` — `try database.writer.backup(to: DatabaseQueue(path: tmpFile))` (consistent online copy, works for the in-memory DB in tests), then reads counts and the last applied migration id (`Migrations.makeMigrator().appliedIdentifiers(db)` → last in registration order) for `BackupInfo`. `deviceName`/`appVersion` passed in so tests are deterministic. |
| `PendingRestore.swift` | `struct PendingRestore: Sendable` with a `directory: URL` (live: the `Application Support/Timelane` folder; tests: a temp dir). `func stage(_ downloaded: URL) throws` — validates then moves the file to `pending-restore.sqlite`. Validation: open with `DatabaseQueue(path:)`, `try migrator.hasBeenSuperseded(db)` → throw `BackupError.newerSchema` (backup from a newer app version); must contain the `project` and `timeEntry` tables, else `BackupError.notATimelaneDatabase`; non-SQLite file → `BackupError.notATimelaneDatabase`; then run `Migrations.makeMigrator().migrate(queue)` on the staged copy so an older backup is upgraded before swap. `var hasPendingRestore: Bool`. `func applyIfPending(databaseFile: URL) throws -> Bool` — if `pending-restore.sqlite` exists: move the current `db.sqlite` (+ `-wal`, `-shm` if present) to `db-before-restore.sqlite` (+ suffixes; replace an older one), move the pending file to `db.sqlite`, return true. |
| `AppDatabase+Changes.swift` | `func changes() -> AsyncStream<Void>` using `DatabaseRegionObservation(tracking: .fullDatabase)` on `writer` (same pattern as `stream`: cancel on termination). Keeps GRDB out of the service. |
| `BackupError.swift` (in `Services/Backup/`) | `enum BackupError: LocalizedError` — `.iCloudUnavailable(CloudAccountStatus)`, `.noBackup`, `.newerSchema`, `.notATimelaneDatabase`; user-facing `errorDescription` in English. |

`AppDatabase.live()`: before opening the queue, call `PendingRestore(directory:).applyIfPending(databaseFile:)` and log with `logger.notice` when a restore was applied. Keep the existing `#if DEBUG` reset logic first and unchanged.

### Wiring

- `AppEnvironment` gets `let backup: CloudBackupService`. New `init` parameters with in-memory defaults
  (`backupStore: any CloudBackupStore = InMemoryCloudBackupStore()`, `backupSettings: any BackupSettingsStore = InMemoryBackupSettingsStore()`,
  `pendingRestore: PendingRestore = <temp dir>`), so `.inMemory()`, `.preview()` and every existing test call keep compiling.
  `.live()` passes `CloudKitBackupStore()`, `UserDefaultsBackupSettingsStore()` and the live `PendingRestore`
  (expose the directory computation from `AppDatabase` as a static helper instead of duplicating the path).
  Keep `AppEnvironment.swift` small; put helpers in `AppEnvironment+Backup.swift` if it grows.
- `AppDelegate.applicationDidFinishLaunching`: after starting the tracker (still skipped when running tests), `Task { await AppEnvironment.shared.backup.run() }`. `run()` returns immediately-idle when disabled (it keeps listening so turning it on later works without a restart).
- **Relaunch after restore**: `AppRelauncher` (`Timelane/App/AppRelauncher.swift`, `@MainActor enum`) — `NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration:)` with `createsNewApplicationInstance = true`, then `NSApp.terminate(nil)` (the existing `applicationShouldTerminate` stops the tracker first). If opening fails, show "Restore is ready. Quit and reopen Timelane to finish." and terminate anyway only after the user confirms. Check that the new instance does not start before the old one has closed the database (the swap happens in `AppDatabase.live()` of the new process; if the old process is still alive the swap still works on the file system, but add a short wait: in the new instance, if `NSRunningApplication.runningApplications(withBundleIdentifier:)` contains another Timelane, wait up to ~3 s before opening the database. Keep this simple; document it in the code.)

### UI — Settings window

- `TimelaneApp`: add a `Settings { SettingsView().environment(environment) }` scene. macOS adds *Timelane ▸ Settings…* (⌘,) automatically. Do **not** add anything to the sidebar, timeline toolbar or menu bar panel.
- `Timelane/Features/Settings/` (new):
  - `ViewModels/BackupSettingsViewModel.swift` — `@MainActor @Observable`, depends on `CloudBackupService`. Exposes `isEnabled`, `statusText` (e.g. "Last backed up today at 14:32", "Not backed up yet", "Backing up…", "Skipped: this Mac has no data yet; your iCloud backup was kept."), `errorMessage`, `pendingChoice: ExistingBackupChoice?`, `isConfirmingRestore`. Intents:
    - `setEnabled(true)`: check account status (not available → `errorMessage = "Sign in to iCloud in System Settings to use iCloud backup."`, stay off). Fetch `latestBackup()`. None → enable + `backUpNow(automatic: false)`. One exists **with data** → set `pendingChoice` with its info and wait (the view shows a dialog). One exists without data → enable + back up.
    - `resolveChoice(.restore)` → enable + `prepareRestore()` + `AppRelauncher.relaunch()`; `.replace` → enable + `backUpNow(automatic: false)`; `.cancel` → stay off.
    - `setEnabled(false)` → turn off; the iCloud backup is **kept** (text in the view says so).
    - `backUpNow()`, `requestRestore()` (shows confirmation) / `confirmRestore()`.
    The view model must not import GRDB or CloudKit.
  - `Views/SettingsView.swift` — `TabView` with one tab for now: "Backup" (`Label("Backup", systemImage: "icloud")`), fixed width ~460. Leaves room for later settings.
  - `Views/BackupSettingsView.swift` — `Form` (`.formStyle(.grouped)`):
    - `Toggle("Back up to iCloud", isOn:)` with footnote: "Keeps a copy of your projects, logged hours and tracked apps in your private iCloud. Backups run automatically, at most every 15 minutes while data changes."
    - Status line (secondary text) + `ProgressView().controlSize(.small)` while working; error in red text.
    - Buttons (only when enabled): "Back Up Now", "Restore from iCloud…".
    - `.confirmationDialog` for `pendingChoice`: title "A backup already exists in iCloud", message "From <device>, <date>: <n> projects, <m> time entries.", buttons "Restore It" ("Replaces the data on this Mac"), "Replace with This Mac's Data" (`role: .destructive`), Cancel.
    - `.confirmationDialog` for restore: "Restore from iCloud?" / "The data on this Mac is replaced by the backup from <date>. Timelane restarts to finish. A copy of the current data is kept on this Mac.", "Restore and Restart" (`.destructive`).
    - `#Preview` with `AppEnvironment.preview()`.
  - Settings is a normal window (not the menu bar panel), so `.confirmationDialog`/alerts are fine there (the MenuBarExtra trap does not apply).

### Safety

- Automatic backups go through `BackupSafety.mayReplace(remote:with:isAutomatic: true)`; to evaluate it the service fetches `latestBackup()` before each automatic upload (one small record fetch). If refused: no upload, `skippedBecauseEmpty = true`, log a notice.
- Turning backup on with an existing non-empty backup always asks (see view model).
- Restore keeps `db-before-restore.sqlite` locally (the previous data is never deleted by a restore).
- Never upload while a pending restore is staged (`pendingRestore.hasPendingRestore` → skip).
- Temp files (snapshots, downloads) live in `FileManager.default.temporaryDirectory/TimelaneBackup/` and are removed after upload/staging (`defer`).

### Entitlements, signing, CI

- Add `Timelane/Timelane.entitlements` with **only** the iCloud keys (sandbox keys stay in the build settings `ENABLE_APP_SANDBOX` / `ENABLE_USER_SELECTED_FILES`):
  ```xml
  <key>com.apple.developer.icloud-container-identifiers</key>
  <array><string>iCloud.nl.nickkoepr.timelane</string></array>
  <key>com.apple.developer.icloud-services</key>
  <array><string>CloudKit</string></array>
  ```
  Set `CODE_SIGN_ENTITLEMENTS = Timelane/Timelane.entitlements` on the **app target**, Debug and Release.
  The folder is a synchronized group: make sure the `.entitlements` file is not added to *Copy Bundle Resources* (add it to the group's membership exceptions if Xcode would; verify the build has no "entitlements file in Copy Bundle Resources" warning).
- CI (`.github/workflows/tests.yml`) signs ad-hoc; an ad-hoc app with iCloud entitlements is killed at launch. Add `CODE_SIGN_ENTITLEMENTS=` (empty) to the `xcodebuild test` overrides with a comment. Tests never create a `CKContainer` (the hosted test environment uses the in-memory store), so nothing else changes.
- `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` stays correct: CloudKit uses Apple's own exempt encryption. Do not add the `com.apple.security.network.client` entitlement; CloudKit talks to the system `cloudd` daemon.
- **Owner's manual steps** (cannot be done by an agent; list them in the PR description):
  1. Xcode → Timelane target → *Signing & Capabilities*: confirm the iCloud capability shows CloudKit with container `iCloud.nl.nickkoepr.timelane` (create the container there if Xcode asks; this registers it on the App ID).
  2. Run the Debug app once with backup on so the `DatabaseBackup` record type is created in the CloudKit **Development** environment.
  3. Before a TestFlight/App Store build: CloudKit Console → *Deploy Schema Changes* to **Production**.

### Docs

- `README.md`: new section "iCloud backup" (what is stored, opt-in, where the setting is, automatic interval, restore behaviour, the local `db-before-restore.sqlite`). Change the privacy paragraph: nothing leaves the Mac **unless iCloud backup is turned on**; then the database goes only to the user's private iCloud.
- `plans/PLAN.md`: add a short v1.30 note (requirement + pointer to this file) and the Settings scene in §8.
- `AGENTS.md`: update "All data is local … No network" and the layout section (`Services/Backup/`, `Features/Settings/`), add a known trap: *never create `CKContainer` in tests or ad-hoc builds; CI strips the entitlements*.

## Tests (Swift Testing, `TimelaneTests/`)

- `BackupScheduleTests` — disabled / not dirty / first time / within interval / after interval.
- `BackupSafetyTests` — automatic + empty local + remote with data → false; manual → true; remote nil → true; remote empty → true; local with data → true.
- `BackupSnapshotterTests` — in-memory DB with 2 projects + 3 entries → snapshot file opens, has the same rows, info counts 2/3, `schemaVersion == "v3"` (or whatever the last migration is; derive it from the migrator, don't hard-code if possible).
- `PendingRestoreTests` (temp directories, cleaned up) — staging a valid snapshot creates `pending-restore.sqlite`; staging garbage throws `.notATimelaneDatabase`; a DB with an extra unknown migration identifier inserted into `grdb_migrations` throws `.newerSchema`; an older-schema DB (only `v1` applied — build it with a migrator that stops at v1, e.g. `migrate(_:upTo: "v1")`) is upgraded when staged; `applyIfPending` moves the old db to `db-before-restore.sqlite` and the pending one into place, and returns false when nothing is pending; after apply, `AppDatabase.file(at:)` opens it and the restored rows are there.
- `CloudBackupServiceTests` (with `InMemoryCloudBackupStore`, `InMemoryBackupSettingsStore`, fake clock):
  backUpNow uploads and sets `lastBackupAt`; automatic backup with empty local DB and a non-empty remote is skipped; `tick()` respects the schedule; store error → `lastError` set, `isWorking` false; `prepareRestore()` with no backup → `.noBackup`; with backup → pending restore staged; no upload while a restore is pending.
- `BackupSettingsViewModelTests` — account unavailable → stays off with message; no remote → enabled and uploaded; remote with data → `pendingChoice` set and nothing uploaded; `.replace` uploads; `.cancel` stays off; disabling keeps the remote backup (store not cleared). Inject the relaunch action as a closure (`relaunch: () -> Void`) so the test can assert it was called without quitting the test host.
- `BackupSettingsStoreTests` — UserDefaults store round-trip with a throw-away suite (`UserDefaults(suiteName: UUID().uuidString)`, remove the domain afterwards).

## Order of work

1. `BackupInfo`, `BackupError`, `BackupSchedule`, `BackupSafety` + tests.
2. `BackupSettingsStore` (+ tests), `CloudBackupStore` protocol + `InMemoryCloudBackupStore`.
3. `BackupSnapshotter`, `PendingRestore`, `AppDatabase+Changes`, `AppDatabase.live()` swap + tests.
4. `CloudBackupService` + tests; wire into `AppEnvironment` / `AppDelegate`.
5. `CloudKitBackupStore`, entitlements file + build setting, CI override.
6. Settings scene, view model (+ tests), views, `AppRelauncher`.
7. README / PLAN.md / AGENTS.md.
8. Run the full test suite with the CI overrides; then try a normally signed Debug build (see Definition of done).

## Definition of done

- All existing and new tests pass with the CI command line (ad-hoc signing + `CODE_SIGN_ENTITLEMENTS=`):
  `xcodebuild -project Timelane.xcodeproj -scheme Timelane -destination 'platform=macOS' -derivedDataPath build/DerivedData test CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER= CODE_SIGNING_REQUIRED=YES CODE_SIGNING_ALLOWED=YES CODE_SIGN_ENTITLEMENTS=`
- A normally signed build (`xcodebuild ... build -allowProvisioningUpdates`) is attempted; if it fails only because the iCloud capability/container is not yet registered for the team, report the exact error (this is owner step 1) — do not work around it by removing the entitlement.
- No new build warnings. No `import GRDB` outside `Database/` and `Repositories/GRDB/`; no `import CloudKit` outside `CloudKitBackupStore.swift`.
- Backup is off by default; with it off, no CloudKit API is called (the live store's container is never created).
- Files stay < 150 lines where possible (hard limit ~250); every new view has a `#Preview`.
- README, PLAN.md and AGENTS.md updated. Committed on `feature/icloud-backup`.

## Manual check for the owner

1. Open *Timelane ▸ Settings…* (⌘,) → Backup tab; toggle is off.
2. Turn it on → status shows "Backing up…" then "Last backed up …". In CloudKit Console (Development, private DB of your Apple ID) the `latest` record exists.
3. Add an entry, wait ≥ 15 min (or press "Back Up Now") → timestamp updates.
4. "Restore from iCloud…" → confirm → Timelane restarts with the backed-up data; `db-before-restore.sqlite` exists next to `db.sqlite`.
5. Turn it off → no further uploads; the iCloud record is still there.

## Deviations

- `BackupSettingsViewModel.pendingChoice` is the existing `BackupInfo?` (the dialog needs its data); the three answers are a separate `ExistingBackupChoice` enum used by `resolveChoice(_:)`. `requestRestore()` is async (it fetches the backup info for the dialog) and exposes `restoreCandidate`.
- `CloudBackupService.accountStatus()` returns the status; `setEnabled(_:)` is a synchronous method on the service (state is `private(set)`), and the run loop takes the change stream as an injected closure (`changes: () -> AsyncStream<Void>`), wired to `AppDatabase.changes()` in `AppEnvironment+Backup.swift`.
- The snapshot is made on a detached task so the main actor does not block on the file copy.
- The "wait for the old instance" step lives in `AppRelauncher.waitForOtherInstances()` and is called from `AppEnvironment.live()` (only when a restore is pending), so `AppDatabase` stays free of AppKit. `AppDatabase.liveDirectory()` exposes the folder.
- `InMemoryCloudBackupStore` uses a lock-protected state (`@unchecked Sendable` class) so tests can read its counters synchronously; `CloudKitBackupStore` is an actor (lazy `CKContainer`).
- The status line uses an abbreviated date + time ("Last backed up Oct 30, 2026 at 14:32") instead of "today at …".
- Added `TimelaneTests/BackupTestSupport.swift` (shared fixtures). A normally signed Debug build fails until the iCloud capability/provisioning is set up in Xcode (owner step 1): "No profiles for 'nl.nickkoepr.timelane' were found" and "Device ... isn't registered in your developer account".
