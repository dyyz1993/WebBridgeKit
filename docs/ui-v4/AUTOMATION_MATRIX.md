# UI v4 Automation Matrix

## Automation goal

The goal is to turn UI quality into an executable gate. Agents should not report a UI task complete unless the relevant command, test, screenshot, or manual evidence exists.

## Automation layers

| Layer | Tooling | Scope |
|---|---|---|
| Static lint | `tools/ci-lint.sh`, `tools/design-lint.sh`, `rg` rules | Tokens, colors, icons, fonts, fixed heights |
| Unit tests | `xcodebuild test` by scheme | View models, parsers, managers, handlers |
| Integration tests | Existing Cache/Core/Handler/Bridge tests | Cache, manifest, JSBridge, command routing |
| UI tests | XCUITest under `SuperAppUITests/` | User paths and accessibility contracts |
| Screenshot capture | `tools/capture-screenshots.sh`, `ScreenshotCaptureTests` | Light/Dark baseline |
| Visual regression | `tools/run-visual-regression.sh`, `tools/diff-screenshots.sh` | Pixel/threshold comparison |
| Crash scan | `scripts/scan-crash-logs.sh --json` | App/runtime crash gate |
| Release gate | New `tools/run-release-gate.sh` | Final build, archive, size, resources |
| Real-device smoke | New `tools/run-real-device-smoke.sh` | Device-only checks |

## Recommended scripts

### `tools/run-ui-v4-regression.sh`

Purpose:

- Start services.
- Run design lint.
- Build app.
- Run UI v4 tests.
- Capture screenshots.
- Run visual checks.
- Scan crash logs.

Expected output:

- Console summary.
- JSON report at `build/reports/ui-v4-regression.json`.
- Markdown report at `build/reports/ui-v4-regression.md`.

### `tools/run-cache-regression.sh`

Purpose:

- Run cache unit tests.
- Run manifest loader tests.
- Run cache UI tests.
- Verify offline and cleanup states.

Expected test targets:

- `Tests/CacheTests`
- `Tests/HandlerTests`
- `SuperAppUITests/CacheFlowTests.swift`

### `tools/run-jsbridge-regression.sh`

Purpose:

- Run JSBridge unit tests.
- Run handler tests.
- Run Bridge Lab UI tests.

Expected test targets:

- `Tests/CoreTests/WebJavaScriptBridgeTests.swift`
- `Tests/CoreTests/WebJavaScriptBridgeTests+Extended.swift`
- `Tests/BridgeTests`
- `Tests/HandlerTests`
- `SuperAppUITests/JSBridgeLabTests.swift`

### `tools/run-release-gate.sh`

Purpose:

- Verify services.
- Run lint.
- Run core tests.
- Build Release.
- Archive.
- Verify app size.
- Verify no test HTML in Release.
- Scan crash logs.

Expected output:

- Non-zero exit when a release blocker exists.
- Markdown report suitable for PR comment.

### `tools/run-real-device-smoke.sh`

Purpose:

- Build for connected device.
- Install app.
- Launch app.
- Run device smoke checks that do not require private APNs credentials.

Expected output:

- Device name and OS.
- Install result.
- Launch PID.
- Crash scan result.

## Global gates

These gates apply to every agent task.

| Gate | Command | Pass condition |
|---|---|---|
| Service health | `bash scripts/services.sh verify` | 3/3 healthy |
| SwiftLint | `swiftlint --quiet` | No output |
| Design lint | `bash tools/ci-lint.sh` | Exit 0 |
| Crash scan | `bash scripts/scan-crash-logs.sh --json` | `"total": 0` |
| Build | `xcodebuild build -workspace WebBridgeKit.xcworkspace -scheme SuperApp -sdk iphonesimulator -arch arm64 -derivedDataPath /tmp/wbk-dd` | Exit 0 |
| Screenshot capture | `bash tools/capture-screenshots.sh` | All required screenshots generated |
| Visual regression | `bash tools/run-visual-regression.sh` | Under threshold |

## Cache test cases

