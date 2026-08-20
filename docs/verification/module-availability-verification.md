# Module Availability Verification Report

## Next Phase Integration Evidence (2026-08-12)

The combined official-first-run, self-hosted gateway, and strong-offline integration is recorded in `docs/verification/next-phase-acceptance.md`. Core evidence: Server 36/36, message types 15/15, approval 11/11, public gateway 5/5, AppTemplate 5/5, CI lint 17/17, and crash scan `total: 0`. The simulator/open-source verdict is GO-WITH-MANUAL-GATE; real APNs permission, token registration, delivery, background and lock-screen behavior remain physical manual requirements.

Date: 2026-06-04 03:08 CST
Commit under test: `32b57b` plus current Debug Center deep-evidence refresh
Simulator: `iPhone 16 Pro UI Test`, iOS Simulator 18.3.1, command destination `platform=iOS Simulator,id=79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0`<br>
Physical device: `许映洲的iPhone`, iPhone 13, identifier `F38FECA2-2A43-5554-B65D-9990CEEAB0EA`, currently `connected` to Xcode CoreDevice

## Summary

| Area | Status | Evidence |
| --- | --- | --- |
| SDK semantics | Available on simulator | Reusable framework behavior remains covered by module schemes (`CacheTests`, `BridgeTests`, `MessageTests`, and related SDK suites); `bash tools/verify-deliverable-boundaries.sh` prevents SDK sources from importing `SuperApp` product code |
| AppTemplate starter readiness | Available on simulator | `bash tools/run-template-gate.sh` -> 5 passed, 0 failed on 2026-08-12; independently checks 6/6 layer boundaries, AppTemplate SwiftLint, Debug/Release simulator builds, credential scanning, and absence of showcase tabs from the release surface; report: `build/reports/template-gate.md` |
| SuperApp simulator readiness | Available | `bash tools/run-release-gate.sh` -> 8 passed, 0 failed on 2026-08-12, covering local services, layer boundaries, SwiftLint, design lint, Debug build, crash scan, unsigned Release archive, and release-bundle HTML scan; report: `build/reports/release-gate.md`; this state does not depend on AppTemplate UI snapshots |
| SuperApp real-device/APNs readiness | Unavailable in current signing environment | `bash tools/run-real-device-smoke.sh` and `bash tools/verify-real-device-push-readiness.sh` remain the separate physical-device gates; current Personal Development Team provisioning does not satisfy Push Notifications capability |
| Services | Available | `bash scripts/services.sh restart && bash scripts/services.sh verify` passed, ports 8080/8081/8083 healthy; launchctl-backed services remain available across separate shell commands |
| SwiftLint | Available | `swiftlint --quiet` produced zero output |
| Crash gate | Available | `bash scripts/scan-crash-logs.sh --json` -> `{"diagnostic_reports":0,"app_crash_logs":0,"total":0}` |
| Design lint | Available with warnings | `bash tools/ci-lint.sh` passed 16/16 checks, 0 errors, 5 warnings |
| Module UI availability | Available | `ModuleAvailabilityTests`: 14 tests, 0 failures on UDID `79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0`; full rerun includes Push/Bark, Bridge Lab, and Deep Link result-panel paths, plus affected focused reruns on the same UDID; latest focused rerun `Test-SuperApp-2026.06.04_03-06-36-+0800.xcresult` proves Debug Center diagnostics export-file action, network clear action, and Manifest smart-load WebView execution |
| JSBridge real WebView Promise smoke | Available | `testRealWebViewBridgePromiseResolves` opens `bridge-promise-smoke.html`, executes `BarkBridge.callNative('getSystemInfo')`, and waits for DOM text `Bridge Promise OK` |
| Module availability report guard | Available | `bash tools/verify-module-availability-report.sh`; all `SettingsAction` entries are represented in the report and current unavailable markers plus shanbox command token semantics are enforced |
| Settings remember-last-app restore | Available | `SettingsPreferenceKeys` now centralizes `settings.rememberLastApp` and `settings.lastOpenedURL`; `TabBarController`, `WebAccessViewController`, and `MainViewController` use the same keys with legacy migration |
| Settings Appearance entry | Available | `settings.cell.appearance` now opens `AppearanceSettingsView`; `ThemeMode` selection is persisted to `settings.appearanceMode` and applied through `ThemeManager` |
| Cache semantics | Available | `CacheTests`: 548 tests, 0 failures |
| JSBridge semantics | Available | `BridgeTests`: 101 tests, 0 failures |
| Bark/Push/message semantics | Available | `MessageTests`: 226 tests, 0 failures |
| Server route semantics | Available | `cd Server && swift test` passed 16 tests, 0 failures |
| Physical device install and launch | Unavailable for SuperApp in current signing environment | `xcrun devicectl list devices` shows the paired iPhone as `connected`; `bash tools/run-real-device-smoke.sh` -> 1 passed, 2 failed because the Personal Development Team provisioning profile does not support Push Notifications; a no-push command-line override with bundle id `com.webbridgekit.superapp.nopush` also failed before producing `SuperApp.app` |
| Real-device Push/APNs readiness | Unavailable | `bash tools/verify-real-device-push-readiness.sh` -> 6 passed, 3 failed, 4 manual on 2026-06-03 00:52 CST; `project.yml` points to `SuperApp/SuperApp.entitlements`, but the current Personal Development Team/provisioning profile does not support Push Notifications or `aps-environment` |
| shanbox Swift backend + Node admin public routes | Available | `bash tools/verify-shanbox-backend.sh` -> 27 passed, 0 failed, 0 unavailable, report date 2026-06-04 01:53 CST; includes `Command token semantics` asserting URL-safe command token payload decoding |
| shanbox WebBridgeServer + Node admin supervision | Available | `bash tools/verify-shanbox-supervision.sh` -> process=PASS, supervision=PASS, node_admin=PASS via supervisord, report date 2026-06-04 01:53 CST |
| shanbox static fixtures for phone WebView/cache/JSBridge | Available for public reachability/content markers | `bash tools/verify-shanbox-fixtures.sh` -> 18 passed, 0 failed, report date 2026-06-04 01:53 CST; verifies `bridge-hub.html`, `bridge-promise-smoke.html`, `cache-showcase.html`, `WebBridge.js`, manifest, CSS/JS/image resources on `https://ae8fcb.shanbox.19930810.xyz:8443/test_resources` |
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
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0' \
  -derivedDataPath /tmp/wbk-dd-module-availability \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:SuperAppUITests/ModuleAvailabilityTests \
# Result: TEST SUCCEEDED, 14 tests, 0 failures, xcresult:
# Date: 2026-06-04 01:42 CST
# /tmp/wbk-dd-module-availability/Logs/Test/Test-SuperApp-2026.06.04_01-36-26-+0800.xcresult
```

```bash
xcodebuild test -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0' \
  -derivedDataPath /tmp/wbk-dd-module-availability \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:SuperAppUITests/ModuleAvailabilityTests/testTokenPushAndBarkControlsAreUsable \
  -only-testing:SuperAppUITests/ModuleAvailabilityTests/testBridgeLabControlsAreUsable \
  -only-testing:SuperAppUITests/ModuleAvailabilityTests/testSettingsDebugCenterAndDeepLinksAreReachable
