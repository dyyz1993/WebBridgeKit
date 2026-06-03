# Module Availability Verification Report

Date: 2026-06-03 00:55 CST
Commit under test: `869402f` plus current real-device Push readiness refresh
Simulator: `iPhone 16 Pro UI Test`, iOS Simulator 26.5, command destination `platform=iOS Simulator,id=79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0`<br>
Physical device: `许映洲的iPhone`, iPhone 13, identifier `F38FECA2-2A43-5554-B65D-9990CEEAB0EA`, currently `connected` to Xcode CoreDevice

## Summary

| Area | Status | Evidence |
| --- | --- | --- |
| Services | Available | `bash scripts/services.sh restart && bash scripts/services.sh verify` passed, ports 8080/8081/8083 healthy; launchctl-backed services remain available across separate shell commands |
| SwiftLint | Available | `swiftlint --quiet` produced zero output |
| Crash gate | Available | `bash scripts/scan-crash-logs.sh --json` -> `{"diagnostic_reports":0,"app_crash_logs":0,"total":0}` |
| Design lint | Available with warnings | `bash tools/ci-lint.sh` passed 16/16 checks, 0 errors, 5 warnings |
| Module UI availability | Available | `ModuleAvailabilityTests`: 14 tests, 0 failures on UDID `79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0`; includes real WebView JSBridge smoke, split Settings row reachability gates, Debug Center global panel entry, Debug Center child tool concrete-screen entry checks, and Debug Center child tool content/action checks |
| JSBridge real WebView Promise smoke | Available | `testRealWebViewBridgePromiseResolves` opens `bridge-promise-smoke.html`, executes `BarkBridge.callNative('getSystemInfo')`, and waits for DOM text `Bridge Promise OK` |
| Module availability report guard | Available | `bash tools/verify-module-availability-report.sh`; all `SettingsAction` entries are represented in the report and current unavailable markers are enforced |
| Settings remember-last-app restore | Available | `SettingsPreferenceKeys` now centralizes `settings.rememberLastApp` and `settings.lastOpenedURL`; `TabBarController`, `WebAccessViewController`, and `MainViewController` use the same keys with legacy migration |
| Settings Appearance entry | Available | `settings.cell.appearance` now opens `AppearanceSettingsView`; `ThemeMode` selection is persisted to `settings.appearanceMode` and applied through `ThemeManager` |
| Cache semantics | Available | `CacheTests`: 548 tests, 0 failures |
| JSBridge semantics | Available | `BridgeTests`: 101 tests, 0 failures |
| Bark/Push/message semantics | Available | `MessageTests`: 226 tests, 0 failures |
| Server route semantics | Available | `cd Server && swift test` passed 16 tests, 0 failures |
| Physical device install and launch | Unavailable for SuperApp in current signing environment | `xcrun devicectl list devices` shows the paired iPhone as `connected`; `bash tools/run-real-device-smoke.sh` -> 1 passed, 2 failed because the Personal Development Team provisioning profile does not support Push Notifications; a no-push command-line override with bundle id `com.webbridgekit.superapp.nopush` also failed before producing `SuperApp.app` |
| Real-device Push/APNs readiness | Unavailable | `bash tools/verify-real-device-push-readiness.sh` -> 6 passed, 3 failed, 4 manual on 2026-06-03 00:52 CST; `project.yml` points to `SuperApp/SuperApp.entitlements`, but the current Personal Development Team/provisioning profile does not support Push Notifications or `aps-environment` |
| shanbox Swift backend + Node admin public routes | Available | `bash tools/verify-shanbox-backend.sh` -> 26 passed, 0 failed, 0 unavailable, report date 2026-06-03 00:52 CST |
| shanbox WebBridgeServer + Node admin supervision | Available | `bash tools/verify-shanbox-supervision.sh` -> process=PASS, supervision=PASS, node_admin=PASS via supervisord, report date 2026-06-03 00:52 CST |
| Node admin local source | Available locally | `bash tools/verify-node-admin-local.sh` -> 11 passed, 0 failed; validates `Server/node/server.js` routes on a temporary local port |
| shanbox Node admin console | Available | `bash tools/verify-shanbox-backend.sh` -> `/admin`, `/admin-push`, `/admin/api/*`, `/ws/status`, `/messages`, `/packages` all return 200; `webbridge-node-admin` is supervised on remote port `8765` |
| Deep Link external open | Available with first-open confirmation | `xcrun simctl openurl ... webbridgekit://tab?index=2` switched to Bridge; `webbridgekit://open?...cache-showcase.html` opened WebBrowser with Cache Showcase page |
| Deep Link command token | Available on simulator for HTTP/HTTPS URL and in-app `webbridgekit` payloads | Local server generated `webbridgekit://command/<id>.<base64url-json>`; HTTP payload opened Cache Showcase; in-app custom-scheme payload `webbridgekit://tab?index=2` switched to Bridge; screenshots: `docs/screenshots/interaction/command-deeplink-cache-showcase.jpg`, `docs/screenshots/interaction/command-deeplink-custom-scheme-bridge.jpg` |

## Automated Evidence

```bash
xcrun devicectl list devices
# Result:
# Name: 许映洲的iPhone
# Identifier: F38FECA2-2A43-5554-B65D-9990CEEAB0EA
# State: available (paired)
# Model: iPhone 13 (iPhone14,5)
```

```bash
bash scripts/services.sh restart
bash scripts/services.sh verify
# Result: all 3 services verified in the start shell and again in a separate shell.
# Implementation note: scripts/services.sh now uses per-user launchctl jobs under .services/*.plist.
```

```bash
xcodebuild test -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0' \
  -derivedDataPath /tmp/wbk-dd \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:SuperAppUITests/ModuleAvailabilityTests \
# Result: TEST SUCCEEDED, 14 tests, 0 failures, xcresult:
# /tmp/wbk-dd/Logs/Test/Test-SuperApp-2026.06.03_00-42-24-+0800.xcresult
```

```bash
xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme CacheTests \
  -destination 'platform=iOS Simulator,id=79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0' \
  -derivedDataPath /tmp/wbk-dd-cache-tests CODE_SIGNING_ALLOWED=NO
# Result: TEST SUCCEEDED, 548 tests, 0 failures
```

```bash
xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme BridgeTests \
  -destination 'platform=iOS Simulator,id=79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0' \
  -derivedDataPath /tmp/wbk-dd-bridge-tests CODE_SIGNING_ALLOWED=NO
# Result: TEST SUCCEEDED, 101 tests, 0 failures
```