| ID | Case | Type | Paths | Expected |
|---|---|---|---|---|
| C-001 | Open URL online | UI | `SuperAppUITests/CacheFlowTests.swift` | URL opens, source badge says network |
| C-002 | Cache-first reopen | UI + integration | `Sources/Cache/`, `SuperApp/Sources/Views/WebCache/` | Reopen uses cache when available |
| C-003 | Full offline package open | UI + integration | `Sources/Handlers/ManifestLoader/` | Page opens without network after package exists |
| C-004 | Offline without cache | UI | `WebCacheHomeView` | Error state explains no cached copy |
| C-005 | Invalid manifest URL | Unit + UI | `Sources/Handlers/ManifestLoader/LazyManifestLoader.swift` | Completion returns failure, UI shows manifest error |
| C-006 | Manifest incremental update | Unit | `Tests/CacheTests/` | Only changed resources update |
| C-007 | Manifest app ID conflict | Unit | `Tests/CacheTests/` | Conflict detected and isolated |
| C-008 | Large resource cache | Unit + integration | `Tests/CacheTests/` | No memory spike or partial write |
| C-009 | 404 resource handling | Unit + UI | `Sources/Cache/` | Failed resource is visible and recoverable |
| C-010 | Clear selected cache | UI | `WebCacheCleanupSheet` | Confirmation appears, selected app cache removed |
| C-011 | Clear all cache | UI | `WebCacheCleanupSheet` | Confirmation appears, all cache removed, stats reset |
| C-012 | Cache stats refresh | UI | `CacheDashboardViewModel` | Stats update after open/clear |
| C-013 | Pinned URL open | UI | `PinnedURLManager`, Web tab | Pinned URL opens with selected mode |
| C-014 | Recent history open | UI | `RecentAccessHistoryView` | Recent item reopens |
| C-015 | Cache debug overlay | UI | `WebViewController+CacheDebug.swift` | Overlay opens and does not hide web content |

## JSBridge test cases

| ID | Case | Type | Paths | Expected |
|---|---|---|---|---|
| B-001 | Bridge injects into page | Unit + UI | `WebJavaScriptBridge.swift`, `Resources/WebBridge.js` | JS global exists and is callable |
| B-002 | Known command success | Unit + UI | `Sources/Handlers/` | Result JSON shown |
| B-003 | Unknown command | Unit + UI | `BridgeError.swift` | Error code shown |
| B-004 | Invalid params | Unit + UI | `BridgeCommandFormView` | Form blocks execution or bridge returns structured error |
| B-005 | Callback once | Unit | `WebJavaScriptBridge.swift` | Callback not duplicated |
| B-006 | Timeout | Unit + UI | `WebJavaScriptBridge.swift` | Timeout visible with duration |
| B-007 | Permission denied | UI/manual hybrid | `Sources/Handlers/Permission/` | Permission state visible |
| B-008 | Navigation handler | UI | `Sources/Handlers/Navigation/` | Target route opens |
| B-009 | Cache handler | UI + integration | `Sources/Handlers/CacheDebug/` | Cache command result visible |
| B-010 | Clipboard handler | UI | `Sources/Handlers/Interaction/WebClipboardHandler.swift` | Permission/result visible |
| B-011 | Media handler unavailable | UI | `Sources/Handlers/Media/` | Device/manual-only state visible |
| B-012 | Error log correlation | UI | `DebugCenter` | Failed bridge call appears in logs |

## Token/passphrase test cases

| ID | Case | Type | Paths | Expected |
|---|---|---|---|---|
| T-001 | Empty token list | UI | `TokenPushHomeView` | Empty state with generate action |
| T-002 | Generate token | Unit + UI | `TokenManager.swift` | Token appears redacted |
| T-003 | Copy token redacted by default | UI | `TokenListView` | Copy action respects redaction policy |
| T-004 | Reveal token explicit action | UI/manual | `TokenListView` | Reveal requires explicit user action |
| T-005 | Delete token | UI | `TokenListView` | Confirmation and final empty/updated list |
| T-006 | Passphrase create | Unit + UI | `PassphraseManager.swift` | Passphrase stored and redacted |
| T-007 | Passphrase invalid | Unit + UI | `PassphraseManager.swift` | Validation message visible |
| T-008 | API key list | UI | `APIKeyManager.swift` | Redacted list renders |
| T-009 | Diagnostic export redacts token | Unit + UI | `DebugExportView` | Export contains no raw secret |

## Push test cases

| ID | Case | Type | Paths | Expected |
|---|---|---|---|---|
| P-001 | Device token unavailable | UI | `PushNotificationManager.swift` | Clear unavailable state |
| P-002 | Permission denied | UI/manual hybrid | `PushNotificationManager.swift` | Settings action visible |
| P-003 | Compose local payload | UI | `PushPayloadComposerView` | Valid JSON preview |
| P-004 | Invalid payload | UI | `PushPayloadComposerView` | Inline validation |
| P-005 | Local push route | Unit + UI | `PushRouter.swift` | Route result shown |
| P-006 | Server unavailable | UI | `PushRelayManager.swift` | Error state visible |
| P-007 | Server push route | Integration | `Server/Sources/WebBridgeServer/Routes/PushRoutes.swift` | Backend route succeeds |
| P-008 | APNs delivery | Manual/device | APNs config | Manual evidence required |

