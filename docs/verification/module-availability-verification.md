# Module Availability Verification Report

Date: 2026-06-02 18:58 CST
Commit under test: current worktree based on `dc40f2a`
Simulator: `iPhone 16 Pro UI Test`, iOS Simulator 18.3.1, command destination `id=79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0`<br>
Physical device: `许映洲的iPhone`, iPhone 13, iOS 18.7.3, currently `unavailable`/offline to Xcode CoreDevice

## Summary

| Area | Status | Evidence |
| --- | --- | --- |
| Services | Available | `bash scripts/services.sh restart && bash scripts/services.sh verify` passed, ports 8080/8081/8083 healthy; launchctl-backed services remain available across separate shell commands |
| SwiftLint | Available | `swiftlint --quiet` produced zero output |
| Crash gate | Available | `bash scripts/scan-crash-logs.sh --json` -> `{"diagnostic_reports":0,"app_crash_logs":0,"total":0}` |
| Design lint | Available with warnings | `bash tools/ci-lint.sh` passed 16/16 checks, 0 errors, 5 warnings |
| Module UI availability | Available | `ModuleAvailabilityTests`: 8 tests, 0 failures |
| Cache semantics | Available | `CacheTests`: 548 tests, 0 failures |
| JSBridge semantics | Available | `BridgeTests`: 101 tests, 0 failures |
| Bark/Push/message semantics | Available | `MessageTests`: 226 tests, 0 failures |
| Server route semantics | Available | `cd Server && swift test` passed 16 tests, 0 failures |
| Physical device install and launch | Unavailable in current run | `bash tools/run-real-device-smoke.sh` -> 0 passed, 1 failed because no available paired iPhone was discovered |
| Real-device Push/APNs readiness | Unavailable | `bash tools/verify-real-device-push-readiness.sh` -> 4 passed, 4 failed, 4 manual |
| shanbox Swift backend | Available | `bash tools/verify-shanbox-backend.sh` -> 16 passed, 0 failed |
| shanbox WebBridgeServer supervision | Available | `bash tools/verify-shanbox-supervision.sh` -> process=PASS, supervision=PASS |
| shanbox Node admin console | Unavailable on current public service | `bash tools/verify-shanbox-backend.sh` -> `/admin`, `/admin-push`, `/ws/status`, `/messages`, `/packages` returned expected 404 because the public `wbk` host is running the Swift backend, not `Server/node/server.js` |
| Deep Link external open | Available with first-open confirmation | `xcrun simctl openurl ... webbridgekit://tab?index=2` switched to Bridge; `webbridgekit://open?...cache-showcase.html` opened WebBrowser with Cache Showcase page |

## Automated Evidence

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
  -destination 'id=79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0' \
  -derivedDataPath /tmp/wbk-dd-module-current \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:SuperAppUITests/ModuleAvailabilityTests \
