# Timelane v1.12 — Run the unit tests on every pull request (GitHub Actions)

Context: Timelane is a native macOS app (repo folder `/Users/nickk/iosProjects/TimeTracker`, project `Timelane.xcodeproj`, scheme `Timelane`, tests in `TimelaneTests/`, Swift Testing, ~170 tests, ~3 s locally). Remote: github.com/NickKoepr/Timelane (**private** repo). The only dependency is GRDB via Swift Package Manager (`Timelane.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`). Deployment target macOS 26.0, built locally with Xcode 27.1.

User request: when a pull request is opened, GitHub must run the tests.

Exception to the usual workflow: this change goes through a **pull request** on a branch (`ci/pr-tests`), not directly on `main`. Implementers commit on the branch; the main session pushes and opens the PR — **do not push**.

---

## 1. Behaviour

- Workflow `.github/workflows/tests.yml`, name `Tests`, one job `test` (display name "Unit tests").
- Triggers:
  - `pull_request` with types `opened`, `synchronize`, `reopened`, `ready_for_review` targeting `main` — so new commits on an open PR are tested too.
  - `workflow_dispatch` (manual run from the Actions tab).
- Skip runs when a PR only touches docs: `paths-ignore` for `**/*.md`, `plans/**`, `docs/**`. (Note: a required status check would then stay "pending" on docs-only PRs; no branch protection is configured, so this is fine — mention it in the README section.)
- `concurrency: group: tests-${{ github.event.pull_request.number || github.ref }}`, `cancel-in-progress: true` — a new push cancels the outdated run (macOS minutes are expensive on a private repo: 10× multiplier).
- `permissions: contents: read`.
- `timeout-minutes: 30`.
- Draft PRs: still run (keep it simple; no `if:` on draft).

## 2. Runner and Xcode

- `runs-on: macos-26` (the macOS 26 GitHub-hosted image; the app needs the macOS 26 SDK + Xcode 27). Verify the label exists in GitHub's runner-images documentation (github.com/actions/runner-images README, "Available Images"). If `macos-26` is not available, use the newest available macOS label that ships an Xcode able to build for macOS 26.0 and document the choice in this plan's "Notes" section.
- Select Xcode with a plain shell step (no third-party action): pick the newest `/Applications/Xcode_27*.app` (fall back to `/Applications/Xcode.app`), `sudo xcode-select -s` it, then print `xcodebuild -version` and `swift --version` for the log. Fail with a clear message if no Xcode 27 is found.
- Allowed actions: only first-party `actions/checkout@v4`, `actions/cache@v4`, `actions/upload-artifact@v4`. No other third-party actions.

## 3. Build + test command

The project uses automatic signing with the owner's team (`DEVELOPMENT_TEAM = R5Q4D5KC5S`), which doesn't exist on the runner. Tests are *hosted* (the test bundle runs inside `Timelane.app`, `TEST_HOST`), and the app is sandboxed, so the app must still be signed — use **ad-hoc signing** via build-setting overrides on the command line; do **not** change the Xcode project:

```sh
xcodebuild test \
  -project Timelane.xcodeproj \
  -scheme Timelane \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  -resultBundlePath build/TestResults.xcresult \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM= \
  PROVISIONING_PROFILE_SPECIFIER= \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGNING_ALLOWED=YES
```

- **Verify this command locally first** (in the worktree) — it must build and pass all tests without using the owner's certificate. If ad-hoc signing fails for the hosted tests, try `CODE_SIGNING_ALLOWED=NO` and record what worked/failed under "Notes". The command in the workflow must be one that passed locally.
- Pipe through nothing fancy (no `xcpretty`/`xcbeautify` — not installed by default, and no new tools). Keep raw output; use `set -o pipefail` only if piping.
- Optionally run `-resolvePackageDependencies` as a separate step first so dependency failures are easy to spot in the log.

## 4. Caching

- Cache SwiftPM checkouts with `actions/cache@v4`: path `build/DerivedData/SourcePackages`, key `spm-${{ runner.os }}-${{ hashFiles('Timelane.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved') }}`, restore-key `spm-${{ runner.os }}-`. Don't cache the whole DerivedData (stale-build risk, large).

## 5. Test results

- On failure (`if: failure()`), upload `build/TestResults.xcresult` with `actions/upload-artifact@v4` (name `TestResults`, `retention-days: 7`), so failures can be inspected in Xcode.
- Keep the job's own log readable: the raw xcodebuild output already lists failing tests.

## 6. Robustness checks (tests on a fresh CI machine)