# Result: TEST SUCCEEDED, 3 tests, 0 failures
# Date: 2026-06-04 01:33 CST
# xcresult:
# /tmp/wbk-dd-module-availability/Logs/Test/Test-SuperApp-2026.06.04_01-31-30-+0800.xcresult
#
# UI assertion:
# Push opens Token Manager, API Key Manager, Notification Debug, copies the shanbox Bark URL, and validates Bark payload.
# Bridge Lab taps `执行校验` and verifies `命令已完成结构化校验` plus `cache.stats`.
# Deep Link validates the generated open URL and verifies `协议链接合法` plus `cache-showcase.html`.
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
# Result: 100 passed, 0 failed
# Report: build/reports/module-availability-report-check.md
#
# Scope:
# - Verifies required report sections and core module rows are present.
# - Extracts all 15 `SettingsAction` cases from `SettingsViewModel.swift`.
# - Requires every Settings action to appear as a `settings.cell.*` row in the module report.
# - Requires known unavailable markers for current APNs/Push provisioning blockers.
# - Requires Appearance and remember-last-app restore to be marked available when source implementation is present.
# - Requires real WebView JSBridge evidence plus Debug Center concrete child-entry/content/action evidence.
# - Requires public shanbox fixture evidence for physical-phone WebView/cache/JSBridge pages.
# - Requires shanbox command token semantics evidence: URL-safe token and decoded payload.
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
XcodeBuildMCP test_sim \
  -destination 'platform=iOS Simulator,id=BDD44ED8-3763-483C-971F-259E5BAB6B47' \
  -derivedDataPath /tmp/wbk-dd-bridge-focused-17pro \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:SuperAppUITests/ModuleAvailabilityTests/testBridgeLabControlsAreUsable