```bash
xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme MessageTests \
  -destination 'platform=iOS Simulator,id=79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0' \
  -derivedDataPath /tmp/wbk-dd-message-tests CODE_SIGNING_ALLOWED=NO
# Result: TEST SUCCEEDED, 226 tests, 0 failures
```

```bash
cd Server && swift test
# Result: Test run with 16 tests in 3 suites passed
# Suites: Manifest Routes, Push Routes, Command Routes
```

```bash
bash tools/verify-module-availability-report.sh
# Result: 80 passed, 0 failed
# Report: build/reports/module-availability-report-check.md
#
# Scope:
# - Verifies required report sections and core module rows are present.
# - Extracts all 15 `SettingsAction` cases from `SettingsViewModel.swift`.
# - Requires every Settings action to appear as a `settings.cell.*` row in the module report.
# - Requires known unavailable markers for current APNs/Push provisioning blockers.
# - Requires Appearance and remember-last-app restore to be marked available when source implementation is present.
# - Requires real WebView JSBridge evidence plus Debug Center concrete child-entry/content/action evidence.
```

```bash
xcodebuild test -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0' \
  -derivedDataPath /tmp/wbk-dd \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:SuperAppUITests/ModuleAvailabilityTests/testRealWebViewBridgePromiseResolves
# Result: TEST SUCCEEDED, 1 test, 0 failures, xcresult:
# /tmp/wbk-dd/Logs/Test/Test-SuperApp-2026.06.02_23-24-59-+0800.xcresult
#
# Fixture:
# http://localhost:8081/test_resources/bridge-promise-smoke.html?v=2
#
# UI assertion:
# Real WKWebView exposes browserManager.webView and page DOM reaches "Bridge Promise OK".
```

```bash
BODY='{"type":"urlScheme","data":"http://localhost:8081/test_resources/cache-showcase.html","format":"urlScheme","ttlSeconds":300}'
JSON=$(curl -sS -X POST http://localhost:8080/api/v1/commands -H 'Content-Type: application/json' -d "$BODY")
URL=$(printf '%s' "$JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["url"])')
xcrun simctl openurl 79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0 "$URL"
# Result: token used URL-safe base64 without `/`, `+`, or `=`.
# UI result: command recognition alert appeared; tapping `打开` opened Cache Showcase.
# Screenshot: docs/screenshots/interaction/command-deeplink-cache-showcase.jpg
```

```bash
BODY='{"type":"urlScheme","data":"webbridgekit://tab?index=2","format":"urlScheme","ttlSeconds":300}'
JSON=$(curl -sS -X POST http://localhost:8080/api/v1/commands -H 'Content-Type: application/json' -d "$BODY")
URL=$(printf '%s' "$JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["url"])')
xcrun simctl openurl 79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0 "$URL"
# Previous result before fix: CommandParser failed with invalidURL("webbridgekit://tab?index=2").
# Fixed result: command recognition alert appeared; tapping `打开` switched to Bridge tab.
# Screenshot: docs/screenshots/interaction/command-deeplink-custom-scheme-bridge.jpg
```

```bash
bash tools/run-real-device-smoke.sh
# Result: 1 passed, 2 failed, exit 1
# Date: 2026-06-03 00:52 CST
# Gates:
# - Device discovery passed
# - Build for device failed because Personal Development Teams do not support Push Notifications
# - SuperApp.app was not produced under /tmp/wbk-dd-device-smoke
# Report: build/reports/real-device-smoke.md
```

```bash
bash tools/verify-real-device-push-readiness.sh
# Result: 6 passed, 3 failed, 4 manual, exit 1
# Date: 2026-06-03 00:52 CST
# Report: build/reports/real-device-push-readiness.md
#
# Passed:
# - Paired iPhone available
# - shanbox backend routes
# - shanbox backend supervision
# - APNs entitlement configured in project
# - APNs token forwarded to PushNotificationManager
# - Default Bark server is shanbox
#
# Failed:
# - Real-device build/install/launch failed because the current Personal Development Team/provisioning profile does not support Push Notifications
# - Provisioning profile does not support Push Notifications / aps-environment
# - Signed app APNs entitlement cannot be proven because the push-capable real-device build failed before producing SuperApp.app
#
# Manual:
# - Observe notification permission prompt on iPhone
# - Verify real APNs token registration to shanbox
# - Verify Bark end-to-end notification receipt
# - Verify background/lock-screen notification behavior
```

```bash
xcodebuild build -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -destination 'id=F38FECA2-2A43-5554-B65D-9990CEEAB0EA' \
  -derivedDataPath /tmp/wbk-dd-device-smoke-nopush \
  -allowProvisioningUpdates \
  CODE_SIGN_ENTITLEMENTS= \
  PRODUCT_BUNDLE_IDENTIFIER=com.webbridgekit.superapp.nopush
# Result: exit 65
# Report: build/reports/real-device-nopush-override.log
# Failure:
# - Cannot create a provisioning profile for `com.webbridgekit.superapp.nopush`
# - Personal Development Teams do not support the Push Notifications capability
# - No `SuperApp.app` was produced
```

```bash
bash tools/verify-shanbox-backend.sh
# Result: 26 passed, 0 failed, 0 unavailable/needs deployment
# Date: 2026-06-03 00:52 CST
# Report: build/reports/shanbox-backend-verification.md
#
# Required-available routes:
# - GET /health
# - GET /api/v1/stats
# - GET /api/v1/manifests
# - POST /register
# - ASSERT register response code == 200
# - POST /push
# - ASSERT JSON push response code == 200
# - POST /test
# - ASSERT test push response success == true
# - POST /api/v1/commands
# - GET /test_resources/Codex/route%20check
# - ASSERT Bark GET response code == 200
# - POST /test_resources/Codex/post%20route
# - ASSERT Bark POST response code == 200
# - GET /test_resources/{encoded-title}/{encoded-body}?sound=bell&group=Codex%20Group&url={encoded-url}
# - ASSERT Bark encoded query response code == 200
#
# Public Node admin routes:
# - GET /admin
# - GET /admin-push
# - GET /admin/api/stats
# - GET /admin/api/devices
# - GET /admin/api/commands
# - GET /admin/api/manifests
# - GET /admin/api/push-history
# - GET /ws/status
# - GET /messages
# - GET /packages
```

