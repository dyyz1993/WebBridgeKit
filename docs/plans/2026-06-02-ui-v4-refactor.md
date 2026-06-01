# UI v4 Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rebuild the SuperApp UI around WebBridgeKit's real framework capabilities while adding automated gates that prevent layout, style, and interaction regressions.

**Architecture:** Keep WebBridgeKit core modules stable and rebuild the application shell and feature pages with SwiftUI wrappers/adapters. UIKit/WKWebView controllers stay where they own complex web behavior; new product-facing screens live under `SuperApp/Sources/Views/`.

**Tech Stack:** SwiftUI, UIKit, WKWebView, XCUITest, SwiftLint, WebBridgeKit design tokens, Lucide icons, existing shell scripts.

---

## Operating rules

1. Start every implementation session with `bash scripts/services.sh start`.
2. Work in small commits; do not combine unrelated modules.
3. Write or update tests before marking any UI task complete.
4. Use `ThemeTokens.Color.*`, Lucide icons, and existing component contracts.
5. Do not rewrite cache, bridge, command, push, or token core code unless a test proves a bug.
6. Every new control gets an accessibility identifier.
7. Every screen handles empty, loading, success, error, and offline/permission states where relevant.
8. Every agent handoff must list changed paths, commands, screenshots, and gaps.

## Milestone 0: Baseline and guardrails

### Task 0.1: Capture current baseline

**Files:**
- Create: `docs/ui-v4/BASELINE_AUDIT.md`
- Create: `docs/screenshots/ui-v4/baseline/`

**Step 1: Start services**

Run:

```bash
bash scripts/services.sh start
bash scripts/services.sh verify
```

Expected: backend, test HTTP, and prototype are healthy.

**Step 2: Capture screenshots**

Run:

```bash
bash tools/capture-screenshots.sh
```

Expected: current app screenshots are generated.

**Step 3: Write audit**

Document:

- Current primary screens
- Current navigation paths
- Keep/wrap/migrate/delete decision
- Known layout failures
- Known style inconsistencies
- Current test gaps

**Step 4: Verify crash state**

Run:

```bash
bash scripts/scan-crash-logs.sh --json
```

Expected: `"total": 0`.

**Step 5: Commit**

```bash
git add docs/ui-v4/BASELINE_AUDIT.md docs/screenshots/ui-v4/baseline/
git commit -m "docs(ui): capture ui v4 baseline audit"
```

### Task 0.2: Create missing regression script shells

**Files:**
- Create: `tools/run-ui-v4-regression.sh`
- Create: `tools/run-cache-regression.sh`
- Create: `tools/run-jsbridge-regression.sh`
- Create: `tools/run-release-gate.sh`
- Create: `tools/run-real-device-smoke.sh`

**Step 1: Write failing smoke expectation**

Run:

```bash
test -x tools/run-ui-v4-regression.sh
```

Expected: fail if script does not exist yet.

**Step 2: Implement script shells**

Each script must:

- Use `#!/bin/bash`
- Use `set -euo pipefail`
- `cd "$(dirname "$0")/.."`
- Create `build/reports/`
- Print clear sections
- Return non-zero on failure

**Step 3: Add report output**

Each script emits:

- `build/reports/<script-name>.json`
- `build/reports/<script-name>.md`

**Step 4: Run**

```bash
bash tools/run-ui-v4-regression.sh
```

Expected: script reaches existing checks and prints a report path.

**Step 5: Commit**

```bash
git add tools/run-ui-v4-regression.sh tools/run-cache-regression.sh tools/run-jsbridge-regression.sh tools/run-release-gate.sh tools/run-real-device-smoke.sh
git commit -m "test(ui): add ui v4 regression script entrypoints"
```

## Milestone 1: App shell and shared components

### Task 1.1: Add AppTab model

**Files:**
- Create: `SuperApp/Sources/Views/AppShell/AppTab.swift`
- Test: `SuperAppUITests/AppShellTests.swift`

**Step 1: Write UI test**

Test expects tabs with these identifiers:

- `tab.web`
- `tab.bridge`
- `tab.tokenPush`
- `tab.debug`
- `tab.links`

**Step 2: Run test**