# Result: TEST SUCCEEDED, 1 test, 0 failures
# Date: 2026-06-04 00:59 CST
# xcresult:
# /Users/xuyingzhou/Library/Developer/XcodeBuildMCP/workspaces/WebBridgeKit-815a0cec42de/result-bundles/test_sim_2026-06-03T16-59-21-966Z_pid29096_fd7b7ac0.xcresult
#
# UI assertion:
# Bridge Lab taps `执行校验`; `resultPanel.message` / result detail text expose visible evidence containing `命令已完成结构化校验` and `cache.stats`.
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
# Result: 27 passed, 0 failed, 0 unavailable/needs deployment
# Date: 2026-06-04 00:37 CST
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
# - ASSERT Command token semantics == url-safe token, decoded payload ok
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
# Date: 2026-06-04 00:38 CST
# Report: build/reports/shanbox-supervision-verification.md
#
# Evidence:
# - WebBridgeServer process exists and listens on remote :8080
# - Remote PID 1 is `supervisord`
# - `supervisorctl status webbridgeserver` reports RUNNING
# - Node admin process `webbridge-node-admin` listens on remote :8765 and is supervised by supervisord
# - Public route verification passes 27/27 after path-proxying admin routes to Node and validating command token semantics
```

```bash
bash tools/verify-shanbox-fixtures.sh
# Result: 18 passed, 0 failed
# Date: 2026-06-04 00:13 CST
# Report: build/reports/shanbox-fixtures-verification.md
#
# Verified public static fixtures:
# - /index.html
# - /bridge-hub.html
# - /bridge-promise-smoke.html
# - /cache-showcase.html
# - /engine-dashboard.html
# - /all-in-one-tester.html
# - /message-showcase.html
# - /websocket-showcase.html
# - /bridge-device.html
# - /bridge-interaction.html
# - /bridge-cache.html
# - /manifest_demo.html
# - /image_cache_test.html
# - /WebBridge.js
# - /manifest.json
# - /css/styles.css
# - /js/app.js
# - /images/logo.png
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
| PWA Apps | 官方服务零配置启动 | Bottom tab `应用` | `PWAAppCenterViewController.swift`, `HTMLAppGatewayDefaults`, `HTMLAppGatewayOnboardingService` | `HTMLAppGatewayConfigurationTests` + `HTMLAppGatewayOnboardingTests`: 11/11; `tools/verify-open-gateway.sh`: 5/5; `ModuleAvailabilityTests.testPWAAppCenterStartsWithOfficialServiceInsteadOfGatewaySetup` | Available at public gateway contract level | 官方版自动验证受签名清单；自部署网关导入保持可选，不把设置负担给普通用户 |
| PWA Apps | 自部署网关导入 | `应用` -> `自有服务` -> 扫码或粘贴 -> 验证确认 | `GatewayConfigurationViewController.swift`, `HTMLAppGatewayOnboardingService.swift` | `ModuleAvailabilityTests.testGatewayConfigurationImportsPastePayload` passed on simulator | Available | 配置只含公开端点和公钥；切换或删除时撤销旧网关的 PWA 信任与能力授权 |
| Notifications | Primary tab loads | Bottom tab `通知` | `InboxViewController.swift`, `TabBarController.swift` | `ModuleAvailabilityTests.testPrimaryTabsExposeCurrentInformationArchitecture` passed on simulator | Available | Persistent cross-PWA notification history, unread state, grouping and route context |
| Notifications | Message Types v1 native rendering | `通知` -> plain / Markdown / image / QR code / verification code / chat detail | `MessageDetailViewController.swift`, `MessageMediaCardView.swift`, `TestDataSeeder+Entities.swift`, `PushRoutes.swift` | `tools/verify-message-types-v1.sh`: 15/15; focused UI regressions: 10/10; `MessagePayloadTests`: 14/14 | Available on simulator and local backend | Each type has explicit required fields and a readable native fallback; incomplete canonical payloads and raw inline HTML are rejected |
| Notifications | Image loading failure fallback | `通知` -> image detail with unavailable remote asset | `MessageMediaCardView.swift` | `DeepVerificationTests.testInboxImageFailureUsesCompactReadableFallback`: passed; screenshot `/tmp/wbk-ui-inbox-type-image-failure.png` | Available on simulator | Failure state stays compact and preserves title/body readability |
| Notifications | Native approval response | `通知` -> native approval detail -> choose action -> confirm | `MessageDetailViewController+Approval.swift`, `ApprovalResponseClient.swift`, `ApprovalRoutes.swift`, `ApprovalStore.swift` | `DeepVerificationTests.testInboxNativeApprovalShowsActionsAndConfirmation`: 1/1; `tools/verify-approval-v1.sh`: 11/11; server tests: 31/31 | Available on simulator and local backend | First valid response wins; resolved state persists and remains visible after reopening. Physical APNs delivery is not implied |
| Notifications | Web/PWA approval handoff | `通知` -> web or PWA presentation | `MessageDetailViewController+Actions.swift`, `PushRelayManager.swift`, `PushRoutes.swift` | `tools/verify-approval-v1.sh` validates native, web, and PWA payload contracts | Available at route-contract level | Web/PWA owns its interaction lifecycle; raw inline HTML is rejected |
| Web Cache | URL input and open button | `设置` -> `调试中心` -> `网页缓存调试` -> target URL -> `打开` | `WebCacheHomeView.swift`, `WebCacheHomeViewModel.swift` | UI test verifies `webCache.urlInput`, `webCache.openButton` | Available in DEBUG | Network result still depends on service/LAN config on physical phone |
| Web Cache | Online/cache-first/full-offline mode selection | `调试中心` -> `网页缓存调试` -> `在线/缓存优先/完全离线` | `WebCacheModePicker.swift` | `testWebCacheCriticalControlsAreUsableFromDeveloperTools` taps all 3 modes | Available in DEBUG | UI mode switching verified |
| Web Cache | Cache dashboard | `调试中心` -> `网页缓存调试` -> `缓存仪表盘` | `CacheDashboardViewController.swift`, `CacheDashboardView.swift` | UI test opens dashboard; `CacheTests` validates stats/cache systems | Available in DEBUG | |
| Web Cache | Cache management | `调试中心` -> `网页缓存调试` -> `缓存管理` | `ManagementViewController.swift`, `CacheManagementViewController.swift` | UI test opens segmented management screen | Available in DEBUG | |
| Web Cache | Clear all confirmation | `调试中心` -> `网页缓存调试` -> `清理全部缓存` | `WebCacheHomeViewModel.clearAllCache()` | UI test verifies confirmation sheet and cancel action | Available in DEBUG | Destructive confirm is visible |
| Web Cache | Resource/manifest/offline storage semantics | Non-UI cache APIs | `Sources/Cache/` | `CacheTests`: 548/548 | Available | Includes manifest, URL scheme, resource cache, stats |
| Web Cache | Public phone cache fixtures | Physical iPhone WebView target `https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/cache-showcase.html` and related static resources | `test_resources/cache-showcase.html`, `test_resources/manifest.json`, `test_resources/css/styles.css`, `test_resources/js/app.js`, `test_resources/images/logo.png`, `tools/verify-shanbox-fixtures.sh` | `tools/verify-shanbox-fixtures.sh`: Cache showcase, manifest JSON, CSS, JS, and image resource all returned HTTP 200 with expected content markers | Available for public fixture reachability | Does not prove full offline cache completion on a physical iPhone; native/cache semantics remain covered by `CacheTests` and simulator UI evidence |
| Push/Bark | Developer tools load | `设置` -> `调试中心` -> `Push 与 Bark 调试` | `TokenPushHomeView.swift`, `TabBarController.swift` | `ModuleAvailabilityTests.testTokenPushAndBarkControlsAreUsableFromDeveloperTools` passed on simulator | Available in DEBUG | Not exposed as a production bottom tab; `tokenPush.home` is a stable UI-test root |
| Push/Bark | Access token manager | `调试中心` -> `Push 与 Bark 调试` -> `访问口令` | `TokenManageViewController.swift` | UI test opens screen | Available in DEBUG | |
| Push/Bark | Bark API/API key manager | `调试中心` -> `Push 与 Bark 调试` -> `Bark API / API Key` | `APIKeyManageViewController.swift` | UI test opens screen | Available in DEBUG | |
| Push/Bark | Notification debug entry | `调试中心` -> `Push 与 Bark 调试` -> `Bark 推送调试` | `NotificationDebugViewController.swift` | UI test opens screen in Debug build | Available in DEBUG | |
| Push/Bark | Copy Bark-compatible push URL | `调试中心` -> `Push 与 Bark 调试` -> copy icon beside push URL | `TokenPushHomeViewModel.copyPushURL()` | `ModuleAvailabilityTests.testTokenPushAndBarkControlsAreUsableFromDeveloperTools` asserts the app-visible copied URL result; MessageTests cover routing/payload semantics | Available in DEBUG | XCUITest cannot reliably read the app process pasteboard |
| Push/Bark | Bark payload validation | `调试中心` -> `Push 与 Bark 调试` -> `校验 Bark Payload` | `TokenPushHomeViewModel.validatePayload()`, `PushPayload.swift` | UI test taps control; `MessageTests` validates Bark/push payload behavior | Available in DEBUG | |
| Push/Bark | shanbox health and JSON push route | External `https://wbk.shanbox.19930810.xyz:8443` | `Server/Sources/WebBridgeServer/Routes/HealthRoutes.swift`, `PushRoutes.swift` | `tools/verify-shanbox-backend.sh`: `/health`, `/register`, `/push`, JSON response code assertions | Available for route-level checks | This uses a fake device token, so APNs delivery is not proven |
| Push/Bark | shanbox Bark-compatible URL | External `/{key}/{title}/{body}` | `Server/Sources/WebBridgeServer/Routes/PushRoutes.swift` | `tools/verify-shanbox-backend.sh`; `Server/PushRoutesTests` verify GET, POST, encoded Chinese title/body, and query parameters | Available for route-level checks | Uses service test key; real APNs delivery still requires a real registered token |
| Push/Bark | shanbox test endpoint | External `POST /test` | `Server/Sources/WebBridgeServer/Routes/PushRoutes.swift` | `tools/verify-shanbox-backend.sh` asserts `success == true`; `Server/PushRoutesTests.testPushEndpointReportsSuccess` | Available for route-level checks | Route-level semantic success verified; APNs delivery still requires real token |
| Push/Bark | APNs registration | `调试中心` -> `Push 与 Bark 调试` -> `注册推送` | `PushNotificationManager.swift`, `AppDelegate.swift`, project entitlements | `tools/verify-real-device-push-readiness.sh`: project entitlement passes, provisioning profile and signed-app entitlement fail | Unavailable | Token forwarding is fixed and `SuperApp/SuperApp.entitlements` contains `aps-environment`; current Personal Development Team/provisioning profile rejects Push Notifications, so APNs cannot be marked ready |
| Push/Bark | Bark/APNs end-to-end delivery | Bark-compatible request -> shanbox -> APNs -> iPhone notification -> tap action | `PushNotificationManager.swift`, `BarkChannel`, `PushRoutes.swift`, APNs provisioning | `tools/verify-real-device-push-readiness.sh` marks Bark delivery as MANUAL and APNs signing as failed | Unavailable in current signing environment | Bark/APNs end-to-end delivery is unavailable until a Push-capable Apple Developer Program team/profile signs the app and a real device token is registered |
| Bridge | Developer lab loads | `设置` -> `调试中心` -> `Bridge 实验室` | `BridgeLabHomeView.swift` | `ModuleAvailabilityTests.testBridgeLabControlsAreUsableFromDeveloperTools` passed on simulator | Available in DEBUG | Bridge Lab is not exposed as a production bottom tab |
| Bridge | Command JSON entry and execute control | `调试中心` -> `Bridge 实验室` -> `执行校验` | `BridgeLabHomeView.swift`, `BridgeLabViewModel.swift`, `ResultPanel.swift`, `CodeBlockView.swift`, `ModuleAvailabilityTests.swift` | `ModuleAvailabilityTests.testBridgeLabControlsAreUsableFromDeveloperTools` verifies `命令已完成结构化校验` and `cache.stats`; `BridgeTests` validates registry/core semantics | Available in DEBUG | Bridge Lab is a validation surface, not the production WebView execution path |
| Bridge | Real WebView JSBridge Promise execution | `设置` -> `调试中心` -> `网页缓存调试` -> `在线` -> open `bridge-promise-smoke.html` | `WebJavaScriptBridge.swift`, `Resources/WebBridge.js`, `SuperApp/Resources/WebBridge.js`, `WebBrowserViewController.swift`, `test_resources/bridge-promise-smoke.html` | `ModuleAvailabilityTests.testRealWebViewBridgePromiseResolves` | Available on simulator | Proves page JS -> native `getSystemInfo` -> JS Promise resolve -> DOM text `Bridge Promise OK` |
| Bridge | Public phone JSBridge fixture pages | Physical iPhone WebView target `https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-hub.html` and linked Bridge pages | `test_resources/bridge-hub.html`, `bridge-promise-smoke.html`, `bridge-device.html`, `bridge-interaction.html`, `bridge-cache.html`, `WebBridge.js`, `tools/verify-shanbox-fixtures.sh` | `tools/verify-shanbox-fixtures.sh`: Bridge hub, Bridge Promise smoke, Bridge device, Bridge interaction, Bridge cache, and `WebBridge.js` returned HTTP 200 with expected content markers | Available for public fixture reachability | Does not prove native Bridge execution on physical iPhone; simulator real WebView Promise smoke and `BridgeTests` cover execution semantics |
| Bridge | Handler registry and metadata | Non-UI JSBridge APIs | `Sources/Bridge/`, `Sources/Handlers/` | `BridgeTests`: 101/101 | Available | |
| Commands | shanbox command generation | External `POST /api/v1/commands` | `Server/Sources/WebBridgeServer/Routes/CommandRoutes.swift`, `Server/Sources/WebBridgeServer/Services/CommandService.swift` | `tools/verify-shanbox-backend.sh`: `Command generation` and `Command token semantics` both pass; `Server/CommandRoutesTests` | Available | Public endpoint returns a signed `webbridgekit://command/<id>.<base64url-json>` token; verifier decodes payload and rejects `+`, `/`, or `=` padding in the token payload |
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
| Settings | Export diagnostics direct entry | `设置` -> `诊断导出` (`settings.cell.exportDiagnostics`) | `DiagnosticsView.swift`, `TabBarController.handleSettingsNavigation(_:)`, `SettingsViewModel.swift` DEBUG-only section | `ModuleAvailabilityTests.testSettingsDebugAndSupportRowsAreReachable` taps direct row and verifies concrete presentation | Available in DEBUG | Direct entry is reachable; the settings row itself is DEBUG-only, so Release builds no longer render a row whose tap was previously a silent no-op |
| Settings | Cache dashboard | `设置` -> `缓存仪表盘` (`settings.cell.cacheDashboard`) | `CacheDashboardViewController.swift` | `ModuleAvailabilityTests.testSettingsDebugAndSupportRowsAreReachable` opens screen | Available | |
| Settings | About/legal | `设置` -> `关于` (`settings.cell.about`) -> `第三方开源许可` -> `Alamofire` | `AboutView.swift`, `ThirdPartyLicensesViewController.swift`, `LicenseDetailViewController.swift` | `ModuleAvailabilityTests.testSettingsAboutLegalDeepDrillIsReachable` opens About, license list, and license detail | Available | Deep drill now asserted with accessibility identifiers |
| Settings | Notification settings entry | `设置` -> `通知设置` (`settings.cell.notificationSettings`) | `NotificationSettingsOpener.open()` using `UIApplication.openNotificationSettingsURLString` on iOS 16+ and app Settings fallback below iOS 16 | `ModuleAvailabilityTests.testNotificationSettingsEntryIsWiredWithoutCrashing` taps the row and verifies either iOS Settings foregrounds or the app remains stable in foreground | Entry available; system handoff not proven in current simulator | The UI entry is wired and non-crashing. Current simulator did not foreground `com.apple.Preferences`, so real iOS Settings handoff still requires physical/manual confirmation |
| Debug Center | Debug home | `设置` -> `调试中心` (`settings.cell.debugCenter`) | `DebugCenterHomeView.swift` | UI test opens `debugCenter.home` | Available | |
| Debug Center | Global debug panel | `调试中心` -> `全局调试面板` (`debugCenter.openDebugPanel`) | `DebugPanelViewController.swift` | `ModuleAvailabilityTests.testDebugCenterGlobalDebugPanelEntryOpensPanel` opens `debugPanel.root`, verifies `debugPanel.tab.0`, and verifies `debugPanel.handlers.tableView` | Available in DEBUG | Proves the Debug Center entry opens the actual panel shell and handler list |
| Debug Center | Diagnostics export | `调试中心` -> `诊断导出` (`debugCenter.openDiagnostics`) | `DiagnosticsView.swift` | `ModuleAvailabilityTests.testDebugCenterChildToolEntriesOpenConcreteScreens` opens `diagnostics.root`; `ModuleAvailabilityTests.testDebugCenterChildToolContentAndActionsAreUsable` verifies `系统信息`, `导出工具`, taps `复制到剪贴板`, asserts `diagnostics.lastAction` contains `已复制到剪贴板`, taps `diagnostics.action.1.1`, and asserts `diagnostics.lastAction` contains `诊断文件已生成`; direct Settings row also opens diagnostics | Copy and export-to-file actions available in DEBUG | System share sheet presentation is manual-only/not fully asserted by XCUITest |
| Debug Center | Network inspector | `调试中心` -> `网络请求` (`debugCenter.openNetworkInspector`) | `NetworkDebugViewController.swift` | `ModuleAvailabilityTests.testDebugCenterChildToolContentAndActionsAreUsable` opens `networkDebug.tableView`, verifies `networkDebug.cell.0`, sample URL `https://api.example.com/manifest`, method `GET`, status `200`, taps `networkDebug.clearButton`, and verifies `暂无网络请求记录` | Available in DEBUG | Verifies seeded capture content and clear-to-empty behavior; live traffic capture is not replayed here |
| Debug Center | Cache dashboard | `调试中心` -> `缓存仪表盘` (`debugCenter.openCacheDashboard`) | `CacheDashboardViewController.swift` | `ModuleAvailabilityTests.testDebugCenterChildToolEntriesOpenConcreteScreens` opens `cacheDashboard.root` | Available | Cache stats/semantics are covered by `CacheTests` |
| Debug Center | Manifest cache cases | `调试中心` -> `Manifest 缓存用例` (`debugCenter.openManifestCacheTests`) | `ManifestCacheTestViewController.swift`, `WebViewDisplayViewController.swift` | `ModuleAvailabilityTests.testDebugCenterChildToolContentAndActionsAreUsable` opens `manifestCacheTest.root`, verifies `manifest_test.url_field`, `manifest_test.mode_segment`, `manifest_test.start_button`, `manifest_test.stats_label`, `manifest_test.log_view`, initial log `Manifest 缓存测试页面已加载`, taps `manifest_test.clear_cache_button`, verifies `所有缓存已清除`, replaces the URL with `http://localhost:8081/test_resources/bridge-hub.html`, taps `manifest_test.start_button`, asserts `WebViewDisplayViewController`, `manifest_test.display_webview`, and `webview_display.close_button`, closes the WebView, and verifies log text `智能加载成功`; CacheTests validate manifest semantics | Entry, clear-cache action, and smart-load WebView execution available on simulator | Physical-phone execution should use the public fixture URL under `https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/` |
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

