# Test Map And Execution Checklist

Date: 2026-06-04
Scope: WebBridgeKit app, framework, server, public shanbox deployment, simulator regression, and physical-device release checks.

This document is the task-assignment checklist for agents or humans. Each row should be checked against source code, automated tests, user operation path, expected result, and current evidence. Do not mark a module production-ready unless its required automated and manual evidence both exist.

## Environment Rules

| Scenario | Endpoint | Required Setup | Evidence Rule |
| --- | --- | --- | --- |
| Simulator regression | `http://localhost:8080`, `http://localhost:8081`, `http://localhost:8083` | `bash scripts/services.sh start && bash scripts/services.sh verify` | Local deterministic tests only |
| Physical iPhone backend / Bark | `https://wbk.shanbox.19930810.xyz:8443` | `bash tools/verify-shanbox-backend.sh` and `bash tools/verify-shanbox-supervision.sh` | Public route and supervision evidence only |
| Physical iPhone WebView/cache/JSBridge fixtures | `https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/` | `bash tools/verify-shanbox-fixtures.sh` | Public fixture reachability only |
| HTML prototype comparison | `http://localhost:8083` | Local prototype service running | UI comparison only, not backend proof |

## Global Gates

| ID | Gate | Command | Pass Signal | Evidence Path |
| --- | --- | --- | --- | --- |
| G-001 | Local services | `bash scripts/services.sh start && bash scripts/services.sh verify` | Backend, test HTTP, prototype healthy | `scripts/services.sh`, `.services/*.plist` |
| G-002 | SwiftLint | `swiftlint --quiet` | No output, exit 0 | Repo root |
| G-003 | Crash scan | `bash scripts/scan-crash-logs.sh --json` | JSON contains `"total": 0` | `scripts/scan-crash-logs.sh` |
| G-004 | Design/system lint | `bash tools/ci-lint.sh` | `0 failed`; warnings documented | `tools/ci-lint.sh` |
| G-005 | Module availability report guard | `bash tools/verify-module-availability-report.sh` | All checks pass | `tools/verify-module-availability-report.sh`, `docs/verification/module-availability-verification.md` |
| G-006 | Release gate | `bash tools/run-release-gate.sh` | Summary failed count is 0 | `tools/run-release-gate.sh` |

## Web Cache

| Case ID | User Path | Code / Test Path | Automation | Expected Result | Current Status |
| --- | --- | --- | --- | --- | --- |
| C-001 | Web tab -> URL input -> online open | `SuperApp/Sources/Controllers/WebBrowserViewController.swift`, `Tests/CacheTests/WebCacheManagerTests.swift` | `bash tools/run-cache-regression.sh` | Online page loads through WebView without crash | Covered by cache regression and UI availability |
| C-002 | Web tab -> cache dashboard | `SuperAppUITests/CacheDashboardTests.swift`, `Tests/CacheDashboard/CacheStatsAggregatorTests.swift` | `bash tools/run-cache-regression.sh` | Dashboard opens and stats render | Covered |
| C-003 | Web tab -> offline cache manifest | `Tests/CacheTests/ManifestCacheManagerTests.swift`, `Tests/HandlerTests/PersistentManifestLoaderTests.swift` | `xcodebuild test -scheme CacheTests` | Manifest resources are stored and retrievable | Covered by 548 CacheTests |
| C-004 | Web tab -> complete offline mode | `Tests/HandlerTests/OfflineFallbackTests.swift`, `Tests/CacheTests/WebPageOfflineCacheManagerTests.swift` | `bash tools/run-cache-regression.sh` | Cached page works when network is unavailable | Covered in simulator; physical iPhone offline path still should be manually sampled |
| C-005 | Debug Center -> Manifest 缓存用例 -> 清除缓存 | `SuperAppUITests/ModuleAvailabilityTests.swift`, `ManifestCacheTestViewController.swift` | `ModuleAvailabilityTests.testDebugCenterChildToolContentAndActionsAreUsable` | Log contains `所有缓存已清除` | Covered |
| C-006 | Debug Center -> Manifest 缓存用例 -> 智能加载 | `WebViewDisplayViewController.swift`, `ManifestCacheTestViewController.swift` | `ModuleAvailabilityTests.testDebugCenterChildToolContentAndActionsAreUsable` | Opens `WebViewDisplayViewController`, shows `manifest_test.display_webview`, closes, log contains `智能加载成功` | Covered on simulator |
| C-007 | Physical iPhone -> public cache fixture | `test_resources/cache-showcase.html`, `tools/verify-shanbox-fixtures.sh` | `bash tools/verify-shanbox-fixtures.sh` | Public URL returns expected content markers | Fixture reachability covered; native phone cache execution is manual |
| C-008 | Cache HTML fixture validation | `test_resources/cache-html-validation/`, `tools/validate-cache-html.sh` | `bash tools/validate-cache-html.sh` | HTML, manifest, CSS, JS, image fixtures validate | Run after fixture changes |