# Result: TEST SUCCEEDED, 8 tests, 0 failures, xcresult:
# /Users/xuyingzhou/Library/Developer/XcodeBuildMCP/workspaces/WebBridgeKit-815a0cec42de/result-bundles/test_sim_2026-06-02T11-15-15-461Z_pid64712_e17d58d1.xcresult
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
bash tools/run-real-device-smoke.sh
# Result: 0 passed, 1 failed, exit 1
# Gates:
# - Device discovery failed because no available paired iPhone was discovered
# Report: build/reports/real-device-smoke.md
```

```bash
bash tools/verify-real-device-push-readiness.sh
# Result: 4 passed, 4 failed, 4 manual, exit 1
# Report: build/reports/real-device-push-readiness.md
#
# Passed:
# - shanbox backend routes
# - shanbox backend supervision
# - APNs token forwarded to PushNotificationManager
# - Default Bark server is shanbox
#
# Failed:
# - No available paired iPhone discovered
# - Real-device build/install/launch skipped because no paired iPhone was discovered
# - project.yml does not point SuperApp to an entitlements file containing aps-environment
# - SuperApp.app not found under /tmp/wbk-dd-device-smoke, so signed APNs entitlement cannot be proven
#
# Manual:
# - Observe notification permission prompt on iPhone
# - Verify real APNs token registration to shanbox
# - Verify Bark end-to-end notification receipt
# - Verify background/lock-screen notification behavior
```

```bash
bash tools/verify-shanbox-backend.sh
# Result: 16 passed, 0 failed, 5 unavailable/needs deployment
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
# Known-unavailable Node routes:
# - GET /admin
# - GET /admin-push
# - GET /ws/status
# - GET /messages
# - GET /packages
```

```bash
bash tools/verify-shanbox-supervision.sh
# Result: process=PASS, supervision=PASS
# Report: build/reports/shanbox-supervision-verification.md
#
# Evidence:
# - WebBridgeServer process exists and listens on remote :8080
# - Remote PID 1 is `supervisord`
# - `supervisorctl status webbridgeserver` reports RUNNING
# - Public route verification still passes 16/16 after replacing the manual process
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
| Push/Bark | Copy Bark-compatible push URL | `Push` -> copy icon beside push URL | `TokenPushHomeViewModel.copyPushURL()` | UI test taps control without crash; MessageTests cover routing/payload semantics | Available | Clipboard content is not asserted in XCUITest |
| Push/Bark | Bark payload validation | `Push` -> `校验 Bark Payload` | `TokenPushHomeViewModel.validatePayload()`, `PushPayload.swift` | UI test taps control; `MessageTests` validates Bark/push payload behavior | Available | |
| Push/Bark | shanbox health and JSON push route | External `https://wbk.shanbox.19930810.xyz:8443` | `Server/Sources/WebBridgeServer/Routes/HealthRoutes.swift`, `PushRoutes.swift` | `tools/verify-shanbox-backend.sh`: `/health`, `/register`, `/push`, JSON response code assertions | Available for route-level checks | This uses a fake device token, so APNs delivery is not proven |
| Push/Bark | shanbox Bark-compatible URL | External `/{key}/{title}/{body}` | `Server/Sources/WebBridgeServer/Routes/PushRoutes.swift` | `tools/verify-shanbox-backend.sh`; `Server/PushRoutesTests` verify GET, POST, encoded Chinese title/body, and query parameters | Available for route-level checks | Uses service test key; real APNs delivery still requires a real registered token |
| Push/Bark | shanbox test endpoint | External `POST /test` | `Server/Sources/WebBridgeServer/Routes/PushRoutes.swift` | `tools/verify-shanbox-backend.sh` asserts `success == true`; `Server/PushRoutesTests.testPushEndpointReportsSuccess` | Available | Route-level semantic success verified; APNs delivery still requires real token |
| Push/Bark | APNs registration | `Push` -> `注册推送` | `PushNotificationManager.swift`, `AppDelegate.swift`, project entitlements | `tools/verify-real-device-push-readiness.sh`: APNs entitlement checks fail | Unavailable | Token forwarding is fixed, but the project and signed app do not contain `aps-environment`, so APNs cannot be marked ready |
| Bridge | Primary tab loads | Bottom tab `Bridge` | `BridgeLabHomeView.swift` | UI test verifies `bridgeLab.home`, groups, command list, parameter editor | Available | |
| Bridge | Command JSON entry and execute control | `Bridge` -> `执行校验` | `BridgeLabViewModel.swift` | UI test taps execute; `BridgeTests` validates registry/core semantics | Available | Real WebView execution remains future wiring per current UI copy |
| Bridge | Handler registry and metadata | Non-UI JSBridge APIs | `Sources/Bridge/`, `Sources/Handlers/` | `BridgeTests`: 101/101 | Available | |
| Commands | shanbox command generation | External `POST /api/v1/commands` | `Server/Sources/WebBridgeServer/Routes/CommandRoutes.swift` | `tools/verify-shanbox-backend.sh`; `Server/CommandRoutesTests` | Available | Public endpoint returns a signed command token |
| Server Ops | shanbox WebBridgeServer process | SSH `shanbox` / public backend | `/root/WebBridgeKit/Server/.build/release/WebBridgeServer`, `tools/verify-shanbox-supervision.sh` | `tools/verify-shanbox-supervision.sh`: process=PASS, supervision=PASS | Available | Process is running, listening, and supervised by supervisord |
| Settings | Primary tab loads | Bottom tab `设置` | `SettingsView.swift`, `SettingsViewModel.swift` | UI test verifies top rows and all operational rows | Available | |
| Settings | Server config | `设置` -> `服务器配置` | `ServerConfigViewController.swift` | UI test opens screen | Available | |
| Settings | Token manager | `设置` -> `口令管理` | `TokenManageViewController.swift` | UI test opens screen | Available | |
| Settings | API key manager | `设置` -> `密钥管理` | `APIKeyManageViewController.swift` | UI test opens screen | Available | |
| Settings | Cache manager | `设置` -> `缓存管理` | `ManagementViewController.swift` | UI test opens screen | Available | |
| Settings | Favorites | `设置` -> `收藏夹` | `FavoriteViewController.swift` | UI test opens screen | Available | |
| Settings | Recent history | `设置` -> `最近访问` | `RecentAccessHistoryView.swift` | UI test opens screen | Available | |
| Settings | Cache dashboard | `设置` -> `缓存仪表盘` | `CacheDashboardViewController.swift` | UI test opens screen | Available | |
| Settings | About/legal | `设置` -> `关于` -> `第三方开源许可` -> `Alamofire` | `AboutView.swift`, `ThirdPartyLicensesViewController.swift`, `LicenseDetailViewController.swift` | `ModuleAvailabilityTests.testSettingsAboutLegalDeepDrillIsReachable` opens About, license list, and license detail | Available | Deep drill now asserted with accessibility identifiers |
| Settings | Notification settings entry | `设置` -> `通知设置` | `NotificationSettingsOpener.open()` using `UIApplication.openNotificationSettingsURLString` on iOS 16+ and app Settings fallback below iOS 16 | `ModuleAvailabilityTests.testNotificationSettingsEntryIsWiredWithoutCrashing` taps the row and verifies either iOS Settings foregrounds or the app remains stable in foreground | Entry available; system handoff not proven in current simulator | The UI entry is wired and non-crashing. Current simulator did not foreground `com.apple.Preferences`, so real iOS Settings handoff still requires physical/manual confirmation |
| Debug Center | Debug home | `设置` -> `调试中心` | `DebugCenterHomeView.swift` | UI test opens `debugCenter.home` | Available | |
| Debug Center | Global debug panel | `调试中心` -> `全局调试面板` | `DebugPanelViewController.swift` | Entry exists in UI test | Available | Modal content covered by existing DebugPanel tests, not reopened here |
| Debug Center | Diagnostics export | `调试中心` -> `诊断导出` | `DiagnosticsView.swift` | Entry exists in UI test | Available | |
| Debug Center | Network inspector | `调试中心` -> `网络请求` | `NetworkDebugViewController.swift` | Entry exists in UI test | Available | |
| Debug Center | Manifest cache cases | `调试中心` -> `Manifest 缓存用例` | `ManifestCacheTestViewController.swift` | Entry exists in UI test; CacheTests validate manifest semantics | Available | |
| Debug Center | Crash scan guide | `调试中心` -> `崩溃扫描说明` | `DebugCenterViewModel.showCrashScanGuide()` | UI test taps control and remains on Debug Center | Available | Changed from delegated UIKit alert to ResultPanel update |
| Deep Links | Links tool opens | `设置` -> `协议跳转工具` | `DeepLinkHomeView.swift` | UI test opens `deepLink.home` | Available | |
| Deep Links | Open URL builder | `Links` -> target URL / mode / generated scheme | `DeepLinkHomeViewModel.swift` | UI test verifies URL input, generated scheme, mode picker; default local target `/test_resources/cache-showcase.html` returns 200 | Available | Default template now points to an existing cache showcase page |
| Deep Links | Mode switching | `Links` -> `Immersive` | `DeepLinkHomeView.swift` | UI test taps visible label `Immersive` | Available | |
| Deep Links | Validate open scheme | `Links` -> `校验` | `DeepLinkHomeViewModel.validateOpenScheme()` | UI test taps control and remains on Links page | Available | Result text is in long-page ResultPanel and not asserted |
| Deep Links | External tab scheme | External `webbridgekit://tab?index=2` | `SuperApp/Sources/AppDelegate.swift` | `xcrun simctl openurl`; after first-open confirmation, XcodeBuildMCP snapshot showed Bridge heading and `bridge.group.cache/navigation` controls | Available on simulator | First open may show the iOS confirmation dialog before the app receives the URL |
| Deep Links | External open URL scheme | External `webbridgekit://open?url=http%3A%2F%2Flocalhost%3A8081%2Ftest_resources%2Fcache-showcase.html` | `SuperApp/Sources/AppDelegate.swift`, `WebBrowserManager.openBrowser` | `xcrun simctl openurl`; XcodeBuildMCP snapshot showed `browserManager.closeButton`; screenshot showed Cache Showcase page | Available on simulator | `localhost` target depends on the local test HTTP service being reachable |
| Deep Links | Command scheme field | `Links` -> command token | `DeepLinkHomeView.swift`, `AppDelegate.application(_:open:)`, `CommandHandler` | UI test verifies generated command field; no current end-to-end token resolution evidence | Generated available; external command execution not proven | Need a real signed/generated command token and command handler result assertion |
| Server Admin | Node admin console | External `/admin`, `/admin-push` | `Server/node/server.js`, `Server/node/admin.html`, `Server/node/admin-push.html` | `tools/verify-shanbox-backend.sh`: 5 Node paths return 404 | Unavailable on public Swift backend | Node console exists in source but is not deployed behind `wbk.shanbox` |

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
| Real-device APNs readiness was tracked as manual-only | Automatic evidence now shows hard blockers: no project `aps-environment` entitlement and no signed APNs entitlement in the real-device app | `tools/verify-real-device-push-readiness.sh`, `build/reports/real-device-push-readiness.md` |
| Real-device smoke could reuse a stale `SuperApp.app` after build failure | Install/launch rows could look green even when the current build failed | `tools/run-real-device-smoke.sh` now clears DerivedData before build and skips install/launch if build fails |