## Approval v1 Evidence (2026-08-12)

- Contract and lifecycle verification: `bash tools/verify-approval-v1.sh` -> 11 passed, 0 failed. It covers native/web/PWA payloads, status polling, response submission, persisted resolution, first-response-wins, private callback rejection, and raw HTML rejection.
- Server regression: `cd Server && swift test` -> 31 tests in 6 suites, 0 failures.
- Message model regression: focused `MessagePayloadTests` -> 14 passed, 0 failed.
- Native interaction regression: `DeepVerificationTests.testInboxNativeApprovalShowsActionsAndConfirmation` -> 1 passed, 0 failed. Evidence bundle: `/tmp/wbk-approval-dd/Logs/Test/Test-SuperApp-2026.08.12_00-45-47-+0800.xcresult`; resolved-state screenshot: `/tmp/wbk-ui-inbox-native-approval-approved.png`.
- Quality gates: `swiftlint --quiet` -> 0 warnings; `bash tools/ci-lint.sh` -> 16 passed, 0 failed; `bash tools/visual-checks.sh` -> 6 passed, 4 documented warnings, 0 failed.
- Crash gate: `bash scripts/scan-crash-logs.sh --json` -> `total: 0` after the approval interaction run.
- Scope: simulator and local-backend evidence proves contract, rendering, submission, conflict handling, and local state reconciliation. It does not prove APNs delivery to a physical iPhone.