```bash
xcodebuild test -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/wbk-dd \
  -only-testing:SuperAppUITests/AppShellTests
```

Expected: fail until shell exists.

**Step 3: Implement `AppTab`**

Define five cases:

```swift
enum AppTab: String, CaseIterable, Identifiable {
    case web
    case bridge
    case tokenPush
    case debug
    case links
}
```

Map each tab to title, Lucide icon, and accessibility ID.

**Step 4: Commit**

```bash
git add SuperApp/Sources/Views/AppShell/AppTab.swift SuperAppUITests/AppShellTests.swift
git commit -m "feat(ui): add ui v4 app tab model"
```

### Task 1.2: Add AppShellView

**Files:**
- Create: `SuperApp/Sources/Views/AppShell/AppShellView.swift`
- Create: `SuperApp/Sources/Views/AppShell/AppShellViewModel.swift`
- Create: `SuperApp/Sources/Views/AppShell/ModuleHeaderView.swift`
- Create: `SuperApp/Sources/Views/AppShell/ServiceStatusStrip.swift`
- Modify: current app entry point or `SuperApp/Sources/Controllers/Tab/TabBarController.swift`

**Step 1: Extend UI test**

Assert:

- App launches into Web tab.
- All five tabs are tappable.
- Debug tab shows a service status strip.

**Step 2: Implement SwiftUI shell**

Use `TabView` and `NavigationStack`.

Initial placeholder views are allowed:

- Web
- Bridge
- Token/Push
- Debug
- Links

**Step 3: Bridge into app entry**

Use `UIHostingController` where the app currently creates the root controller.

**Step 4: Run**

```bash
bash tools/ci-lint.sh
xcodebuild test -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/wbk-dd \
  -only-testing:SuperAppUITests/AppShellTests
```

Expected: pass.

**Step 5: Commit**

```bash
git add SuperApp/Sources/Views/AppShell SuperAppUITests/AppShellTests.swift
git commit -m "feat(ui): add ui v4 app shell"
```

### Task 1.3: Build shared components

**Files:**
- Create: `SuperApp/Sources/Views/Components/StatusBadge.swift`
- Create: `SuperApp/Sources/Views/Components/MetricTile.swift`
- Create: `SuperApp/Sources/Views/Components/ActionRow.swift`
- Create: `SuperApp/Sources/Views/Components/CodeBlockView.swift`
- Create: `SuperApp/Sources/Views/Components/ResultPanel.swift`
- Create: `SuperApp/Sources/Views/Components/EmptyStatePanel.swift`
- Create: `SuperApp/Sources/Views/Components/ConfirmDangerSheet.swift`
- Test: `SuperAppUITests/ComponentCatalogTests.swift`

**Step 1: Add component catalog UI test**

Assert each component appears in the component catalog or a dedicated `--show-component-catalog` path.

**Step 2: Implement components**

Rules:

- Use tokens only.
- No nested cards.
- CodeBlock scrolls internally.
- ResultPanel supports success, error, loading, timeout.
- EmptyStatePanel has optional action with 44 pt minimum height.

**Step 3: Run**

```bash
bash tools/ci-lint.sh
xcodebuild test -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/wbk-dd \
  -only-testing:SuperAppUITests/ComponentCatalogTests
```

Expected: pass.

**Step 4: Commit**

```bash
git add SuperApp/Sources/Views/Components SuperAppUITests/ComponentCatalogTests.swift
git commit -m "feat(ui): add ui v4 shared components"
```

## Milestone 2: Core capability modules

### Task 2.1: Implement Web Cache Home

**Files:**
- Create: `SuperApp/Sources/Views/WebCache/WebCacheHomeView.swift`
- Create: `SuperApp/Sources/Views/WebCache/WebCacheHomeViewModel.swift`
- Create: `SuperApp/Sources/Views/WebCache/WebCacheModePicker.swift`
- Create: `SuperApp/Sources/Views/WebCache/WebCacheStatusPanel.swift`
- Create: `SuperApp/Sources/Views/WebCache/WebCacheCleanupSheet.swift`
- Test: `SuperAppUITests/CacheFlowTests.swift`

**Step 1: Write UI tests**

Cover:

- URL input exists.
- Online mode opens page.
- Cache-first mode opens from cache.
- Full-offline mode shows package status.
- Clear selected cache asks confirmation.
- Clear all cache resets stats.
- Invalid manifest shows error.

**Step 2: Run test to see failures**

```bash
xcodebuild test -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/wbk-dd \
  -only-testing:SuperAppUITests/CacheFlowTests
```

Expected: fail until module exists.

**Step 3: Implement view model adapter**

Wrap existing:

- `CacheDashboardViewModel`
- `Sources/Cache/`
- `Sources/Handlers/ManifestLoader/`

Expose state:

```swift
enum WebCacheScreenState {
    case empty
    case loading(stage: String)
    case onlineSuccess
    case cacheSuccess
    case fullOfflineSuccess
    case offlineMissingCache
    case manifestInvalid(String)
    case cleanupSuccess(deletedCount: Int)
    case failed(String)
}
```

**Step 4: Implement UI**

Use:

- `ModuleHeaderView`
- `StatusBadge`
- `ResultPanel`
- `ConfirmDangerSheet`

**Step 5: Run cache regression**

```bash
bash tools/run-cache-regression.sh
```

Expected: pass or produce clear remaining failures.

**Step 6: Commit**

```bash
git add SuperApp/Sources/Views/WebCache SuperAppUITests/CacheFlowTests.swift
git commit -m "feat(ui): add ui v4 web cache module"
```

### Task 2.2: Implement Bridge Lab

**Files:**
- Create: `SuperApp/Sources/Views/BridgeLab/BridgeLabHomeView.swift`
- Create: `SuperApp/Sources/Views/BridgeLab/BridgeLabViewModel.swift`
- Create: `SuperApp/Sources/Views/BridgeLab/BridgeCommandCatalogView.swift`
- Create: `SuperApp/Sources/Views/BridgeLab/BridgeCommandFormView.swift`
- Create: `SuperApp/Sources/Views/BridgeLab/BridgeResultPanel.swift`
- Test: `SuperAppUITests/JSBridgeLabTests.swift`

**Step 1: Write UI tests**

Cover:

- Handler groups render.
- Command selection renders parameter form.
- Valid command executes.
- Invalid params show inline errors.
- Unknown command shows structured error.
- Timeout state appears.
- Copy result works.

**Step 2: Run test to see failures**

```bash
xcodebuild test -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/wbk-dd \
  -only-testing:SuperAppUITests/JSBridgeLabTests
```

Expected: fail until module exists.

**Step 3: Implement handler catalog**

Catalog groups:

- App
- Cache
- Device
- Interaction
- Media
- Navigation
- Network
- Permission
- System

**Step 4: Implement result panel**

Result must show:

- Status
- JSON
- Duration
- Error code/message
- Copy button
- Open logs button

**Step 5: Run JSBridge regression**

```bash
bash tools/run-jsbridge-regression.sh
```

Expected: pass or report exact failures.

**Step 6: Commit**

```bash
git add SuperApp/Sources/Views/BridgeLab SuperAppUITests/JSBridgeLabTests.swift
git commit -m "feat(ui): add ui v4 jsbridge lab"
```

## Milestone 3: Support modules

### Task 3.1: Implement Token/Push

**Files:**
- Create: `SuperApp/Sources/Views/TokenPush/TokenPushHomeView.swift`
- Create: `SuperApp/Sources/Views/TokenPush/TokenPushViewModel.swift`
- Create: `SuperApp/Sources/Views/TokenPush/TokenListView.swift`
- Create: `SuperApp/Sources/Views/TokenPush/PassphraseListView.swift`
- Create: `SuperApp/Sources/Views/TokenPush/PushPayloadComposerView.swift`
- Test: `SuperAppUITests/TokenPushTests.swift`

**Step 1: Write tests**

Cover:

- Empty token list.
- Generate token.
- Token is redacted by default.
- Reveal requires explicit action.
- Payload JSON validates.
- Local push route result appears.
- Server unavailable state appears.

**Step 2: Implement adapter**

Wrap:

- `TokenManager`
- `PassphraseManager`
- `APIKeyManager`
- `AccessTokenManager`
- `PushNotificationManager`
- `PushRouter`

**Step 3: Run tests**