## JSBridge

| Case ID | User Path | Code / Test Path | Automation | Expected Result | Current Status |
| --- | --- | --- | --- | --- | --- |
| B-001 | Web tab -> open `bridge-promise-smoke.html` | `WebJavaScriptBridge.swift`, `Resources/WebBridge.js`, `SuperApp/Resources/WebBridge.js` | `ModuleAvailabilityTests.testRealWebViewBridgePromiseResolves` | DOM shows `Bridge Promise OK` | Covered on simulator |
| B-002 | Bridge tab -> command list -> execute validation | `BridgeLabHomeView.swift`, `Tests/BridgeTests/BridgeCoreTests.swift` | `ModuleAvailabilityTests.testBridgeLabControlsAreUsable`, `bash tools/run-jsbridge-regression.sh` | Result panel shows `命令已完成结构化校验` and `cache.stats` | Covered |
| B-003 | Native handler registry | `Tests/BridgeTests/HandlerRegistryAdvancedTests.swift`, `Tests/HandlerTests/HandlerRegistryTests.swift` | `xcodebuild test -scheme BridgeTests` | Handlers register, resolve, and reject invalid commands correctly | Covered by BridgeTests |
| B-004 | Page cache JSBridge API | `Tests/HandlerTests/WebPageCacheHandlerTests.swift`, `Tests/HandlerTests/WebCacheDebugHandlerTests.swift` | `bash tools/run-jsbridge-regression.sh` | JS command can invoke cache APIs and returns structured payloads | Covered |
| B-005 | Permission / camera / scan / location handlers | `Tests/HandlerTests/WebPermissionHandlerTests.swift`, `WebCameraHandlerTests.swift`, `WebScanHandlerTests.swift`, `WebLocationHandlerTests.swift` | Handler test scheme via JSBridge regression | Permission commands respond with deterministic status or documented unavailable state | Covered at handler level; real device permission UX should be sampled |
| B-006 | Physical iPhone -> public bridge fixture | `test_resources/bridge-hub.html`, `bridge-promise-smoke.html`, `tools/verify-shanbox-fixtures.sh` | `bash tools/verify-shanbox-fixtures.sh` | Public fixture pages reachable | Fixture reachability covered; native phone Bridge execution is manual |

## Push And Bark

| Case ID | User Path | Code / Test Path | Automation | Expected Result | Current Status |
| --- | --- | --- | --- | --- | --- |
| P-001 | Push tab -> copy Bark URL | `TokenPushHomeView.swift`, `TokenPushHomeViewModel.swift` | `ModuleAvailabilityTests.testTokenPushAndBarkControlsAreUsable` | Result panel contains `推送地址已复制` and `https://wbk.shanbox.19930810.xyz:8443` | Covered on simulator |
| P-002 | Push tab -> Token Manager | `TokenManagerView.swift`, `ModuleAvailabilityTests.swift` | `ModuleAvailabilityTests.testTokenPushAndBarkControlsAreUsable` | Token Manager opens | Covered |
| P-003 | Push tab -> API Key Manager | `APIKeyManagerView.swift`, `ModuleAvailabilityTests.swift` | `ModuleAvailabilityTests.testTokenPushAndBarkControlsAreUsable` | API Key Manager opens | Covered |
| P-004 | Push tab -> Notification Debug | `NotificationDebugViewController.swift`, `ModuleAvailabilityTests.swift` | `ModuleAvailabilityTests.testTokenPushAndBarkControlsAreUsable` | Notification Debug opens | Covered |
| P-005 | shanbox Bark GET route | `Server/Sources/WebBridgeServer/Routes/PushRoutes.swift`, `Server/Tests/WebBridgeServerTests/PushRoutesTests.swift` | `bash tools/verify-shanbox-backend.sh`, `cd Server && swift test` | Bark-compatible GET returns JSON success semantics | Covered route-level |
| P-006 | shanbox Bark POST route | `PushRoutes.swift`, `PushRoutesTests.swift` | `bash tools/verify-shanbox-backend.sh` | Bark-compatible POST returns JSON success semantics | Covered route-level |
| P-007 | APNs entitlement and provisioning | `SuperApp/SuperApp.entitlements`, `project.yml`, `tools/verify-real-device-push-readiness.sh` | `DEVICE_ID=<id> bash tools/verify-real-device-push-readiness.sh` | Signed app contains `aps-environment`; provisioning profile supports Push Notifications | Currently unavailable under Personal Team |
| P-008 | Bark end-to-end delivery | `PushNotificationManager.swift`, server push routes | Manual after P-007 passes | Bark request -> APNs -> iPhone notification -> tap opens expected app path | Not production-proven yet |
| P-009 | Lock-screen/background notification | iOS app notification delegate and APNs profile | Manual after P-007 passes | Notification appears while app backgrounded/locked | Manual-only |

