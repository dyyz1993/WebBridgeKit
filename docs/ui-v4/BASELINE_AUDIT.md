# UI v4 Baseline Audit

Date: 2026-06-02
Branch: `codex/ui-v4-refactor`

## Purpose

This audit captures the current UI and automation baseline before UI v4 implementation begins. It should be updated only when the baseline is intentionally refreshed.

## Current product problem

The core framework capabilities are clearer than the current app UI. The app currently mixes demo surfaces, settings pages, cache debugging, message/inbox screens, showcase screens, and development panels. This makes user paths hard to verify and makes UI regressions easy to miss.

The UI v4 direction is to rebuild the product shell around the real capabilities:

- Web cache: online, cache-first, full offline package, cleanup, cache stats
- JSBridge: handler catalog, command execution, parameters, results, errors
- Token/Push: token/passphrase/API key, device token, payload composer, push route
- Debug Center: logs, network, cache, crash, environment, diagnostics export
- Deep Link: URL templates, parameter editor, execution, history

## Baseline command results

| Check | Result | Evidence |
|---|---|---|
| Services | PASS | `bash scripts/services.sh start && bash scripts/services.sh verify` reported 3/3 healthy |
| SwiftLint | WARN | `swiftlint --quiet` produced 15 style warnings |
| CI design lint | PASS | `bash tools/ci-lint.sh` reported 16 PASS, 0 FAIL; comprehensive design lint still reports 5 warnings |
| Visual static checks | WARN | `bash tools/visual-checks.sh` reported 6 PASS, 4 WARN, 0 FAIL |
| Crash scan | PASS | `bash scripts/scan-crash-logs.sh --json` returned `{"diagnostic_reports": 0, "app_crash_logs": 0, "total": 0}` |
| Screenshot capture | BLOCKED | `bash tools/capture-screenshots.sh` failed because no booted simulator exists; two simulator boot attempts also failed/hung |
| UI v4 regression entrypoint | FAIL | `bash tools/run-ui-v4-regression.sh` generated reports with 5 PASS, 2 FAIL because no simulator is booted |

## SwiftLint warnings

Current warning count: 15.

| File | Issue |
|---|---|
| `Sources/Handlers/ManifestLoader/ManifestDownloadService.swift:83` | unused closure parameter |
| `SuperApp/Sources/Views/CacheDashboardView.swift:33` | multiple closure trailing closure syntax |
| `SuperApp/Sources/Views/CacheDashboardView.swift:70` | multiple closure trailing closure syntax |
| `SuperApp/Sources/Views/CacheDashboardView.swift:104` | multiple closure trailing closure syntax |
| `SuperApp/Sources/Views/CacheDashboardView.swift:214` | multiple closure trailing closure syntax |
| `SuperApp/Sources/Views/SettingsView.swift:111` | multiple closure trailing closure syntax |
| `SuperApp/Sources/Views/SettingsRow.swift:9` | implicit optional initialization |
| `SuperApp/Sources/Views/SettingsRow.swift:14` | implicit optional initialization |
| `SuperApp/Sources/Views/SettingsRow.swift:15` | implicit optional initialization |
| `SuperApp/Sources/Views/SwiftUIHelpers.swift:40` | statement position |
| `SuperApp/Sources/Views/SwiftUIHelpers.swift:41` | statement position |
| `SuperApp/Sources/Views/SwiftUIHelpers.swift:42` | statement position |
| `SuperApp/Sources/Views/SwiftUIHelpers.swift:43` | statement position |
| `SuperApp/Sources/Views/SwiftUIHelpers.swift:44` | statement position |
| `SuperApp/Sources/Views/SwiftUIHelpers.swift:45` | statement position |

## CI design lint status

Previous failure:

```text
Sources/Handlers/ManifestLoader/ManifestProgressUI.swift:24
NSLog("[WEB] [ProgressUI] ...")
```

Reason:

- `tools/ci-lint.sh` blocks UI emoji in Swift code.
- The blocking emoji was removed from the log message.
- `tools/ci-lint.sh` now passes.
- The comprehensive design lint still reports 5 warnings for hardcoded fonts and deprecated ThemeBadge usage. These are warnings, not current blockers.

## Visual static warnings

`tools/visual-checks.sh` currently reports warnings for:

- `WBKListRow` height check expects literal values while implementation uses token references.
- `WBKFilterPill` check sees an internal 14 pt icon size and warns about height.
- `WBKFilterPill` intrinsic content size may not match 32 pt.
- `WBKEmptyState` action button height check may not detect the current implementation.

These may be false positives. UI v4 should either update the checks to understand tokenized values or fix the component implementation if screenshots prove a real layout issue.