```bash
xcodebuild test -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/wbk-dd \
  -only-testing:SuperAppUITests/TokenPushTests
```

Expected: pass.

**Step 4: Commit**

```bash
git add SuperApp/Sources/Views/TokenPush SuperAppUITests/TokenPushTests.swift
git commit -m "feat(ui): add ui v4 token push module"
```

### Task 3.2: Implement Debug Center

**Files:**
- Create: `SuperApp/Sources/Views/DebugCenter/DebugCenterHomeView.swift`
- Create: `SuperApp/Sources/Views/DebugCenter/DebugCenterViewModel.swift`
- Create: `SuperApp/Sources/Views/DebugCenter/DebugLogListView.swift`
- Create: `SuperApp/Sources/Views/DebugCenter/DebugNetworkView.swift`
- Create: `SuperApp/Sources/Views/DebugCenter/DebugCrashView.swift`
- Create: `SuperApp/Sources/Views/DebugCenter/DebugExportView.swift`
- Test: `SuperAppUITests/DebugCenterFlowTests.swift`

**Step 1: Write tests**

Cover:

- Logs empty state.
- Logs populated state.
- Filter errors.
- Copy logs.
- Crash zero state.
- Export diagnostics.

**Step 2: Implement segmented debug center**

Segments:

- Logs
- Network
- Cache
- Crash
- Environment
- Export

**Step 3: Run tests**

```bash
xcodebuild test -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/wbk-dd \
  -only-testing:SuperAppUITests/DebugCenterFlowTests
```

Expected: pass.

**Step 4: Commit**

```bash
git add SuperApp/Sources/Views/DebugCenter SuperAppUITests/DebugCenterFlowTests.swift
git commit -m "feat(ui): add ui v4 debug center"
```

### Task 3.3: Implement Deep Link tester

**Files:**
- Create: `SuperApp/Sources/Views/DeepLink/DeepLinkHomeView.swift`
- Create: `SuperApp/Sources/Views/DeepLink/DeepLinkViewModel.swift`
- Create: `SuperApp/Sources/Views/DeepLink/DeepLinkTemplateListView.swift`
- Create: `SuperApp/Sources/Views/DeepLink/DeepLinkParameterEditor.swift`
- Create: `SuperApp/Sources/Views/DeepLink/DeepLinkHistoryView.swift`
- Test: `SuperAppUITests/DeepLinkFlowTests.swift`

**Step 1: Write tests**

Cover:

- Template list renders.
- URL preview updates.
- Missing required param validates.
- Invalid scheme shows structured error.
- Generated URL copies.
- Execution appears in history.

**Step 2: Implement templates**

Templates:

- Open URL
- Open URL with cache mode
- Open page with app ID
- Execute command
- Open debug panel
- Open cache dashboard
- Open bridge lab command

**Step 3: Run tests**

```bash
xcodebuild test -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/wbk-dd \
  -only-testing:SuperAppUITests/DeepLinkFlowTests
```

Expected: pass.

**Step 4: Commit**

```bash
git add SuperApp/Sources/Views/DeepLink SuperAppUITests/DeepLinkFlowTests.swift
git commit -m "feat(ui): add ui v4 deep link tester"
```

## Milestone 4: Visual automation

### Task 4.1: Expand screenshot capture

**Files:**
- Modify: `SuperAppUITests/ScreenshotCaptureTests.swift`
- Modify: `tools/capture-screenshots.sh`
- Create: `docs/screenshots/ui-v4/baseline/`
- Create: `docs/screenshots/ui-v4/current/`
- Create: `docs/screenshots/ui-v4/diff/`

**Step 1: Add screenshot cases**

Capture:

- Web empty
- Web success
- Web offline error
- Bridge ready
- Bridge result
- Token/Push redacted
- Debug logs
- Debug crash zero
- Deep Link generated
- Component catalog

Each must capture:

- Light mode
- Dark mode
- iPhone SE
- iPhone 16 Pro

**Step 2: Run capture**

```bash
bash tools/capture-screenshots.sh
```

Expected: all screenshots exist.

**Step 3: Commit**

```bash
git add SuperAppUITests/ScreenshotCaptureTests.swift tools/capture-screenshots.sh docs/screenshots/ui-v4/
git commit -m "test(ui): add ui v4 screenshot coverage"
```