## Message Types v1 Evidence (2026-08-12)

- Contract verification: `bash tools/verify-message-types-v1.sh` -> 15 passed, 0 failed. It covers valid plain, Markdown, image, QR code, verification code, chat, and approval payloads, plus missing required fields and raw inline HTML rejection.
- Server regression: `cd Server && swift test` -> 31 tests in 6 suites, 0 failures. `PushRoutesTests.canonicalMessageTypesValidateRenderingFields` verifies renderer-specific requirements at the HTTP boundary.
- Message model regression: focused `MessagePayloadTests` -> 14 passed, 0 failed. Evidence bundle: `/tmp/wbk-message-catalog-dd/Logs/Test/Test-MessageTests-2026.08.12_01-19-37-+0800.xcresult`.
- Native detail regressions: 10 passed, 0 failed across plain, Markdown, image success, compact image failure, QR code, verification code, chat, native approval, and technical-detail disclosure. Evidence bundles: `/tmp/wbk-message-catalog-dd/Logs/Test/Test-SuperApp-2026.08.12_01-11-17-+0800.xcresult`, `/tmp/wbk-message-catalog-dd/Logs/Test/Test-SuperApp-2026.08.12_01-15-10-+0800.xcresult`, and `/tmp/wbk-message-catalog-dd/Logs/Test/Test-SuperApp-2026.08.12_01-16-27-+0800.xcresult`.
- Offline Markdown regression: `MarkdownRendererTests` verifies headings, task lists, tables, quotes, inline/fenced code, safe links, raw-HTML escaping, unsafe-URL rejection, and no CDN parser dependency -> 2 passed, 0 failed. Focused message-model run (`MarkdownRendererTests` + `MessagePayloadTests`) -> 16 passed, 0 failed. Evidence bundle: `/tmp/wbk-markdown-dd/Logs/Test/Test-MessageTests-2026.08.12_02-08-33-+0800.xcresult`.
- Markdown visual regression: `DeepVerificationTests.testInboxMessageDetail` -> 1 passed, 0 failed; it captures a realistic deployment message with a quote, task list, metrics table, fenced command, inline code, and link. Evidence bundle: `/tmp/wbk-markdown-dd/Logs/Test/Test-SuperApp-2026.08.12_02-06-59-+0800.xcresult`; screenshots: `/tmp/wbk-ui-inbox-markdown-top.png` and `/tmp/wbk-ui-inbox-markdown-details.png`.
- Visual artifacts: `/tmp/wbk-ui-inbox-type-plain.png`, `/tmp/wbk-ui-inbox-detail.png`, `/tmp/wbk-ui-inbox-type-image.png`, `/tmp/wbk-ui-inbox-type-image-failure.png`, `/tmp/wbk-ui-inbox-qr.png`, `/tmp/wbk-ui-inbox-verification.png`, `/tmp/wbk-ui-inbox-type-chat.png`, and `/tmp/wbk-ui-inbox-native-approval.png`.
- Build and quality gates: SuperApp simulator build succeeded; `swiftlint --quiet` -> 0 warnings; `bash tools/ci-lint.sh` -> 16 passed, 0 failed; `bash tools/visual-checks.sh` -> 6 passed, 4 documented warnings, 0 failed.
- Scope: this proves the canonical HTTP contract and simulator rendering behavior. It does not prove physical-device APNs delivery, remote image-host availability, or third-party callback uptime.