```bash
bash tools/verify-shanbox-supervision.sh
# Result: process=PASS, supervision=PASS, node_admin=PASS
# Date: 2026-06-03 00:52 CST
# Report: build/reports/shanbox-supervision-verification.md
#
# Evidence:
# - WebBridgeServer process exists and listens on remote :8080
# - Remote PID 1 is `supervisord`
# - `supervisorctl status webbridgeserver` reports RUNNING
# - Node admin process `webbridge-node-admin` listens on remote :8765 and is supervised by supervisord
# - Public route verification passes 26/26 after path-proxying admin routes to Node
```

```bash
bash tools/verify-node-admin-local.sh
# Result: 11 passed, 0 failed
# Report: build/reports/node-admin-local-verification.md
#
# Verified local/source routes:
# - GET /health
# - GET /admin
# - GET /admin-push
# - GET /admin/api/stats
# - GET /admin/api/devices
# - GET /admin/api/commands
# - GET /admin/api/manifests
# - GET /admin/api/push-history
# - GET /ws/status
# - GET /messages
# - GET /packages
#
# Scope:
# - Proves `Server/node/server.js` can serve the Node admin routes locally.
# - Public deployment is separately proven by `tools/verify-shanbox-backend.sh`.
```

```bash
xcrun simctl openurl 79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0 'webbridgekit://tab?index=2'
# Result: exit 0; first run displayed iOS "在 SuperApp 中打开？" confirmation.
# After accepting "打开", XcodeBuildMCP snapshot showed Bridge heading and bridgeLab controls.

xcrun simctl openurl 79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0 \
  'webbridgekit://open?url=http%3A%2F%2Flocalhost%3A8081%2Ftest_resources%2Fcache-showcase.html'
# Result: exit 0; XcodeBuildMCP snapshot showed browserManager controls.
# Screenshot: build/reports/deeplink/open-cache-demo.png showed "Cache Showcase — WebBridgeKit".

/usr/local/opt/curl/bin/curl -s -o /dev/null -w '%{http_code}\n' \
  http://localhost:8081/test_resources/cache-showcase.html
# Result: 200
```

## Module Matrix