Before finishing, review the test suite for things that might pass locally but fail on a clean runner, and fix them in the tests (not by weakening assertions):
- Dependence on the machine's **time zone / locale / calendar** (runner is UTC, `en_US`). Run locally with `TZ=UTC` (e.g. `TZ=UTC xcodebuild test ...`) and, if feasible, another zone such as `TZ=Pacific/Auckland`, to catch issues around midnight/DST. Tests should inject a fixed `Calendar`/`TimeZone` where they compute days.
- Use of `UserDefaults.standard` or the real database/sandbox container (AGENTS.md: shared state must be injected with throw-away suites / in-memory stores).
- Real wall-clock timing / sleeps that could be flaky on a slower machine.
- Dependence on installed apps (e.g. `AppCandidates`, `RunningApps`, `NSWorkspace`) — the runner has a different set of apps.
If nothing needs fixing, say so in "Notes".

## 7. Documentation

- `README.md`: add a short "Continuous integration" section (or a line in the development section): every PR to `main` runs the unit tests on GitHub Actions (`.github/workflows/tests.yml`, macOS runner, ad-hoc signing); docs-only changes are skipped; how to run it manually (Actions tab → Tests → Run workflow). Optionally a status badge: `![Tests](https://github.com/NickKoepr/Timelane/actions/workflows/tests.yml/badge.svg)` (works for private repos only when signed in — fine).
- `AGENTS.md`: under "Build, test, run" add one line that CI runs the same tests on every PR via `.github/workflows/tests.yml` with ad-hoc signing overrides; if a test needs the owner's signing identity or local state, it will fail in CI.
- `plans/PLAN.md`: add a one-line mention under the conventions/workflow section if there is a natural place.

## 8. Files

- New: `.github/workflows/tests.yml`
- Changed: `README.md`, `AGENTS.md`, possibly `plans/PLAN.md`, possibly test files (only for §6 fixes)
- This plan: `plans/PLAN-v1.12.md`

## 9. Order of work

1. Create branch `ci/pr-tests` from `main`.
2. Run the §3 command locally; adjust overrides until it passes; also run with `TZ=UTC`.
3. Review tests per §6; fix if needed; re-run.
4. Write `.github/workflows/tests.yml`. Validate the YAML syntax (e.g. `ruby -ryaml -e 'YAML.load_file(".github/workflows/tests.yml")'` or `python3 -c 'import yaml'` if available; `plutil` can't do YAML). If `actionlint` happens to be installed, run it; don't install anything.
5. Update docs (§7) and fill in "Notes" below.
6. Run the full test suite once more with the normal AGENTS.md command (with the owner's signing) to make sure nothing regressed.
7. Commit on `ci/pr-tests` (English message, ends with the session's Co-Authored-By line). Do **not** push.

## 10. Definition of done

- `.github/workflows/tests.yml` exists and matches §1–§5.
- The exact xcodebuild command used in the workflow passed locally with ad-hoc signing and with `TZ=UTC`.
- Docs updated; all tests pass; one commit on `ci/pr-tests`, not pushed.
- After the main session pushes and opens the PR, the `Tests` workflow runs on that PR and passes (verified by the main session).

## Notes

- Runner: `macos-26` (arm64) exists but only ships Xcode 26.0.1 to 26.6 (per the runner-images macos-26-arm64 readme). The project file uses `objectVersion = 90` (Xcode 27 format) and AGENTS.md says it is built with Xcode 27, so the workflow uses the `xcode-27` image label instead (runner image with Xcode 27 beta, marked preview in runner-images, issue #14404; Xcode at `/Applications/Xcode_27_beta_3.app` with `Xcode_27.0.app` / `Xcode.app` symlinks). Uncertain: the preview image may be unstable and its beta Xcode differs from the local 27.1; not verifiable locally. Switch to `macos-26` once that image ships Xcode 27.
- Signing: the ad-hoc overrides from section 3 (`CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER= CODE_SIGNING_REQUIRED=YES CODE_SIGNING_ALLOWED=YES`) worked first time locally (Xcode 27.1): 172 tests in 45 suites passed. `CODE_SIGNING_ALLOWED=NO` was not needed.
- TZ runs: `TZ=UTC` and `TZ=Pacific/Auckland` both pass (172 tests).
- Test review (section 6): no fixes needed. Tests use a fixed `TestCalendar`, in-memory databases and throw-away `UserDefaults` suites; no use of `UserDefaults.standard`, `NSWorkspace`, `Calendar.current` or `TimeZone.current`. Waits are early-exit polling loops (1 to 3 s caps), not fixed sleeps.
- actionlint is not installed; YAML syntax validated with Ruby `YAML.load_file`.