## Commands And Deep Links

| Case ID | User Path | Code / Test Path | Automation | Expected Result | Current Status |
| --- | --- | --- | --- | --- | --- |
| D-001 | Settings -> 协议跳转工具 | `DeepLinkHomeView.swift`, `DeepLinkHomeViewModel.swift` | `ModuleAvailabilityTests.testSettingsDebugCenterAndDeepLinksAreReachable` | Deep Link tool opens | Covered |
| D-002 | Links -> 校验 open URL | `DeepLinkHomeViewModel.validateOpenScheme()` | `ModuleAvailabilityTests.testSettingsDebugCenterAndDeepLinksAreReachable` | Result panel contains `协议链接合法` and `cache-showcase.html` | Covered |
| D-003 | External `webbridgekit://tab?index=2` | `SuperApp/Sources/AppDelegate.swift` | `xcrun simctl openurl ...` in availability report | App switches to Bridge tab | Covered on simulator with first-open confirmation caveat |
| D-004 | External `webbridgekit://open?...` | `AppDelegate.swift`, `WebAccessViewController.swift` | `xcrun simctl openurl ...` in availability report | Opens WebBrowser with target page | Covered on simulator |
| D-005 | Command token generation | `CommandService.swift`, `Server/Tests/WebBridgeServerTests/CommandRoutesTests.swift` | `bash tools/verify-shanbox-backend.sh`, `cd Server && swift test` | URL-safe token payload decodes without `+`, `/`, or `=` padding | Covered |
| D-006 | Command parser security | `Tests/CommandParserTests/CommandDecoderTests.swift`, `HMACSignatureVerifierTests.swift` | `xcodebuild test -scheme CommandParserTests` if available, or full test matrix | Invalid signature / malformed payload rejected | Covered by parser tests when scheme is run |

## Debug Center

| Case ID | User Path | Code / Test Path | Automation | Expected Result | Current Status |
| --- | --- | --- | --- | --- | --- |
| X-001 | Settings -> 调试中心 | `DebugCenterHomeView.swift`, `ModuleAvailabilityTests.swift` | `ModuleAvailabilityTests.testSettingsDebugCenterAndDeepLinksAreReachable` | `debugCenter.home` visible | Covered |
| X-002 | Debug Center -> 全局调试面板 | `DebugPanelViewController.swift`, `DebugPanelTests.swift` | `ModuleAvailabilityTests.testDebugCenterGlobalDebugPanelEntryOpensPanel` | `debugPanel.root`, `debugPanel.tab.0`, `debugPanel.handlers.tableView` visible | Covered |
| X-003 | Debug Center -> 诊断导出 -> 复制到剪贴板 | `DiagnosticsView.swift`, `ModuleAvailabilityTests.swift` | `ModuleAvailabilityTests.testDebugCenterChildToolContentAndActionsAreUsable` | `diagnostics.lastAction` contains `已复制到剪贴板` | Covered |
| X-004 | Debug Center -> 诊断导出 -> 导出到文件 | `DiagnosticsView.swift`, `ModuleAvailabilityTests.swift` | `ModuleAvailabilityTests.testDebugCenterChildToolContentAndActionsAreUsable` | `diagnostics.lastAction` contains `诊断文件已生成` | Covered |
| X-005 | Debug Center -> 诊断导出 -> 分享诊断数据 | `DiagnosticsView.swift` | Manual UI check | iOS share sheet appears with diagnostics JSON | Manual-only |
| X-006 | Debug Center -> 网络请求 -> 清空 | `NetworkDebugViewController.swift`, `ModuleAvailabilityTests.swift` | `ModuleAvailabilityTests.testDebugCenterChildToolContentAndActionsAreUsable` | Seeded request visible, clear action results in `暂无网络请求记录` | Covered |
| X-007 | Debug Center -> Manifest 缓存用例 | `ManifestCacheTestViewController.swift`, `WebViewDisplayViewController.swift` | `ModuleAvailabilityTests.testDebugCenterChildToolContentAndActionsAreUsable` | Controls visible, clear works, smart-load opens WebView and succeeds | Covered |
| X-008 | Debug Center -> 崩溃扫描说明 | `DebugCenterViewModel.showCrashScanGuide()` | Module availability UI test | User-visible guide/result appears or Debug Center remains stable | Covered |