### Task 4.2: Enforce visual checks

**Files:**
- Modify: `tools/visual-checks.sh`
- Modify: `tools/run-visual-regression.sh`
- Modify: `tools/run-ui-v4-regression.sh`

**Step 1: Add static checks**

Checks:

- No clipped tab content.
- Required screenshots exist.
- Required accessibility IDs exist.
- No hardcoded colors.
- No SF Symbols in feature UI.
- No buttons below 44 pt.
- No missing empty states for primary modules.

**Step 2: Run**

```bash
bash tools/visual-checks.sh
bash tools/run-visual-regression.sh
bash tools/run-ui-v4-regression.sh
```

Expected: pass.

**Step 3: Commit**

```bash
git add tools/visual-checks.sh tools/run-visual-regression.sh tools/run-ui-v4-regression.sh
git commit -m "test(ui): enforce ui v4 visual regression gates"
```

## Milestone 5: Release gate and cleanup

### Task 5.1: Release gate

**Files:**
- Modify: `tools/run-release-gate.sh`
- Modify: `docs/RELEASE_CHECKLIST.md`
- Modify: `docs/APP_SIZE_BUDGET.md`
- Modify: `.github/workflows/ci.yml` if required

**Step 1: Add release checks**

Gate must verify:

- Services healthy.
- SwiftLint passes.
- Design lint passes.
- Build passes.
- Core tests pass.
- UI v4 regression passes.
- Release archive succeeds.
- App size budget respected.
- No test HTML in Release.
- Crash scan total is 0.

**Step 2: Run**

```bash
bash tools/run-release-gate.sh
```

Expected: pass.

**Step 3: Commit**

```bash
git add tools/run-release-gate.sh docs/RELEASE_CHECKLIST.md docs/APP_SIZE_BUDGET.md .github/workflows/ci.yml
git commit -m "test(release): add ui v4 release gate"
```

### Task 5.2: Legacy UI quarantine

**Files:**
- Modify/delete only after parity:
  - `SuperApp/Sources/Controllers/Tab/MainViewController.swift`
  - `SuperApp/Sources/Controllers/Tab/InboxViewController.swift`
  - `SuperApp/Sources/Controllers/Tab/DiscoverViewController.swift`
  - `SuperApp/Sources/Controllers/Tab/SettingsViewController.swift`
  - related old cells under `SuperApp/Sources/Views/Cells/`

**Step 1: Verify parity**

Run:

```bash
bash tools/run-ui-v4-regression.sh
bash tools/run-release-gate.sh
```

Expected: pass before deleting anything.

**Step 2: Remove or hide old UI**

Do one of:

- Delete old UI files if no longer referenced.
- Move old paths behind a debug-only legacy entry.

**Step 3: Verify references**

```bash
rg "MainViewController|InboxViewController|DiscoverViewController|SettingsViewController" SuperApp Sources Tests SuperAppUITests
```

Expected: no unexpected production references.

**Step 4: Commit**

```bash
git add SuperApp Sources Tests SuperAppUITests
git commit -m "refactor(ui): quarantine legacy tab ui after ui v4 parity"
```

## Final verification

Run:

```bash
bash scripts/services.sh verify
swiftlint --quiet
bash tools/ci-lint.sh
bash tools/run-ui-v4-regression.sh
bash tools/run-release-gate.sh
bash scripts/scan-crash-logs.sh --json
git status --short
```

Expected:

- Services: 3/3 healthy
- SwiftLint: no output
- Design lint: pass
- UI v4 regression: pass
- Release gate: pass
- Crash scan: total 0
- Git status: clean after final commit

## Merge checklist

- [ ] Baseline audit committed
- [ ] App shell committed
- [ ] Shared components committed
- [ ] Web Cache module committed
- [ ] JSBridge Lab committed
- [ ] Token/Push module committed
- [ ] Debug Center committed
- [ ] Deep Link module committed
- [ ] Screenshot baseline committed
- [ ] Visual regression gate committed
- [ ] Release gate committed
- [ ] Legacy UI removed or quarantined
- [ ] CI green
- [ ] Real-device smoke completed