## UI v4 regression entrypoint baseline

The new `tools/run-ui-v4-regression.sh` entrypoint runs and emits:

- `build/reports/ui-v4-regression.json`
- `build/reports/ui-v4-regression.md`

Current summary after removing the blocking UI emoji:

| Gate | Result |
|---|---|
| Services start and verify | PASS |
| SwiftLint | PASS |
| Design lint | PASS |
| Visual static checks | PASS |
| Crash scan | PASS |
| Screenshot capture | FAIL, no booted simulator |
| Visual regression | FAIL, skipped because no booted simulator |

## Current screen inventory

| Area | Current paths | Baseline decision |
|---|---|---|
| Generic tab shell | `SuperApp/Sources/Controllers/Tab/` | Migrate to UI v4 shell, keep temporarily until parity |
| Home/Main | `SuperApp/Sources/Controllers/Tab/MainViewController*.swift` | Migrate or delete after Web/Bridge/Token flows cover it |
| Inbox/Message | `SuperApp/Sources/Controllers/Tab/InboxViewController*.swift`, `SuperApp/Sources/Controllers/Message/` | Quarantine unless still required by push/message demos |
| Discover/Favorites | `SuperApp/Sources/Controllers/Tab/DiscoverViewController*.swift`, `FavoriteViewController.swift` | Fold useful URL/history behavior into Web tab |
| Settings | `SuperApp/Sources/Controllers/Tab/SettingsViewController.swift`, `SuperApp/Sources/Views/SettingsView.swift` | Split across Token/Push, Debug, Links, About |
| Cache | `SuperApp/Sources/Controllers/Cache/`, `SuperApp/Sources/Views/CacheDashboardView.swift` | Migrate into Web tab with SwiftUI adapter |
| JSBridge showcase | `SuperApp/Sources/Controllers/Showcase/BridgeShowcaseViewController.swift` | Replace with Bridge Lab |
| Debug | `SuperApp/Sources/Controllers/Debug/` | Consolidate into Debug Center |
| Token/API key/passphrase | `SuperApp/Sources/Controllers/Settings/*Token*`, `*APIKey*`, managers under `SuperApp/Sources/Managers/` | Consolidate into Token/Push |
| WebView | `Sources/Controllers/WebViewController*.swift`, `Sources/Controllers/WebBrowserViewController*.swift` | Keep UIKit/WKWebView controller behavior, wrap if needed |

## Keep/wrap/migrate/delete decisions

| Decision | Paths |
|---|---|
| Keep | `Sources/Cache/`, `Sources/Core/WebJavaScriptBridge.swift`, `Resources/WebBridge.js`, `Sources/Handlers/`, `Sources/CommandParser/`, `SuperApp/Sources/Push/` |
| Wrap | `Sources/Controllers/WebViewController*.swift`, `Sources/Controllers/WebBrowserViewController*.swift`, `SuperApp/Sources/Controllers/Debug/*` |
| Migrate | `SuperApp/Sources/Controllers/Cache/`, `SuperApp/Sources/Views/CacheDashboardView.swift`, `SuperApp/Sources/Views/SettingsView.swift` |
| Quarantine | `SuperApp/Sources/Controllers/Showcase/`, old generic tab controllers after parity |
| Delete later | Legacy tab screens and old cells only after UI v4 parity and release gate pass |

## Missing baseline evidence

Screenshots were not captured because no simulator is currently booted.

Attempts:

- `iPhone 16 Pro UI Test` on iOS 18.3 failed with `launchd_sim` startup/bind error.
- `iPhone 16 Pro 26.5` did not complete `simctl bootstatus` in a reasonable time and was stopped.

Required refresh command after booting a simulator:

```bash
xcrun simctl boot "iPhone 16 Pro"
bash tools/capture-screenshots.sh --build
```

Then copy or move the resulting screenshots into:

```text
docs/screenshots/ui-v4/baseline/
```

## Baseline risks

| Risk | Severity | Why it matters |
|---|---|---|
| UI shell does not match product modules | High | Users cannot discover or validate framework capabilities cleanly |
| UI tests are spread across old generic tabs | High | Regressions can pass while real module flows are broken |
| Screenshot capture depends on booted simulator | Medium | Agents may report UI complete without visual evidence |
| Screenshot capture requires a booted simulator | Medium | Visual evidence cannot be generated until simulator is available |
| Legacy UIKit and new SwiftUI coexist without shell contract | Medium | Layout and state behavior can drift |

## Recommended next action

Start Task 0.2 and Task 1 only after this audit is committed:

1. Finish regression script entrypoints.
2. Boot simulator and capture baseline screenshots.
3. Implement the UI v4 App Shell with placeholder module pages.