## Inbox Scheme One Evidence (2026-08-12)

- Visual contract: the latest timeline keeps source, title, preview, time, type-derived icon, and unread indicator. It deliberately suppresses generic type/priority chips; only an actionable approval or critical message may show a state marker.
- Group contract: the original gateway `group` value remains the stable identifier for grouping and accessibility, while known Bark-style values are localized for display (for example, `verification-codes` -> `验证码`).
- Focused Inbox interaction regression: `DeepVerificationTests.testInboxLatestTimelineCanSwitchToGroups`, `testInboxGroupCanCollapseAndExpand`, `testInboxUnreadFilter`, and `testInboxAppFilter` -> 4 passed, 0 failed. Evidence bundle: `/tmp/wbk-inbox-scheme-one-dd/Logs/Test/Test-SuperApp-2026.08.12_02-40-31-+0800.xcresult`.
- Visual artifacts: `/tmp/wbk-ui-inbox-latest.png`, `/tmp/wbk-ui-inbox-groups.png`, `/tmp/wbk-ui-inbox-unread.png`, and `/tmp/wbk-ui-inbox-app-filter.png`.
- Scope: simulator evidence verifies the native Inbox rendering and local persisted-message behavior; it does not imply physical-device APNs delivery.

## Trusted PWA Approval Handoff Evidence (2026-08-12)