| Module | Function | User path | Code path | Automated evidence | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Web Cache | Primary tab loads | Bottom tab `Web` | `SuperApp/Sources/Views/WebCache/WebCacheHomeView.swift` | `ModuleAvailabilityTests.testPrimaryTabsExposeCurrentInformationArchitecture` | Available | Root id `webCache.home` |
| Web Cache | URL input and open button | `Web` -> target URL -> `打开` | `WebCacheHomeView.swift`, `WebCacheHomeViewModel.swift` | UI test verifies `webCache.urlInput`, `webCache.openButton` | Available | Network result still depends on service/LAN config on physical phone |
| Web Cache | Online/cache-first/full-offline mode selection | `Web` -> `在线/缓存优先/完全离线` | `WebCacheModePicker.swift` | `testWebCacheCriticalControlsAreUsable` taps all 3 modes | Available | UI mode switching verified |
| Web Cache | Cache dashboard | `Web` -> `缓存仪表盘` | `CacheDashboardViewController.swift`, `CacheDashboardView.swift` | UI test opens dashboard; `CacheTests` validates stats/cache systems | Available | |
| Web Cache | Cache management | `Web` -> `缓存管理` | `ManagementViewController.swift`, `CacheManagementViewController.swift` | UI test opens segmented management screen | Available | |
| Web Cache | Clear all confirmation | `Web` -> `清理全部缓存` | `WebCacheHomeViewModel.clearAllCache()` | UI test verifies confirmation sheet and cancel action | Available | Destructive confirm is visible |
| Web Cache | Resource/manifest/offline storage semantics | Non-UI cache APIs | `Sources/Cache/` | `CacheTests`: 548/548 | Available | Includes manifest, URL scheme, resource cache, stats |
| Push/Bark | Primary tab loads | Bottom tab `Push` | `TokenPushHomeView.swift` | UI test verifies `tokenPush.home` and metric grid | Available | |
| Push/Bark | Access token manager | `Push` -> `访问口令` | `TokenManageViewController.swift` | UI test opens screen | Available | |
| Push/Bark | Bark API/API key manager | `Push` -> `Bark API / API Key` | `APIKeyManageViewController.swift` | UI test opens screen | Available | |
| Push/Bark | Notification debug entry | `Push` -> `Bark 推送调试` | `NotificationDebugViewController.swift` | UI test opens screen in Debug build | Available | Debug-only in non-Debug builds |
| Push/Bark | Copy Bark-compatible push URL | `Push` -> copy icon beside push URL | `TokenPushHomeViewModel.copyPushURL()` | `ModuleAvailabilityTests.testTokenPushAndBarkControlsAreUsable` taps the concrete Button and asserts ResultPanel value contains `推送地址已复制` and `https://wbk.shanbox.19930810.xyz:8443`; MessageTests cover routing/payload semantics | Available | XCUITest cannot reliably read the app process pasteboard, so the deterministic evidence is the app-visible copied URL result |
| Push/Bark | Bark payload validation | `Push` -> `校验 Bark Payload` | `TokenPushHomeViewModel.validatePayload()`, `PushPayload.swift` | UI test taps control; `MessageTests` validates Bark/push payload behavior | Available | |
| Push/Bark | shanbox health and JSON push route | External `https://wbk.shanbox.19930810.xyz:8443` | `Server/Sources/WebBridgeServer/Routes/HealthRoutes.swift`, `PushRoutes.swift` | `tools/verify-shanbox-backend.sh`: `/health`, `/register`, `/push`, JSON response code assertions | Available for route-level checks | This uses a fake device token, so APNs delivery is not proven |
| Push/Bark | shanbox Bark-compatible URL | External `/{key}/{title}/{body}` | `Server/Sources/WebBridgeServer/Routes/PushRoutes.swift` | `tools/verify-shanbox-backend.sh`; `Server/PushRoutesTests` verify GET, POST, encoded Chinese title/body, and query parameters | Available for route-level checks | Uses service test key; real APNs delivery still requires a real registered token |
| Push/Bark | shanbox test endpoint | External `POST /test` | `Server/Sources/WebBridgeServer/Routes/PushRoutes.swift` | `tools/verify-shanbox-backend.sh` asserts `success == true`; `Server/PushRoutesTests.testPushEndpointReportsSuccess` | Available for route-level checks | Route-level semantic success verified; APNs delivery still requires real token |
| Push/Bark | APNs registration | `Push` -> `注册推送` | `PushNotificationManager.swift`, `AppDelegate.swift`, project entitlements | `tools/verify-real-device-push-readiness.sh`: project entitlement passes, provisioning profile and signed-app entitlement fail | Unavailable | Token forwarding is fixed and `SuperApp/SuperApp.entitlements` contains `aps-environment`; current Personal Development Team/provisioning profile rejects Push Notifications, so APNs cannot be marked ready |
| Push/Bark | Bark/APNs end-to-end delivery | Bark-compatible request -> shanbox -> APNs -> iPhone notification -> tap action | `PushNotificationManager.swift`, `BarkChannel`, `PushRoutes.swift`, APNs provisioning | `tools/verify-real-device-push-readiness.sh` marks Bark delivery as MANUAL and APNs signing as failed | Unavailable in current signing environment | Bark/APNs end-to-end delivery is unavailable until a Push-capable Apple Developer Program team/profile signs the app and a real device token is registered |
| Bridge | Primary tab loads | Bottom tab `Bridge` | `BridgeLabHomeView.swift` | UI test verifies `bridgeLab.home`, groups, command list, parameter editor | Available | |
| Bridge | Command JSON entry and execute control | `Bridge` -> `执行校验` | `BridgeLabHomeView.swift`, `BridgeLabViewModel.swift`, `ResultPanel.swift`, `ModuleAvailabilityTests.swift` | Existing UI test taps execute; `BridgeTests` validates registry/core semantics. Current source now exposes `bridge.resultPanel` and `testBridgeLabControlsAreUsable` asserts the result value contains `命令已完成结构化校验` and `cache.stats`, but the focused rerun was blocked before XCTest execution by local `AssetCatalogSimulatorAgent`/CoreSimulator system-policy failure while compiling `Sources/Theme/icons.xcassets`. | Partially available | Bridge Lab is a validation/lab surface, not the production WebView execution path. Keep partial until `testBridgeLabControlsAreUsable` passes with the new `bridge.resultPanel` assertions; real WebView Promise execution is separately proven below |
| Bridge | Real WebView JSBridge Promise execution | `Web` -> `在线` -> open `bridge-promise-smoke.html` | `WebJavaScriptBridge.swift`, `Resources/WebBridge.js`, `SuperApp/Resources/WebBridge.js`, `WebBrowserViewModel.swift`, `WebBrowserViewController.swift`, `WebBrowserViewController+Navigation.swift`, `LazyManifestLoader.swift`, `PersistentManifestLoader.swift`, `test_resources/bridge-promise-smoke.html` | `ModuleAvailabilityTests.testRealWebViewBridgePromiseResolves` passed on simulator UDID `79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0` | Available on simulator | Proves page JS -> native `getSystemInfo` -> JS Promise resolve -> DOM text `Bridge Promise OK`; physical-device WebView smoke can reuse the same URL after phone backend reachability is configured |
| Bridge | Handler registry and metadata | Non-UI JSBridge APIs | `Sources/Bridge/`, `Sources/Handlers/` | `BridgeTests`: 101/101 | Available | |
| Commands | shanbox command generation | External `POST /api/v1/commands` | `Server/Sources/WebBridgeServer/Routes/CommandRoutes.swift` | `tools/verify-shanbox-backend.sh`; `Server/CommandRoutesTests` | Available | Public endpoint returns a signed command token |
| Server Ops | shanbox WebBridgeServer process | SSH `shanbox` / public backend | `/root/WebBridgeKit/Server/.build/release/WebBridgeServer`, `tools/verify-shanbox-supervision.sh` | `tools/verify-shanbox-supervision.sh`: process=PASS, supervision=PASS | Available | Process is running, listening, and supervised by supervisord |
| Settings | Primary tab loads | Bottom tab `设置` | `SettingsView.swift`, `SettingsViewModel.swift` | UI test verifies top rows and all operational rows | Available | |
| Settings | Server config | `设置` -> `服务器配置` (`settings.cell.serverConfig`) | `ServerConfigViewController.swift` | `ModuleAvailabilityTests.testSettingsCoreRowsAreReachable` opens screen | Available | |
| Settings | Token manager | `设置` -> `口令管理` (`settings.cell.tokenManager`) | `TokenManageViewController.swift` | `ModuleAvailabilityTests.testSettingsCoreRowsAreReachable` opens screen | Available | |
| Settings | API key manager | `设置` -> `密钥管理` (`settings.cell.apiKeyManage`) | `APIKeyManageViewController.swift` | `ModuleAvailabilityTests.testSettingsCoreRowsAreReachable` opens screen | Available | |
| Settings | Cache manager | `设置` -> `缓存管理` (`settings.cell.cacheManager`) | `ManagementViewController.swift` | `ModuleAvailabilityTests.testSettingsCoreRowsAreReachable` opens screen | Available | |
| Settings | Favorites | `设置` -> `收藏夹` (`settings.cell.favorites`) | `FavoriteViewController.swift` | `ModuleAvailabilityTests.testSettingsCoreRowsAreReachable` opens screen | Available | |
| Settings | Recent history | `设置` -> `最近访问` (`settings.cell.history`) | `RecentAccessHistoryView.swift` | `ModuleAvailabilityTests.testSettingsCoreRowsAreReachable` opens screen | Available | |
| Settings | Remember last app toggle and restore | `设置` -> `记住上次打开` (`settings.cell.rememberLastApp`, `settings.toggle.rememberLastApp`) | `SettingsView.swift`, `SettingsPreferenceKeys.swift`, `TabBarController.checkAndRestoreLastApp()` | `ModuleAvailabilityTests.testSettingsPreferencesAreUsable`; source uses shared `SettingsPreferenceKeys.rememberLastApp` and `SettingsPreferenceKeys.lastOpenedURL` with legacy migration | Available | Toggle is UI-test reachable; restore reads the same key written by Web open flows |
| Settings | Appearance | `设置` -> `外观` (`settings.cell.appearance`) | `AppearanceSettingsView.swift`, `TabBarController.handleSettingsNavigation(_:)`, `ThemeManager` | `ModuleAvailabilityTests.testSettingsPreferencesAreUsable` opens `appearance.root`, verifies `appearance.modePicker`, and toggles `浅色/深色/跟随系统` | Available | Selection persists to `settings.appearanceMode` and is re-applied during theme bootstrap |
| Settings | Debug panel direct entry | `设置` -> `调试面板` (`settings.cell.debugPanel`) | `DebugPanelViewController.swift`, `TabBarController.handleSettingsNavigation(_:)` | `ModuleAvailabilityTests.testSettingsDebugAndSupportRowsAreReachable` taps direct row; `DebugPanelTests` cover panel tabs | Available in DEBUG | Direct entry is reachable; DEBUG-only surface |
| Settings | Debug Center | `设置` -> `调试中心` (`settings.cell.debugCenter`) | `DebugCenterHomeView.swift`, `TabBarController.handleSettingsNavigation(_:)` | `ModuleAvailabilityTests.testSettingsDebugCenterAndDeepLinksAreReachable` opens `debugCenter.home` | Available | |
| Settings | Deep Links | `设置` -> `协议跳转工具` (`settings.cell.deepLinks`) | `DeepLinkHomeView.swift`, `TabBarController.handleSettingsNavigation(_:)` | `ModuleAvailabilityTests.testSettingsDebugCenterAndDeepLinksAreReachable` opens `deepLink.home` | Available | |
| Settings | Export diagnostics direct entry | `设置` -> `诊断导出` (`settings.cell.exportDiagnostics`) | `DiagnosticsView.swift`, `TabBarController.handleSettingsNavigation(_:)` | `ModuleAvailabilityTests.testSettingsDebugAndSupportRowsAreReachable` taps direct row and verifies concrete presentation | Available in DEBUG | Direct entry is reachable; DEBUG-only surface |
| Settings | Cache dashboard | `设置` -> `缓存仪表盘` (`settings.cell.cacheDashboard`) | `CacheDashboardViewController.swift` | `ModuleAvailabilityTests.testSettingsDebugAndSupportRowsAreReachable` opens screen | Available | |
| Settings | About/legal | `设置` -> `关于` (`settings.cell.about`) -> `第三方开源许可` -> `Alamofire` | `AboutView.swift`, `ThirdPartyLicensesViewController.swift`, `LicenseDetailViewController.swift` | `ModuleAvailabilityTests.testSettingsAboutLegalDeepDrillIsReachable` opens About, license list, and license detail | Available | Deep drill now asserted with accessibility identifiers |
| Settings | Notification settings entry | `设置` -> `通知设置` (`settings.cell.notificationSettings`) | `NotificationSettingsOpener.open()` using `UIApplication.openNotificationSettingsURLString` on iOS 16+ and app Settings fallback below iOS 16 | `ModuleAvailabilityTests.testNotificationSettingsEntryIsWiredWithoutCrashing` taps the row and verifies either iOS Settings foregrounds or the app remains stable in foreground | Entry available; system handoff not proven in current simulator | The UI entry is wired and non-crashing. Current simulator did not foreground `com.apple.Preferences`, so real iOS Settings handoff still requires physical/manual confirmation |
| Debug Center | Debug home | `设置` -> `调试中心` (`settings.cell.debugCenter`) | `DebugCenterHomeView.swift` | UI test opens `debugCenter.home` | Available | |
| Debug Center | Global debug panel | `调试中心` -> `全局调试面板` (`debugCenter.openDebugPanel`) | `DebugPanelViewController.swift` | `ModuleAvailabilityTests.testDebugCenterGlobalDebugPanelEntryOpensPanel` opens `debugPanel.root`, verifies `debugPanel.tab.0`, and verifies `debugPanel.handlers.tableView` | Available in DEBUG | Proves the Debug Center entry opens the actual panel shell and handler list |
| Debug Center | Diagnostics export | `调试中心` -> `诊断导出` (`debugCenter.openDiagnostics`) | `DiagnosticsView.swift` | `ModuleAvailabilityTests.testDebugCenterChildToolEntriesOpenConcreteScreens` opens `diagnostics.root`; `ModuleAvailabilityTests.testDebugCenterChildToolContentAndActionsAreUsable` verifies `系统信息`, `导出工具`, taps `复制到剪贴板`, and asserts `diagnostics.lastAction` contains `已复制到剪贴板`; direct Settings row also opens diagnostics | Copy action available in DEBUG | Share sheet/export-to-file payload content is not fully asserted here |
| Debug Center | Network inspector | `调试中心` -> `网络请求` (`debugCenter.openNetworkInspector`) | `NetworkDebugViewController.swift` | `ModuleAvailabilityTests.testDebugCenterChildToolContentAndActionsAreUsable` opens `networkDebug.tableView`, verifies `networkDebug.cell.0`, sample URL `https://api.example.com/manifest`, method `GET`, status `200`, taps `networkDebug.clearButton`, and verifies `暂无网络请求记录` | Available in DEBUG | Verifies seeded capture content and clear-to-empty behavior; live traffic capture is not replayed here |
| Debug Center | Cache dashboard | `调试中心` -> `缓存仪表盘` (`debugCenter.openCacheDashboard`) | `CacheDashboardViewController.swift` | `ModuleAvailabilityTests.testDebugCenterChildToolEntriesOpenConcreteScreens` opens `cacheDashboard.root` | Available | Cache stats/semantics are covered by `CacheTests` |
| Debug Center | Manifest cache cases | `调试中心` -> `Manifest 缓存用例` (`debugCenter.openManifestCacheTests`) | `ManifestCacheTestViewController.swift` | `ModuleAvailabilityTests.testDebugCenterChildToolContentAndActionsAreUsable` opens `manifestCacheTest.root`, verifies `manifest_test.url_field`, `manifest_test.mode_segment`, `manifest_test.start_button`, `manifest_test.stats_label`, `manifest_test.log_view`, initial log `Manifest 缓存测试页面已加载`, taps `manifest_test.clear_cache_button`, and verifies `所有缓存已清除`; CacheTests validate manifest semantics | Entry and clear-cache action available; semantics covered by CacheTests | Full smart-load WebView run is not replayed in this report |
| Debug Center | Crash scan guide | `调试中心` -> `崩溃扫描说明` | `DebugCenterViewModel.showCrashScanGuide()` | UI test taps control and remains on Debug Center | Available | Changed from delegated UIKit alert to ResultPanel update |
| Deep Links | Links tool opens | `设置` -> `协议跳转工具` | `DeepLinkHomeView.swift` | UI test opens `deepLink.home` | Available | |
| Deep Links | Open URL builder | `Links` -> target URL / mode / generated scheme | `DeepLinkHomeViewModel.swift` | UI test verifies URL input, generated scheme, mode picker; default local target `/test_resources/cache-showcase.html` returns 200 | Available | Default template now points to an existing cache showcase page |
| Deep Links | Mode switching | `Links` -> `Immersive` | `DeepLinkHomeView.swift` | UI test taps visible label `Immersive` | Available | |
| Deep Links | Validate open scheme | `Links` -> `校验` | `DeepLinkHomeViewModel.validateOpenScheme()` | `ModuleAvailabilityTests.testSettingsDebugCenterAndDeepLinksAreReachable` taps validate and asserts ResultPanel value contains `协议链接合法` and `cache-showcase.html` | Available | ResultPanel now exposes stable accessibility value for message/detail |
| Deep Links | External tab scheme | External `webbridgekit://tab?index=2` | `SuperApp/Sources/AppDelegate.swift` | `xcrun simctl openurl`; after first-open confirmation, XcodeBuildMCP snapshot showed Bridge heading and `bridge.group.cache/navigation` controls | Available on simulator | First open may show the iOS confirmation dialog before the app receives the URL |
| Deep Links | External open URL scheme | External `webbridgekit://open?url=http%3A%2F%2Flocalhost%3A8081%2Ftest_resources%2Fcache-showcase.html` | `SuperApp/Sources/AppDelegate.swift`, `WebBrowserManager.openBrowser` | `xcrun simctl openurl`; XcodeBuildMCP snapshot showed `browserManager.closeButton`; screenshot showed Cache Showcase page | Available on simulator | `localhost` target depends on the local test HTTP service being reachable |
| Deep Links | Command scheme field | External `webbridgekit://command/<id>.<base64url-json>` plus `Links` generated command field | `DeepLinkHomeView.swift`, `AppDelegate.application(_:open:)`, `CommandHandler`, `CommandDecoder`, `CommandParser`, `Server/Sources/WebBridgeServer/Services/CommandService.swift` | Unit tests cover URL-safe server token generation, app command URL decoding, and explicit `webbridgekit` scheme parsing; local backend generated real command URLs; `xcrun simctl openurl` showed `口令识别`; tapping `打开` opened Cache Showcase for HTTP payload and switched to Bridge for `webbridgekit://tab?index=2` payload | Available on simulator for HTTP/HTTPS URL and in-app `webbridgekit` payloads | First run after install may require iOS paste permission; allow paste then re-trigger URL if the permission dialog interrupts parsing |
| Server Admin | Node admin console local source | Local temporary port `/admin`, `/admin-push`, `/admin/api/*`, `/ws/status`, `/messages`, `/packages` | `Server/node/server.js`, `Server/node/admin.html`, `Server/node/admin-push.html` | `tools/verify-node-admin-local.sh`: 11/11 pass | Available locally | This validates source/local Node Admin behavior only |
| Server Admin | Node admin console public deployment | Public `https://wbk.shanbox.19930810.xyz:8443/admin`, `/admin-push`, `/admin/api/*`, `/ws/status`, `/messages`, `/packages` | `Server/node/server.js`, shanbox supervisord/nginx deployment config | `tools/verify-shanbox-backend.sh`: Node admin public routes return 200; `tools/verify-shanbox-supervision.sh`: node_admin=PASS | Available | Public `wbk.shanbox` path-proxies admin routes to supervised remote `webbridge-node-admin` on port `8765` |

