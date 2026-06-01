# UI v4 Agent Task List

This document is intended for agent execution. Each task has scope, paths, acceptance criteria, and required evidence.

## Execution rules

1. Do tasks in order unless a later task is explicitly unblocked.
2. Do not redesign core framework behavior while working on UI.
3. Use existing design tokens, Lucide icons, and existing managers/handlers.
4. Every task must update or add tests.
5. Every task handoff must include changed paths, commands run, screenshots/reports, and known gaps.
6. If a task cannot be automated, mark it manual-only with reason and evidence.

## Task 0: Baseline audit

Priority: P0

Scope:

- Capture current state before UI v4 implementation.
- Identify existing UI files to migrate, wrap, or delete.

Read paths:

- `SuperApp/Sources/Controllers/Tab/`
- `SuperApp/Sources/Controllers/Cache/`
- `SuperApp/Sources/Controllers/Settings/`
- `SuperApp/Sources/Controllers/Debug/`
- `SuperApp/Sources/Views/`
- `SuperAppUITests/`
- `tools/ci-lint.sh`
- `tools/visual-checks.sh`
- `docs/design-tokens.json`

Deliverables:

- `docs/ui-v4/BASELINE_AUDIT.md`
- Current screenshot set under `docs/screenshots/ui-v4/baseline/`

Acceptance:

- Lists every current primary screen.
- Marks each screen as keep, wrap, migrate, or delete.
- Records current failing UI/style/test issues.
- Includes iPhone SE and iPhone 16 Pro screenshots.

Required commands:

```bash
bash scripts/services.sh verify
bash tools/ci-lint.sh
bash tools/capture-screenshots.sh
bash scripts/scan-crash-logs.sh --json
```

## Task 1: App shell

Priority: P0

Scope:

- Create the 5-tab SwiftUI shell.
- Do not remove old tabs until parity is verified.

Create paths:

- `SuperApp/Sources/Views/AppShell/AppShellView.swift`
- `SuperApp/Sources/Views/AppShell/AppTab.swift`
- `SuperApp/Sources/Views/AppShell/AppShellViewModel.swift`
- `SuperApp/Sources/Views/AppShell/ModuleHeaderView.swift`
- `SuperApp/Sources/Views/AppShell/ServiceStatusStrip.swift`

Modify paths:

- `SuperApp/Sources/Controllers/Tab/TabBarController.swift` or app entry point used by current project
- `project.yml` if new files are not auto-included

Acceptance:

- Five tabs exist: Web, Bridge, Token/Push, Debug, Links.
- Each tab has Lucide icon and accessibility ID.
- Tab content does not overlap tab bar on iPhone SE.
- Global service status strip renders without blocking actions.
- Old screens remain reachable through a temporary Legacy entry if needed.

Tests:

- Add `SuperAppUITests/AppShellTests.swift`.

Required evidence:

- Light/Dark screenshots of shell.
- `AppShellTests` pass.

## Task 2: Shared SwiftUI components

Priority: P0

Scope:

- Create reusable components that prevent layout drift.

Create or reuse paths:

- `SuperApp/Sources/Views/Components/StatusBadge.swift`
- `SuperApp/Sources/Views/Components/MetricTile.swift`
- `SuperApp/Sources/Views/Components/ActionRow.swift`
- `SuperApp/Sources/Views/Components/CodeBlockView.swift`
- `SuperApp/Sources/Views/Components/ResultPanel.swift`
- `SuperApp/Sources/Views/Components/EmptyStatePanel.swift`
- `SuperApp/Sources/Views/Components/ConfirmDangerSheet.swift`

Acceptance:

- Components use `ThemeTokens`.
- Components use Lucide icons only.
- Components support Light/Dark mode.
- Components have fixed layout contracts where needed.
- Components expose stable accessibility IDs.
- No nested cards.

Tests:

- Add or extend `SuperAppUITests/ComponentCatalogTests.swift`.
- Add visual screenshots for all shared components.

Required commands:

```bash
bash tools/ci-lint.sh
xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme SuperApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath /tmp/wbk-dd -only-testing:SuperAppUITests/ComponentCatalogTests
```

## Task 3: Web Cache module

Priority: P0

Scope:

- Build the new Web tab around cache/offline flows.

Create paths:

- `SuperApp/Sources/Views/WebCache/WebCacheHomeView.swift`
- `SuperApp/Sources/Views/WebCache/WebCacheHomeViewModel.swift`
- `SuperApp/Sources/Views/WebCache/WebCacheModePicker.swift`
- `SuperApp/Sources/Views/WebCache/WebCacheStatusPanel.swift`
- `SuperApp/Sources/Views/WebCache/WebCacheCleanupSheet.swift`
- `SuperAppUITests/CacheFlowTests.swift`

Use paths:

- `SuperApp/Sources/ViewModels/CacheDashboardViewModel.swift`
- `Sources/Cache/`
- `Sources/Handlers/CacheDebug/`
- `Sources/Handlers/ManifestLoader/`
- `Sources/Controllers/WebViewController+CacheDebug.swift`

Acceptance:

- User can open URL online.
- User can reopen from cache.
- User can see full offline package status.
- User can clear selected cache.
- User can clear all cache with confirmation.
- User can see manifest/resource failure reasons.
- Cache stats update after open and clear.
- UI has empty/loading/success/offline/error states.

Tests:

- `C-001` through `C-015` from `AUTOMATION_MATRIX.md`.

Required commands:

```bash
bash scripts/services.sh verify
bash tools/run-cache-regression.sh
bash scripts/scan-crash-logs.sh --json
```

## Task 4: JSBridge Lab module

Priority: P0

Scope:

- Build a proper JSBridge command lab.

Create paths:

- `SuperApp/Sources/Views/BridgeLab/BridgeLabHomeView.swift`
- `SuperApp/Sources/Views/BridgeLab/BridgeLabViewModel.swift`
- `SuperApp/Sources/Views/BridgeLab/BridgeCommandCatalogView.swift`
- `SuperApp/Sources/Views/BridgeLab/BridgeCommandFormView.swift`
- `SuperApp/Sources/Views/BridgeLab/BridgeResultPanel.swift`
- `SuperAppUITests/JSBridgeLabTests.swift`

Use paths:

- `Sources/Core/WebJavaScriptBridge.swift`
- `Resources/WebBridge.js`
- `Sources/Handlers/`
- `Sources/Bridge/Error/BridgeError.swift`
- `test_resources/js_bridge_test.html`

Acceptance:

- Handler groups are visible.
- Commands are searchable or grouped.
- Parameter editor validates required inputs.
- Execute shows running, success, timeout, and error states.
- Result JSON is copyable.
- Failed command appears in Debug logs.

Tests:

- `B-001` through `B-012` from `AUTOMATION_MATRIX.md`.

Required commands:

```bash
bash tools/run-jsbridge-regression.sh
bash scripts/scan-crash-logs.sh --json
```

## Task 5: Token/Push module

Priority: P1

Scope:

- Combine token, passphrase, API key, device token, and push test flows into one module.

Create paths:

- `SuperApp/Sources/Views/TokenPush/TokenPushHomeView.swift`
- `SuperApp/Sources/Views/TokenPush/TokenPushViewModel.swift`
- `SuperApp/Sources/Views/TokenPush/TokenListView.swift`
- `SuperApp/Sources/Views/TokenPush/PassphraseListView.swift`
- `SuperApp/Sources/Views/TokenPush/PushPayloadComposerView.swift`
- `SuperAppUITests/TokenPushTests.swift`

Use paths:

- `SuperApp/Sources/Managers/TokenManager.swift`
- `SuperApp/Sources/Managers/PassphraseManager.swift`
- `SuperApp/Sources/Managers/APIKeyManager.swift`
- `SuperApp/Sources/Managers/AccessTokenManager.swift`
- `SuperApp/Sources/Push/`
- `Server/Sources/WebBridgeServer/Routes/PushRoutes.swift`

Acceptance:

- Tokens and passphrases are redacted by default.
- Reveal requires explicit action.
- Copy/export never leaks raw secrets unless user explicitly reveals.
- Push payload composer validates JSON.
- Local push route is testable.
- Server push unavailable state is clear.
- APNs real delivery is marked manual/device-only.

Tests:

- `T-001` through `T-009`.
- `P-001` through `P-008`.

## Task 6: Debug Center module

Priority: P1

Scope:

- Replace scattered debug panels with one organized Debug Center.

Create paths:

- `SuperApp/Sources/Views/DebugCenter/DebugCenterHomeView.swift`
- `SuperApp/Sources/Views/DebugCenter/DebugCenterViewModel.swift`
- `SuperApp/Sources/Views/DebugCenter/DebugLogListView.swift`
- `SuperApp/Sources/Views/DebugCenter/DebugNetworkView.swift`
- `SuperApp/Sources/Views/DebugCenter/DebugCrashView.swift`
- `SuperApp/Sources/Views/DebugCenter/DebugExportView.swift`
- `SuperAppUITests/DebugCenterFlowTests.swift`

Use paths:

- `SuperApp/Sources/Controllers/Debug/`
- `Sources/Infrastructure/Debug/`
- `scripts/scan-crash-logs.sh`

Acceptance:

- Logs, Network, Cache, Crash, Environment, Export are reachable.
- Logs support filter/search/copy.
- Crash zero/non-zero states are visible.
- Export redacts secrets.
- Debug UI is available in development builds and safely hidden/controlled for Release if required.

Tests:

- `D-001` through `D-010`.

## Task 7: Deep Link module

Priority: P1

Scope:

- Build an interactive deep-link and command URL tester.

Create paths:

- `SuperApp/Sources/Views/DeepLink/DeepLinkHomeView.swift`
- `SuperApp/Sources/Views/DeepLink/DeepLinkViewModel.swift`
- `SuperApp/Sources/Views/DeepLink/DeepLinkTemplateListView.swift`
- `SuperApp/Sources/Views/DeepLink/DeepLinkParameterEditor.swift`
- `SuperApp/Sources/Views/DeepLink/DeepLinkHistoryView.swift`
- `SuperAppUITests/DeepLinkFlowTests.swift`

Use paths:

- `SuperApp/Sources/AppDelegate.swift`
- `SuperApp/Sources/Managers/CommandHandler.swift`
- `Sources/CommandParser/`
- `Server/Sources/WebBridgeServer/Routes/CommandRoutes.swift`

Acceptance:

- User can generate a valid URL from templates.
- User can execute and verify target page.
- Missing required params show inline errors.
- Unsupported command/path produces structured error.
- History stores last executions.

Tests:

- `L-001` through `L-008`.

## Task 8: UI v4 automation scripts

Priority: P0

Scope:

- Add one-command regression scripts.

Create paths:

- `tools/run-ui-v4-regression.sh`
- `tools/run-cache-regression.sh`
- `tools/run-jsbridge-regression.sh`
- `tools/run-release-gate.sh`
- `tools/run-real-device-smoke.sh`

Acceptance:

- Scripts use `set -euo pipefail`.
- Scripts print clear pass/fail summary.
- Scripts emit JSON and Markdown reports under `build/reports/`.
- Scripts return non-zero on failure.
- Scripts do not require interactive input.

Required smoke:

```bash
bash tools/run-ui-v4-regression.sh
bash tools/run-release-gate.sh
```

## Task 9: Screenshot and visual regression baseline

Priority: P1

Scope:

- Create deterministic screenshot capture for UI v4.

Modify paths:

- `SuperAppUITests/ScreenshotCaptureTests.swift`
- `tools/capture-screenshots.sh`
- `tools/run-visual-regression.sh`
- `tools/visual-checks.sh`

Create paths:

- `docs/screenshots/ui-v4/baseline/`
- `docs/screenshots/ui-v4/current/`
- `docs/screenshots/ui-v4/diff/`

Acceptance:

- Captures Light/Dark for all 5 tabs.
- Captures iPhone SE and iPhone 16 Pro.
- Captures at least one success and one error state for Web and Bridge.
- Visual report lists changed files and threshold.

## Task 10: Release hardening

Priority: P0 before release

Scope:

- Make UI v4 release-safe.

Read/modify paths:

- `project.yml`
- `.github/workflows/ci.yml`
- `docs/RELEASE_CHECKLIST.md`
- `docs/APP_SIZE_BUDGET.md`
- `tools/run-release-gate.sh`

Acceptance:

- Release build succeeds.
- Business warnings equal 0.
- Test HTML is not packaged into Release.
- Debug-only screens are gated appropriately.
- App size budget updated.
- CI runs the release gate or equivalent checks.

## Task 11: Delete or quarantine legacy UI

Priority: P2 after parity

Scope:

- Remove old generic tabs only after UI v4 has parity.

Candidate paths:

- `SuperApp/Sources/Controllers/Tab/MainViewController.swift`
- `SuperApp/Sources/Controllers/Tab/InboxViewController.swift`
- `SuperApp/Sources/Controllers/Tab/DiscoverViewController.swift`
- `SuperApp/Sources/Controllers/Tab/SettingsViewController.swift`
- Related old cells under `SuperApp/Sources/Views/Cells/`

Acceptance:

- No broken references.
- Old user paths either migrated or documented as intentionally removed.
- Tests no longer depend on deleted UI.
- Release build succeeds.

## Suggested milestone order

| Milestone | Tasks | Merge condition |
|---|---|---|
| M0 Audit | Task 0 | Baseline documented |
| M1 Shell | Tasks 1, 2, 8 partial | App shell + shared components pass UI tests |
| M2 Core flows | Tasks 3, 4 | Cache and JSBridge automated |
| M3 Support flows | Tasks 5, 6, 7 | Token/Push, Debug, Deep Link automated |
| M4 Visual gate | Task 9 | Screenshot and visual regression stable |
| M5 Release | Task 10 | Release gate green |
| M6 Cleanup | Task 11 | Legacy UI removed/quarantined |

## Final handoff template

Agents must finish with this structure:

```markdown
## Scope

- Task:
- Changed paths:

## Verification

| Command | Result |
|---|---|
| bash scripts/services.sh verify | PASS/FAIL |
| bash tools/ci-lint.sh | PASS/FAIL |
| xcodebuild ... | PASS/FAIL |
| bash scripts/scan-crash-logs.sh --json | PASS/FAIL |

## Screenshots

- Light:
- Dark:
- iPhone SE:

## Known gaps

- None / list with reason
```