- Modal PWA handoff now configures the embedded WebView before its first navigation and preserves `WebBrowserParams` launch context. Only `file://` URLs use the app-bundled HTML loader; localhost and HTTPS approval pages remain remote PWA navigations.
- Safety regression: `DeepVerificationTests.testInboxPWAApprovalOpensTrustedRouteWithoutApproving` plus `testInboxNativeApprovalShowsActionsAndConfirmation` -> 2 passed, 0 failed. Evidence bundle: `~/Library/Developer/XcodeBuildMCP/workspaces/WebBridgeKit-815a0cec42de/result-bundles/test_sim_2026-08-12T05-17-47-896Z_pid47459_eab838e6.xcresult`.
- The PWA fixture receives `requestId=approval-42` and `webbridgekitSource=notification`; the test closes the modal and asserts that the native record remains `待确认`, with no `已通过` state. Screenshot: `/tmp/wbk-ui-inbox-pwa-approval.png`.
- Scope: this proves simulator navigation, trusted launch-context delivery, and non-approval-by-navigation. A PWA remains responsible for its own custom approval UI and callback/state protocol; real APNs delivery and third-party callback availability still require physical/external verification.

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
| Debug Center child tools only had entry-level evidence | A child row could open a shell while the expected content or primary action stayed broken | `SuperAppUITests/ModuleAvailabilityTests.testDebugCenterChildToolContentAndActionsAreUsable` now verifies diagnostics copy result, diagnostics export-to-file result, network seeded row plus clear action, and Manifest cache controls/clear action/full smart-load WebView execution; `DiagnosticsView.swift`, `NetworkDebugViewController.swift`, `ManifestCacheTestViewController.swift`, and `WebViewDisplayViewController.swift` expose stable accessibility evidence |
| shanbox command generation returned padded base64 token payloads | Public `/api/v1/commands` returned HTTP 200 but emitted `=` padding, conflicting with the app/report requirement for URL-safe command deep links | Synced the current `CommandService.swift` to `/root/WebBridgeKit/Server`, rebuilt `swift build -c release`, restarted `webbridgeserver` via supervisord, and added `Command token semantics` to `tools/verify-shanbox-backend.sh`; refreshed evidence is 27/27 pass |
| Bridge Lab result was hidden below the execute action and unstable in XCUITest | The result panel could be below the fold after tapping `执行校验`, and asserting the SwiftUI container triggered fragile broad snapshots | `BridgeLabHomeView.swift` now places the result panel directly above the execute controls; `CodeBlockView.swift` exposes stable detail text identifiers; `ModuleAvailabilityTests.testBridgeLabControlsAreUsable` verifies visible result text and `cache.stats`, 1/1 passed |
| Push tab availability used a fragile root-container assertion | On iOS 26.5 automation, repeatedly waiting for a SwiftUI root container could make XCUITest lose the app session even though the Push page was visually loaded | `TabBarController.swift` exposes UIKit hosting root identifiers, `TokenPushHomeViewModel.swift` defers status snapshot refresh until after first render, and `ModuleAvailabilityTests.testTokenPushAndBarkControlsAreUsable` now proves availability through concrete Push controls and result text; affected rerun passed 3/3 |