## Debug test cases

| ID | Case | Type | Paths | Expected |
|---|---|---|---|---|
| D-001 | Logs empty | UI | `DebugLogListView` | Empty state visible |
| D-002 | Logs populated | UI | `Sources/Infrastructure/Debug/` | Log rows render |
| D-003 | Filter errors | UI | `DebugLogListView` | Only error logs visible |
| D-004 | Copy logs | UI | `DebugLogListView` | Clipboard contains log text |
| D-005 | Export JSON | UI + unit | `DebugExportView` | JSON exported and redacted |
| D-006 | Network healthy | UI | `NetworkDebugViewController.swift` | Status healthy |
| D-007 | Network unavailable | UI | `NetworkDebugViewController.swift` | Status unavailable |
| D-008 | Crash count zero | Script + UI | `scripts/scan-crash-logs.sh` | Zero state visible |
| D-009 | Crash count non-zero | Unit/UI fixture | `DebugCrashView` | Non-zero state blocks release |
| D-010 | Environment view | UI | `DebugCenter` | Simulator/device, version, build visible |

## Deep-link test cases

| ID | Case | Type | Paths | Expected |
|---|---|---|---|---|
| L-001 | Open page URL | UI + integration | `AppDelegate.swift` | Target page opens |
| L-002 | Open page with cache mode | UI | `DeepLinkViewModel` | Mode is parsed and shown |
| L-003 | Command URL | Unit + UI | `CommandHandler.swift`, `Sources/CommandParser/` | Command executes or fails clearly |
| L-004 | Missing required param | Unit + UI | `DeepLinkParameterEditor` | Inline validation |
| L-005 | Invalid scheme | Unit + UI | `CommandParser.swift` | Structured error |
| L-006 | Unsupported path | Unit + UI | `CommandRouter.swift` | Structured error |
| L-007 | Copy generated URL | UI | `DeepLinkHomeView` | Clipboard contains generated URL |
| L-008 | History list | UI | `DeepLinkHistoryView` | Last executions visible |

## Visual regression cases

| ID | Page | Modes | Devices |
|---|---|---|---|
| V-001 | Web empty | Light/Dark | iPhone SE, iPhone 16 Pro |
| V-002 | Web cache success | Light/Dark | iPhone SE, iPhone 16 Pro |
| V-003 | Web offline error | Light/Dark | iPhone SE, iPhone 16 Pro |
| V-004 | Bridge ready | Light/Dark | iPhone SE, iPhone 16 Pro |
| V-005 | Bridge result | Light/Dark | iPhone SE, iPhone 16 Pro |
| V-006 | Token/Push redacted | Light/Dark | iPhone SE, iPhone 16 Pro |
| V-007 | Debug logs | Light/Dark | iPhone SE, iPhone 16 Pro |
| V-008 | Debug crash zero | Light/Dark | iPhone SE, iPhone 16 Pro |
| V-009 | Deep Link generated | Light/Dark | iPhone SE, iPhone 16 Pro |
| V-010 | Component catalog | Light/Dark | iPhone SE, iPhone 16 Pro |

## Manual-only and semi-automated cases

| Case | Why not fully automated | Required evidence |
|---|---|---|
| APNs real delivery | Requires valid APNs environment and device state | Device video or screenshot plus payload |
| Camera/scan UX | Requires camera hardware or controlled simulator media | Manual pass note or simulator media setup |
| Permission sheet first-run behavior | iOS owns system sheet timing | Screenshot or screen recording |
| Background push behavior | Requires app lifecycle and APNs/device | Manual test log |
| Network handoff Wi-Fi/cellular | Physical environment dependent | Manual checklist |
| Low-memory behavior | Device/simulator memory pressure is unstable | Crash scan plus manual note |

## Report format

Every automation script should produce the same final summary shape:

```markdown
## UI v4 Regression Report

| Gate | Result | Evidence |
|---|---|---|
| Services | PASS | 3/3 healthy |
| Design lint | PASS | tools/ci-lint.sh |
| Build | PASS | xcodebuild exit 0 |
| UI tests | PASS | 42/42 |
| Screenshots | PASS | 20 files |
| Visual regression | PASS | threshold 0.02 |
| Crash scan | PASS | total 0 |

## Failures

- None
```

Agents must attach the report path in their handoff.