## Items Requiring Physical Manual Verification

| Item | Why automation is insufficient | Manual acceptance |
| --- | --- | --- |
| APNs permission and device token | Requires a paid Apple Developer Program team with Push Notifications capability, `aps-environment` entitlement, and real iPhone permission/token observation | After entitlement is configured with a capable team, tap `Push` -> `注册推送`; permission prompt appears if not decided; after allow, APNs state changes to registered or a clear failure is shown |
| Bark end-to-end push delivery | Requires APNs entitlement, a real registered APNs token, reachable backend URL, network, and real device notification permissions | After APNs readiness passes, send Bark-compatible request to backend; iPhone receives notification; tapping notification routes to target URL/app state |
| Physical iOS Settings handoff | Current simulator verifies the row is wired and stable, but did not foreground `com.apple.Preferences`; release still needs a real-device OS check | On iPhone, `设置` -> `通知设置` opens iOS notification settings for SuperApp, or app settings on OS versions without notification-specific settings URL support |
| Physical-device backend reachability | Phone `localhost` is the phone, not the Mac | Configure service URL to Mac LAN IP, for this run `http://192.168.0.4:8080`; backend-dependent features work |
| Background/locked notification behavior | Requires physical lock screen/background state | Notification appears on lock screen/background and tap behavior matches payload |