## Remaining Unavailable And Manual-Only Items

| Item | Status | Required next evidence |
| --- | --- | --- |
| Push Notifications provisioning profile is unavailable | Unavailable | Use a paid Apple Developer Program team/App ID with Push Notifications enabled, regenerate provisioning profile, rebuild for device, and verify signed app contains `aps-environment` |
| SuperApp real-device install/launch is blocked by Push capability signing | Unavailable in current signing environment | Use a Push-capable Apple Developer Program team/profile; temporary command-line no-push override with `com.webbridgekit.superapp.nopush` still failed, so do not claim non-push real-device SuperApp smoke until an installable app bundle is produced |
| Bark/APNs end-to-end delivery is unavailable | Unavailable | After APNs signing passes, register a real iPhone token to shanbox, send a Bark-compatible request, verify notification receipt and tap routing |
| Physical iOS Settings handoff not proven on real device | Manual-only | On iPhone, tap `设置` -> `通知设置` and verify iOS opens the SuperApp notification settings page or documented fallback |
| Diagnostics system share sheet presentation | Manual-only | On iPhone or simulator, tap `设置` -> `诊断导出` -> `分享诊断数据` and verify the iOS share sheet appears with the generated diagnostics JSON |

## Remaining Non-Blocking Debt

| Debt | Status | Path |
| --- | --- | --- |
| Design lint warning: hardcoded system font | Non-blocking warning | `Sources/Models/ManifestModels.swift:410` |
| Design lint warning: hardcoded system font | Non-blocking warning | `Sources/Extensions/UIImageView+LetterIcon.swift:26` |
| Design lint warning: deprecated `ThemeBadge` init | Non-blocking warning | `SuperApp/Sources/Controllers/ComponentCatalog/ComponentSections.swift:101` |
| Design lint warning: deprecated `ThemeBadge` init | Non-blocking warning | `SuperApp/Sources/Controllers/Showcase/ThemeShowcaseViewController.swift:114` |
| Design lint warning: deprecated `ThemeBadge` init | Non-blocking warning | `SuperApp/Sources/Controllers/ComponentCatalog/ActionSections.swift:223` |

## Current Availability Verdict

No confirmed unavailable non-push in-app navigation entry is currently listed after this pass.

The items not marked fully available are real-device/system-level flows, Push/Bark APNs delivery, and phone-specific network behavior:

- Push-capable Apple Developer Team/provisioning profile
- Signed-app `aps-environment` entitlement proof
- SuperApp real-device install/launch under the current signing environment
- APNs registration on physical iPhone
- Bark end-to-end notification delivery to a real APNs token
- Real-device notification settings handoff
- Background/lock-screen notification behavior
- Phone-specific backend reachability and LAN/firewall/VPN differences outside simulator
- Diagnostics system share-sheet presentation remains manual-only; diagnostics copy/export-file, network seeded content/clear, and Manifest full smart-load WebView execution are now proven by UI automation