## Remaining Non-Blocking Debt

| Debt | Status | Path |
| --- | --- | --- |
| Design lint warning: hardcoded system font | Non-blocking warning | `Sources/Models/ManifestModels.swift:410` |
| Design lint warning: hardcoded system font | Non-blocking warning | `Sources/Extensions/UIImageView+LetterIcon.swift:26` |
| Design lint warning: deprecated `ThemeBadge` init | Non-blocking warning | `SuperApp/Sources/Controllers/ComponentCatalog/ComponentSections.swift:101` |
| Design lint warning: deprecated `ThemeBadge` init | Non-blocking warning | `SuperApp/Sources/Controllers/Showcase/ThemeShowcaseViewController.swift:114` |
| Design lint warning: deprecated `ThemeBadge` init | Non-blocking warning | `SuperApp/Sources/Controllers/ComponentCatalog/ActionSections.swift:223` |
| Long-page ResultPanel message assertions are fragile in XCUITest because nested SwiftUI ScrollViews remain in the hierarchy | UI tests assert tappability and no crash; semantics covered by unit tests | `TokenPushHomeView.swift`, `BridgeLabHomeView.swift`, `DeepLinkHomeView.swift` |
| APNs entitlement is missing | `tools/verify-real-device-push-readiness.sh` confirms no `aps-environment` in project config and no APNs entitlement in the signed real-device app; production readiness also needs an Apple Developer Program team/App ID with Push Notifications enabled | `project.yml`, `SuperApp/`, signed `SuperApp.app` entitlements |
| External command deep link execution is not fully proven | UI generates `webbridgekit://command/<token>`, but no current automated evidence proves a real command token is resolved and executed through `CommandHandler` | `AppDelegate.application(_:open:)`, `CommandHandler`, command server |
| Node admin console is not deployed behind `wbk.shanbox` | `tools/verify-shanbox-backend.sh` confirms `/admin`, `/admin-push`, `/ws/status`, `/messages`, `/packages` return 404 on public shanbox Swift service | `Server/node/server.js`, shanbox deployment config |

## Current Availability Verdict

No confirmed unavailable in-app UI module was found in automated verification.

The items not marked fully available are real-device/system-level flows, external command-token execution, and non-Swift admin tooling: APNs entitlement/registration, Bark end-to-end delivery to a real APNs token, real-device notification settings handoff, backend reachability from phone-specific networks, background/lock-screen notification behavior, `webbridgekit://command/<token>` end-to-end execution, and Node admin console deployment.