## Issues Found And Fixed In This Pass

| Issue | Impact | Files |
| --- | --- | --- |
| SwiftUI `Color.init(_:)` fallback recursively called itself on iOS < 15 | Potential runtime crash or hang in older deployment target paths | `SuperApp/Sources/Views/SwiftUIHelpers.swift` |
| Debug Center crash guide relied on delegated UIKit alert and did not appear under UI automation | User could tap the guide and see no visible result | `SuperApp/Sources/Views/DebugCenter/DebugCenterHomeView.swift`, `SuperApp/Sources/Views/DebugCenter/DebugCenterViewModel.swift` |
| SwiftLint warnings drifted back into source | Verification baseline was noisy | `SettingsRow.swift`, `CacheDashboardView.swift`, `ManifestDownloadService.swift`, `SwiftUIHelpers.swift` |
| Existing UI smoke tests still reference old `首页/收信箱/发现` IA | Old tests can produce false negatives or false confidence | New `SuperAppUITests/ModuleAvailabilityTests.swift` verifies current `Web/Push/Bridge/设置` IA |
| API Key examples pointed to official Bark and nonexistent `/v1/pages` route | Users would copy dead examples and fail on production shanbox | `APIKeyExampleViewModel.swift`, `APIKeyExampleViewController.swift`, localized placeholders, `AppDetailViewController.swift`, `docs/system-interaction-guide.md` |
| Server test endpoint timestamp formatter recursively called itself | `/test` success path could recurse instead of returning an ISO8601 timestamp | `Server/Sources/WebBridgeServer/Routes/PushRoutes.swift` |
| Server Push route tests used an unregistered key and did not verify the service-supported test key | `swift test` failed 3 Push route tests, weakening backend availability evidence | `Server/Tests/WebBridgeServerTests/PushRoutesTests.swift` |
| shanbox `WebBridgeServer` process was down during verification | Public `wbk` routes returned 502 until the Swift backend was restarted | Synced Server route fixes to `/root/WebBridgeKit`, rebuilt release, restarted `WebBridgeServer` |
| shanbox backend checks were manual curl commands only | Endpoint availability evidence was easy to drift and hard to rerun consistently | `tools/verify-shanbox-backend.sh`, `build/reports/shanbox-backend-verification.md` |
| About/legal route had weak UI automation coverage and a misleading `MIT License` row label | Settings -> About could pass shallow smoke while the third-party license list/detail path stayed unverified | `SuperApp/Sources/Views/AboutView.swift`, `SuperApp/Sources/Controllers/Settings/AboutViewController.swift`, `SuperApp/Sources/Controllers/Settings/ThirdPartyLicensesViewController.swift`, `SuperApp/Sources/Controllers/Settings/LicenseDetailViewController.swift`, `SuperAppUITests/ModuleAvailabilityTests.swift` |
| UI test helper treated offscreen accessibility elements as visible | XCUITest could tap stale/offscreen coordinates and hit the wrong row on long SwiftUI pages | `SuperAppUITests/ModuleAvailabilityTests.swift` |
| Real-device smoke discovery treated `unavailable` as `available` because of substring matching | Offline phones could be selected and then fail later with confusing CoreDevice errors | `tools/run-real-device-smoke.sh`, `tools/verify-real-device-push-readiness.sh` now exclude unavailable devices |
| Notification settings used the generic app Settings URL instead of the notification-specific URL when available | Users tapping `设置` -> `通知设置` could land in a broader app settings surface instead of notification settings | `SuperApp/Sources/Utilities/NotificationSettingsOpener.swift`, `SuperApp/Sources/Controllers/Tab/SettingsViewController.swift`, `SuperApp/Sources/Controllers/Tab/TabBarController.swift` |
| Notification settings handoff evidence was overstated | Current simulator verifies the row is wired and non-crashing, but does not prove `com.apple.Preferences` foregrounding; release evidence now correctly requires a real-device/manual check | `SuperAppUITests/ModuleAvailabilityTests.swift`, `docs/verification/module-availability-verification.md` |
| Local services died after the agent shell exited | `bash scripts/services.sh start` could pass in the start command but fail in the next command, making cache/deep-link verification flaky | `scripts/services.sh` now launches backend, test HTTP, and prototype servers as per-user `launchctl` jobs |
| Deep Link default cache template pointed to a missing file | `webbridgekit://open` demo opened a browser container but showed a 404 for `/test_resources/cache-demo.html` | `SuperApp/Sources/Views/DeepLinks/DeepLinkHomeViewModel.swift` now points to `/test_resources/cache-showcase.html`, verified 200 |
| Bark/Push route evidence only checked shallow HTTP 200s | A route could return 200 while response semantics, encoded Bark URLs, POST compatibility, or optional payload fields stayed unverified | `tools/verify-shanbox-backend.sh`, `Server/Tests/WebBridgeServerTests/PushRoutesTests.swift`, `docs/verification/module-availability-verification.md`, `AGENTS.md` |
| Push test endpoint logs used dynamic strings as NSLog format strings | Percent-encoded URLs such as `%3A%2F%2F` were mangled in server logs, weakening debug evidence | `Server/Sources/WebBridgeServer/Routes/PushRoutes.swift` |
| shanbox WebBridgeServer supervision was assumed from a stale systemd unit file | Replaced the manual backend process with a supervisord-managed `webbridgeserver` program and made verification check the actual supervisor | `tools/verify-shanbox-supervision.sh`, `build/reports/shanbox-supervision-verification.md`, `AGENTS.md`, remote `/etc/supervisor/supervisord.conf` |
| AppDelegate discarded real APNs device tokens | Push UI could remain `未注册` even if APNs registration succeeded, and Bark server registration would not run through `PushNotificationManager` | `SuperApp/Sources/AppDelegate.swift`, `tools/verify-real-device-push-readiness.sh` |
| Real-device APNs readiness was tracked as manual-only | Automatic evidence now shows hard blockers separately: project entitlement presence, provisioning profile Push capability, signed app entitlements, and manual notification observation | `tools/verify-real-device-push-readiness.sh`, `build/reports/real-device-push-readiness.md` |
| Project had no APNs entitlement file | Push readiness could not even request the Push Notifications capability | `SuperApp/SuperApp.entitlements`, `project.yml`; current blocker moved to Apple Developer Team/provisioning profile support |
| Real-device smoke could reuse a stale `SuperApp.app` after build failure | Install/launch rows could look green even when the current build failed | `tools/run-real-device-smoke.sh` now clears DerivedData before build and skips install/launch if build fails |
| SuperApp cannot be real-device smoke tested under the current Personal Development Team | Both the production bundle id and a temporary no-push command-line bundle id failed before producing `SuperApp.app` because Xcode still requires Push Notifications capability for this target | `build/reports/build-for-device.log`, `build/reports/real-device-nopush-override.log`; use a paid Apple Developer Program team/App ID/profile with Push Notifications enabled before marking real-device SuperApp install/launch, APNs registration, or Bark delivery available |
| Command token custom-scheme payloads were rejected | `webbridgekit://command/<token>` with payload `webbridgekit://tab?index=2` failed as `invalidURL` before the App command parser allowlist included `webbridgekit`; `CommandHandler` now applies the App command parser config before parsing and EngineBootstrap reuses the same config | `SuperApp/Sources/Managers/CommandHandler.swift`, `SuperApp/Sources/Managers/EngineBootstrap.swift`, `Tests/CommandParserTests/CommandParserTests.swift` |
| Token Push copy URL button was not reliably tappable under XCUITest | The UI test could find the icon control but tapping it left ResultPanel in `Idle`, so the copy action was not proven | `TokenPushHomeView.swift` now keeps the icon-only control as a concrete Button with a 52x44 hit target, content shape, accessibility label, and direct UI assertion |
| ResultPanel message/detail were not stable accessibility evidence | Long-page SwiftUI Text identifiers were not reliably discoverable, so result semantics could not be asserted | `ResultPanel.swift` now exposes message/detail through the panel accessibility value; `ModuleAvailabilityTests` asserts Push copy and Deep Link validation result content |
| JSBridge callback IDs were inconsistent between JS and native | Real WKWebView Promise calls could send `messageId` while native only returned `callbackId`, leaving callbacks unable to resolve reliably | `Resources/WebBridge.js`, `SuperApp/Resources/WebBridge.js`, `Sources/Core/WebJavaScriptBridge.swift` now send/read/return both IDs for compatibility |
| Browser WKWebView JavaScript enablement was implicit after deprecated preference cleanup | Real fixture pages could fail silently if per-page content JavaScript was not enabled | `Sources/ViewModels/WebBrowserViewModel.swift` sets `defaultWebpagePreferences.allowsContentJavaScript = true`; `Sources/Controllers/WebBrowserViewController+Navigation.swift` also enables it in the navigation preferences delegate |
| Web Cache `在线` mode could reuse stale persistent manifest cache | Opening the same persistent URL for a real WebView smoke could serve an older cached HTML instead of the current fixture | `Sources/Handlers/ManifestLoader/LazyManifestLoader.swift` now forwards `forceRefresh`; `Sources/Handlers/ManifestLoader/PersistentManifestLoader.swift` skips existing persistent cache when `forceRefresh == true` |
| UI automation had no stable handle for the browser WKWebView | Tests could prove the browser shell opened but not that a concrete WebView was present | `Sources/Controllers/WebBrowserViewController.swift` sets `browserManager.webView`; `ModuleAvailabilityTests.testRealWebViewBridgePromiseResolves` asserts it exists |
| Simulator destination by name can select the wrong runtime/device during repeated runs | A by-name run can fail for environment reasons even when the booted test simulator is healthy | Current evidence pins destination UDID `79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0` |
| A single long Settings row UI test triggered XCTest high-log-volume SIGSEGV during automation | `CrashLogManager` recorded a SIGSEGV from `XCTAutomationSupport` after the old long `testSettingsOperationalRowsAreReachable` produced excessive repeated snapshot queries; crash gate became red even though the user-facing row routes were valid | `SuperAppUITests/ModuleAvailabilityTests.swift` splits the row coverage into `testSettingsCoreRowsAreReachable` and `testSettingsDebugAndSupportRowsAreReachable`, keeps About in its dedicated deep-drill test, reduces broad navigation/scroll snapshot queries, and the full module suite now passes 14/14 with crash scan `total: 0` |
| Debug Center child tools only had entry-level evidence | A child row could open a shell while the expected content or primary action stayed broken | `SuperAppUITests/ModuleAvailabilityTests.testDebugCenterChildToolContentAndActionsAreUsable` now verifies diagnostics copy result, network seeded row plus clear action, and Manifest cache controls/log clear action; `DiagnosticsView.swift`, `NetworkDebugViewController.swift`, and `ManifestCacheTestViewController.swift` expose stable accessibility evidence |