## Settings And App Information Architecture

| Case ID | User Path | Code / Test Path | Automation | Expected Result | Current Status |
| --- | --- | --- | --- | --- | --- |
| S-001 | Bottom tab -> Web | `TabBarController.swift`, `ModuleAvailabilityTests.swift` | `ModuleAvailabilityTests.testPrimaryTabsExposeCurrentInformationArchitecture` | Web root and core controls visible | Covered |
| S-002 | Bottom tab -> Push | `TokenPushHomeView.swift`, `ModuleAvailabilityTests.swift` | Module availability tests | Push metric grid and actions visible | Covered |
| S-003 | Bottom tab -> Bridge | `BridgeLabHomeView.swift`, `ModuleAvailabilityTests.swift` | Module availability tests | Bridge group list, command list, parameter editor visible | Covered |
| S-004 | Bottom tab -> Settings | `SettingsViewController.swift`, `ModuleAvailabilityTests.swift` | Module availability tests | Settings root visible | Covered |
| S-005 | Settings core rows | `SettingsAction`, `ModuleAvailabilityTests.testSettingsCoreRowsAreReachable` | Module availability tests | Server config, token manager, API key, cache manager, favorites, history navigate | Covered |
| S-006 | Settings debug/support rows | `SettingsAction`, `ModuleAvailabilityTests.testSettingsDebugAndSupportRowsAreReachable` | Module availability tests | Appearance, debug panel, diagnostics, cache dashboard navigate | Covered |
| S-007 | Settings -> Appearance | `AppearanceSettingsView.swift`, `ThemeManager.swift` | `ModuleAvailabilityTests.testSettingsPreferencesAreUsable` | Light, dark, follow system options apply without crash | Covered |
| S-008 | Settings -> About -> Legal -> License detail | `AboutView.swift`, `ThirdPartyLicensesViewController.swift`, `LicenseDetailViewController.swift` | `ModuleAvailabilityTests.testSettingsAboutLegalDeepDrillIsReachable` | License list and detail text open | Covered |
| S-009 | Settings -> 通知设置 | `NotificationSettingsOpener.swift` | `ModuleAvailabilityTests.testNotificationSettingsEntryIsWiredWithoutCrashing` | App stays stable or iOS Settings foregrounds | Simulator non-crash covered; physical handoff manual |

## UI, Visual, Layout

| Case ID | User Path | Code / Test Path | Automation | Expected Result | Current Status |
| --- | --- | --- | --- | --- | --- |
| U-001 | Light/Dark screenshots | `SuperAppUITests/ScreenshotCaptureTests.swift`, `tools/capture-screenshots.sh` | `bash tools/capture-screenshots.sh --build` | Screenshots written for core pages | Covered when screenshot gate is run |
| U-002 | Visual static contracts | `tools/visual-checks.sh` | `bash tools/visual-checks.sh` | Row/card/pill heights, placeholder, wrapping, touch target checks pass | Covered by UI v4 gate |
| U-003 | Layout guard | `SuperAppUITests/LayoutGuardTests.swift` | XCUITest targeted run | No hidden/overlapping critical controls | Covered in prior UI gate |
| U-004 | Component catalog | `SuperAppUITests/ComponentCatalogTests.swift`, launch arg `--show-component-catalog` | Targeted UI test | WBK components render with stable dimensions | Covered by component catalog tests when run |
| U-005 | Design token usage | `docs/design-tokens.json`, `Sources/Theme/ThemeTokens.swift`, `tools/sync-tokens.sh` | `bash tools/ci-lint.sh` | No forbidden hardcoded component colors; token JSON valid | Covered with documented warnings |
| U-006 | Visual regression diff | `tools/run-visual-regression.sh`, `tools/diff-screenshots.sh` | `bash tools/run-visual-regression.sh` | Diffs under threshold | Run after visual redesign work |