## Remaining Unavailable And Manual-Only Items

| Item | Status | Required next evidence |
| --- | --- | --- |
| Push Notifications provisioning profile is unavailable | Unavailable | Use a paid Apple Developer Program team/App ID with Push Notifications enabled, regenerate provisioning profile, rebuild for device, and verify signed app contains `aps-environment` |
| SuperApp real-device install/launch is blocked by Push capability signing | Unavailable in current signing environment | Use a Push-capable Apple Developer Program team/profile; temporary command-line no-push override with `com.webbridgekit.superapp.nopush` still failed, so do not claim non-push real-device SuperApp smoke until an installable app bundle is produced |
| Bark/APNs end-to-end delivery is unavailable | Unavailable | After APNs signing passes, register a real iPhone token to shanbox, send a Bark-compatible request, verify notification receipt and tap routing |
| Physical iOS Settings handoff not proven on real device | Manual-only | On iPhone, tap `设置` -> `通知设置` and verify iOS opens the SuperApp notification settings page or documented fallback |

## Remaining Non-Blocking Debt

| Debt | Status | Path |
| --- | --- | --- |
| Design lint warning: hardcoded system font | Non-blocking warning | `Sources/Models/ManifestModels.swift:410` |
| Design lint warning: hardcoded system font | Non-blocking warning | `Sources/Extensions/UIImageView+LetterIcon.swift:26` |
| Design lint warning: deprecated `ThemeBadge` init | Non-blocking warning | `SuperApp/Sources/Controllers/ComponentCatalog/ComponentSections.swift:101` |
| Design lint warning: deprecated `ThemeBadge` init | Non-blocking warning | `SuperApp/Sources/Controllers/Showcase/ThemeShowcaseViewController.swift:114` |
| Design lint warning: deprecated `ThemeBadge` init | Non-blocking warning | `SuperApp/Sources/Controllers/ComponentCatalog/ActionSections.swift:223` |
| Some long-page ResultPanel message assertions remain fragile in XCUITest because nested SwiftUI ScrollViews stay in the hierarchy | Push copy and Deep Link validate now assert ResultPanel accessibility values; Bridge Lab remains a validation surface, while real WebView Promise execution is covered by `testRealWebViewBridgePromiseResolves` | `BridgeLabHomeView.swift` |
| Bridge Lab result assertion awaits a clean local simulator rebuild | Current source adds a dedicated `bridge.resultPanel` accessibility identifier and focused assertions for `命令已完成结构化校验` plus `cache.stats`, but the 2026-06-04 focused UI rerun failed before tests because `AssetCatalogSimulatorAgent` could not load `CoreThemeDefinition.framework` under current CoreSimulator system policy | `ResultPanel.swift`, `BridgeLabHomeView.swift`, `ModuleAvailabilityTests.swift`, `/tmp/wbk-dd-bridge-focused/Logs/Test/Test-SuperApp-2026.06.03_23-57-06-+0800.xcresult` |

## Current Availability Verdict

No confirmed unavailable non-push in-app navigation entry is currently listed after this pass.

The items not marked fully available are real-device/system-level flows, Push/Bark APNs delivery, phone-specific network behavior, and partial interaction assertions:

- Push-capable Apple Developer Team/provisioning profile
- Signed-app `aps-environment` entitlement proof
- SuperApp real-device install/launch under the current signing environment
- APNs registration on physical iPhone
- Bark end-to-end notification delivery to a real APNs token
- Real-device notification settings handoff
- Background/lock-screen notification behavior
- Phone-specific backend reachability and LAN/firewall/VPN differences outside simulator
- Bridge Lab UI execute remains validation-only and the stronger `bridge.resultPanel` result assertion is awaiting a clean simulator rebuild; production WebView JSBridge Promise execution is now proven on simulator
- Debug Center diagnostics share/export-file payload content and Manifest full smart-load WebView execution are not deeply asserted in this report; diagnostics copy, network seeded content/clear, and manifest clear-cache action are now proven by UI automation