## Server, Admin, And shanbox

| Case ID | User Path | Code / Test Path | Automation | Expected Result | Current Status |
| --- | --- | --- | --- | --- | --- |
| R-001 | Local backend routes | `Server/Sources/WebBridgeServer/Routes/`, `Server/Tests/WebBridgeServerTests/` | `cd Server && swift test` | Manifest, Push, Command route tests pass | Covered |
| R-002 | Public shanbox Swift backend | `tools/verify-shanbox-backend.sh` | `bash tools/verify-shanbox-backend.sh` | 27 passed, 0 failed | Covered |
| R-003 | Public shanbox process supervision | `tools/verify-shanbox-supervision.sh`, remote supervisor config | `bash tools/verify-shanbox-supervision.sh` | `process=PASS, supervision=PASS, node_admin=PASS` | Covered |
| R-004 | Public Node admin routes | `Server/node/server.js`, `tools/verify-shanbox-backend.sh` | `bash tools/verify-shanbox-backend.sh` | `/admin`, `/admin-push`, `/admin/api/*`, `/ws/status`, `/messages`, `/packages` return 200 | Covered |
| R-005 | Local Node admin source | `Server/node/server.js`, `tools/verify-node-admin-local.sh` | `bash tools/verify-node-admin-local.sh` | 11 passed, 0 failed | Covered locally |
| R-006 | Public static fixtures | `test_resources/`, `tools/verify-shanbox-fixtures.sh` | `bash tools/verify-shanbox-fixtures.sh` | 18 passed, 0 failed | Covered route/content-marker level |

## Release And Physical Device

| Case ID | User Path | Code / Test Path | Automation | Expected Result | Current Status |
| --- | --- | --- | --- | --- | --- |
| M-001 | Debug build | `project.yml`, `WebBridgeKit.xcworkspace` | `xcodebuild build -workspace WebBridgeKit.xcworkspace -scheme SuperApp -sdk iphonesimulator -arch arm64 -derivedDataPath /tmp/wbk-dd` | Build succeeds with 0 business warnings | Covered in release gates |
| M-002 | Release archive | `tools/run-release-gate.sh` | `bash tools/run-release-gate.sh` | Release archive succeeds and no test HTML is bundled | Covered when release gate is run |
| M-003 | Real-device install/launch | `tools/run-real-device-smoke.sh` | `DEVICE_ID=<id> bash tools/run-real-device-smoke.sh` | App builds, installs, launches on iPhone | Currently blocked by Push-capable provisioning profile |
| M-004 | Real-device push readiness | `tools/verify-real-device-push-readiness.sh` | `DEVICE_ID=<id> bash tools/verify-real-device-push-readiness.sh` | 0 failed, manual rows observed | Currently 3 automatic failures under Personal Team |
| M-005 | Manual notification receipt | Push/Bark server + physical iPhone | Manual after M-004 passes | Bark request creates visible notification; tap routes into app | Not proven |
| M-006 | Manual offline cache on phone | Physical iPhone WebView using public fixture URL | Manual | Open public fixture, cache it, disable network, confirm cached/offline behavior | Not fully proven |
| M-007 | Manual iOS Settings handoff | Settings -> 通知设置 | Manual | iOS Settings opens SuperApp notification settings | Not fully proven |

## Assignment Template

Use this template when handing one row to another agent:

```text
Task ID:
Module:
User operation path:
Source paths:
Test paths:
Command to run:
Expected result:
Evidence to paste back:
Current status:
Do not claim available unless:
```

## Current Production Gaps

| Gap | Why It Matters | Required Evidence |
| --- | --- | --- |
| Push-capable provisioning profile | Current Personal Team profile does not support Push Notifications or `aps-environment` | Paid Apple Developer Program team/App ID/profile with Push enabled, signed app entitlement verified |
| Real-device SuperApp install/launch | App cannot be fully proven on phone while signing fails | `tools/run-real-device-smoke.sh` returns production pass signal |
| Bark/APNs end-to-end delivery | Route success with fake token does not prove notification delivery | Real device token registered, Bark request sent, notification received and tapped |
| Physical notification settings handoff | Simulator non-crash is weaker than phone behavior | Manual iPhone check |
| Diagnostics share sheet | File generation is automated, system share UI is manual | Manual share-sheet observation |
| Physical offline cache and JSBridge execution | Public fixture reachability does not prove native phone execution | Manual phone WebView run against public fixture pages |
