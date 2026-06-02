# WebBridgeKit Project

## Services

Three local services must be running for simulator development and local regression testing:

| Service | Port | URL | Description |
|---------|------|-----|-------------|
| Backend (Swift) | 8080 | http://localhost:8080 | WebBridgeServer - Hummingbird, routes: /health /push /manifest /command |
| Test HTTP | 8081 | http://localhost:8081 | Static file server for cache testing (project root + test_resources/) |
| Prototype | 8083 | http://localhost:8083 | HTML prototype (index.html, v2-current-implementation.html) |

### Public shanbox Backend

Do **not** replace the local services above with the public URL. They serve different verification scopes.

| Environment | URL | Use For | Do Not Use For |
|-------------|-----|---------|----------------|
| Local backend | http://localhost:8080 | Simulator tests, local route debugging, cache/manifest/command regression | Proving public deployment or phone reachability |
| Local test HTTP | http://localhost:8081 | Static fixtures for cache tests and offline/cache HTML validation | Production/Bark route checks |
| Local prototype | http://localhost:8083 | HTML design prototype comparison | Backend/API validation |
| Public shanbox Swift backend | https://wbk.shanbox.19930810.xyz:8443 | Real-phone/server config, Bark-compatible route checks, public `/health`, `/register`, `/push`, `/test`, `/api/v1/commands` verification | Local fixture tests, prototype viewing, APNs delivery proof by itself |

Use the public URL when validating the deployed backend or configuring the app on a physical iPhone:

```bash
bash tools/verify-shanbox-backend.sh
WBK_SHANBOX_URL=https://wbk.shanbox.19930810.xyz:8443 bash tools/verify-shanbox-backend.sh
bash tools/verify-shanbox-supervision.sh
```

The public shanbox backend check is route-level evidence only. It does not prove APNs registration, real Bark delivery, lock-screen/background notification behavior, phone LAN behavior, or process supervision. Use `tools/verify-shanbox-supervision.sh` for SSH-level process supervision evidence.

### Management

```bash
bash scripts/services.sh start     # Start all 3 services
bash scripts/services.sh stop      # Stop all services
bash scripts/services.sh restart   # Restart all services
bash scripts/services.sh status    # Show running status
bash scripts/services.sh verify    # Health-check with curl
bash scripts/services.sh logs      # Show recent logs
```

Run `bash scripts/services.sh` without args for full usage.

**IMPORTANT**: Always run `bash scripts/services.sh start` before testing the app in simulator. The local backend is required for simulator push-route, command, manifest, cache, and prototype workflows. Use `tools/verify-shanbox-backend.sh` separately for public deployment evidence.

## Build & Run

```bash
xcodebuild build -workspace WebBridgeKit.xcworkspace -scheme SuperApp -sdk iphonesimulator -arch arm64 -derivedDataPath /tmp/wbk-dd
```

Install to booted simulator:
```bash
APP=$(find /tmp/wbk-dd -name "SuperApp.app" -maxdepth 5 | head -1)
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.webbridgekit.superapp
```

## XcodeBuildMCP

- If using XcodeBuildMCP, use the installed XcodeBuildMCP skill before calling XcodeBuildMCP tools.

## Project Structure

- `Server/` - Swift Hummingbird backend (SPM)
- `Sources/` - WebBridgeKit framework core
- `SuperApp/` - iOS app target
- `docs/prototype/` - HTML design prototypes
- `scripts/` - Utility scripts (services.sh, test_server.py)
- `docs/design-tokens.json` - Single source of truth for design tokens

## i18n

- `SuperApp/Resources/zh-Hans.lproj/Localizable.strings` - Chinese (primary)
- `SuperApp/Resources/en.lproj/Localizable.strings` - English
- `Sources/Utils/L10n.swift` - Localization helper with multi-bundle fallback

## CI

- `.github/workflows/ci.yml` - 14 jobs, Smoke Tests may need retry
- Check: `gh run list --limit 5`

## Design System

- `docs/design-tokens.json` — Single source of truth for design tokens (95 tokens, 9 categories)
- `Sources/Theme/ThemeTokens.swift` — iOS token constants (**use `ThemeTokens.Color.*` for ALL colors**)
- `docs/prototype/design-tokens.css` — Auto-generated CSS variables
- `tools/sync-tokens.sh` — Bidirectional sync (JSON → Swift + CSS)

### Color Usage Rules (MANDATORY)

1. **Always use `ThemeTokens.Color.*`** — it auto-adapts to Light/Dark mode
2. **Never hardcode** `UIColor(red:)`, `.systemBlue`, `.label`, etc.
3. **Never use** `ThemeTokens.Colors.Light/Dark` (static, no dark mode) or `WKColor.*` (deprecated)
4. For shadows/borders only: `UIColor.black.cgColor` is acceptable
5. See `.opencode/rules/ios-design-best-practices.mdc` for full spec

## Icons

- Real Lucide icon library: `Sources/Theme/icons.xcassets` (1703 PDF icons)
- `Sources/Theme/LucideIcon.swift` — 50+ case enum mapping to Lucide IDs
- `Sources/Theme/Lucide.swift` — UIImage extension for loading Lucide icons

## Testing

- **Coverage**: ~87% (168 test files / 193 source files)
- **UITesting**: `--ui-testing --show-component-catalog` launch arguments
- **Component Catalog**: Settings → 框架展示 OR launch arg `--show-component-catalog`
- **Visual Regression**: `tools/diff-screenshots.sh` (PIL-based, HTML report)

## Essential Verification Scripts

Use these scripts as the repeatable evidence source before declaring a module "available". Most scripts write reports/logs under `build/reports/`; treat those as verification artifacts, not source files to commit unless the user explicitly asks.

### Basic Gates

| Script | Purpose | Pass Signal | When To Run |
|--------|---------|-------------|-------------|
| `bash scripts/services.sh start` | Starts backend `:8080`, test HTTP `:8081`, prototype `:8083` | All 3 services running | Before simulator app tests, cache tests, manifest tests, push/command route checks |
| `bash scripts/services.sh verify` | Curl health check for the 3 local services | Backend `/health` 200/204, test HTTP 200, prototype 200 | After starting services or when a network/cache/push feature looks broken |
| `bash scripts/scan-crash-logs.sh --json` | Scans app crash logs, diagnostic reports, simulator logs, OOM/jetsam signals | JSON contains `"total": 0` | After launch, UI tests, real-device/simulator smoke, or when user asks about crashes |
| `swiftlint --quiet` | SwiftLint quality gate | No output, exit 0 | Before every commit |
| `bash tools/ci-lint.sh` | Design-system lint wrapper: colors, icons, fonts, `.opencode`, crash logs, token JSON, touch targets | `16 passed, 0 failed`; warnings may remain documented debt | Before UI/design commits and release gates |

### Module Regression Gates

| Script / Command | Purpose | Pass Signal | Notes |
|------------------|---------|-------------|-------|
| `bash tools/run-cache-regression.sh` | Cache module regression: services, `CacheTests`, cache handler tests, cache dashboard UI tests | `Summary: ... failed` must be 0 | Requires a booted simulator for the UI portion |
| `bash tools/run-jsbridge-regression.sh` | JSBridge regression: core bridge tests, `BridgeTests`, handler tests, functional UI tests | `Summary: ... failed` must be 0 | Requires a booted simulator for the UI portion |
| `xcodebuild test ... -only-testing:SuperAppUITests/ModuleAvailabilityTests` | Current information architecture/module availability UI gate | 8 tests, 0 failures | Verifies `Web`, `Push`, `Bridge`, `Settings`, Debug Center, Deep Links, About/Legal, iOS Settings handoff |
| `cd Server && swift test` | Swift Hummingbird backend route semantics | All `Manifest Routes`, `Push Routes`, `Command Routes` tests pass | Does not prove public shanbox deployment or APNs delivery |

### UI And Visual Gates

| Script | Purpose | Pass Signal | Notes |
|--------|---------|-------------|-------|
| `bash tools/run-ui-v4-regression.sh` | Aggregated UI v4 gate: services, SwiftLint, design lint, static visual checks, crash scan, screenshots, visual regression | `Summary: ... failed` must be 0 | Requires a booted simulator for screenshot/visual gates |
| `bash tools/visual-checks.sh` | Static UI contract checks: UILabel wrapping, search placeholder, row/card/pill heights, empty-state action, hardcoded component colors | `FAIL=0` | Warnings are acceptable only if documented |
| `bash tools/capture-screenshots.sh --build` | Builds/installs app, captures light/dark screenshots to `docs/screenshots/ui-redesign/` | Screenshots written successfully | Requires a booted simulator |
| `bash tools/run-visual-regression.sh` | Compares screenshot directories with threshold, writes HTML/JSON diff report | Exit 0, no screenshots over threshold | Use `--threshold N`, `--output-dir PATH`, `--screenshots-dir PATH` as needed |
| `bash tools/diff-screenshots.sh` | Low-level PIL screenshot diff engine | Exit 0 within threshold | Normally called by `run-visual-regression.sh` |

### External, Release, And Device Gates

| Script | Purpose | Pass Signal | Notes |
|--------|---------|-------------|-------|
| `bash tools/verify-shanbox-backend.sh` | Verifies public shanbox Swift backend routes, response JSON semantics, Bark-compatible GET/POST, and encoded Bark query paths | `16 passed, 0 failed`; Node admin paths currently tracked as unavailable | Route-level only; fake device token does not prove APNs delivery |
| `bash tools/verify-shanbox-supervision.sh` | Verifies remote `WebBridgeServer` process and whether it is supervised by systemd or PM2 | `process=PASS, supervision=PASS`; current shanbox is known to fail supervision | Requires SSH alias `shanbox` or `WBK_SHANBOX_SSH_HOST`; intentionally exits 1 if supervision is missing |
| `bash tools/run-real-device-smoke.sh` | Auto-discovers paired/available iPhone, builds for device, installs, launches `com.webbridgekit.superapp` | `4 passed, 0 failed` | Proves physical build/install/launch only, not APNs/Bark delivery |
| `bash tools/run-release-gate.sh` | Release readiness: services, SwiftLint, design lint, Debug build, crash scan, Release archive, no test HTML in app bundle | `Summary: ... failed` must be 0 | Use before release/archive handoff |
| `bash tools/validate-cache-html.sh` | Validates cache-related HTML resources | Exit 0 | Use after changing test resources or cached HTML fixtures |

### Availability Evidence Rules

- Do not mark APNs registration, Bark end-to-end delivery, lock-screen/background notification behavior, or phone-specific LAN reachability as fully available from simulator-only evidence.
- iOS Settings handoff can be simulator-verified by proving `UIApplication.openSettingsURLString` opens `com.apple.Preferences`; require a physical confirmation only when release criteria explicitly demand a real-device Settings handoff check.
- `tools/verify-shanbox-backend.sh` proves public route behavior only. It intentionally marks Node admin routes (`/admin`, `/admin-push`, `/ws/status`, `/messages`, `/packages`) as unavailable on the current Swift backend deployment.
- `tools/verify-shanbox-supervision.sh` proves whether the public Swift backend has restart supervision. Current shanbox evidence is `process=PASS, supervision=FAIL`, so route availability must not be treated as production supervision.
- `tools/run-real-device-smoke.sh` proves the app can build, install, and launch on a paired iPhone. It does not prove notification permission, APNs token registration, or notification receipt.
- When updating `docs/verification/module-availability-verification.md`, cite the exact command, pass/fail count, and report/log path.

## Prototypes

| File | Purpose |
|------|---------|
| `docs/prototype/index.html` | V1 design prototype (English, 618 lines) |
| `docs/prototype/v2-current-implementation.html` | V2 current implementation (Chinese, 926 lines) |

## Key Dependencies

- **CocoaPods**: 10 pods (Alamofire, etc.)
- **SPM** (Server): Hummingbird 2, swift-nio, swift-crypto
- **XcodeGen**: `project.yml` generates pbxproj

## Development Workflow

1. Start services: `bash scripts/services.sh start`
2. Build: `xcodebuild build -workspace WebBridgeKit.xcworkspace -scheme SuperApp -sdk iphonesimulator -arch arm64 -derivedDataPath /tmp/wbk-dd`
3. Install to simulator: `xcrun simctl install booted "$APP" && xcrun simctl launch booted com.webbridgekit.superapp`
4. Compare with prototype: open http://localhost:8083/index.html in browser
5. Run tests: `xcodebuild test ...`

## Crash Log Scanning (定期扫描)

App 内置 `CrashLogManager` 自动捕获崩溃（NSSetUncaughtExceptionHandler + signal handlers），持久化到 `Documents/crash_logs/*.json`。

### 扫描命令

```bash
# 快速扫描（推荐，定期执行）
bash scripts/scan-crash-logs.sh

# JSON 输出（用于自动化）
bash scripts/scan-crash-logs.sh --json

# 扫描 + 清理
bash scripts/scan-crash-logs.sh --fix
```

### 扫描范围

| 来源 | 路径 | 内容 |
|------|------|------|
| App 崩溃日志 | Simulator Documents/crash_logs/*.json | CrashLogManager 捕获的异常/signal 崩溃 |
| 系统诊断报告 | ~/Library/Logs/DiagnosticReports/SuperApp*.ips | macOS 系统级崩溃报告 |
| 系统日志 | simctl log show (最近 1h) | os_log error 级别 + crash/terminated/OOM 关键词 |
| 内存事件 | simctl log show (最近 1h) | memory/OOM/jetsam 事件 |

### 当用户说"扫一下日志"或"看下崩溃"时

1. 确保 booted simulator 存在且 app 已安装
2. 运行 `bash scripts/scan-crash-logs.sh`
3. 如有崩溃，分析崩溃类型/原因/调用栈，定位到对应源码
4. 将分析结果和修复建议写入 AGENTS.md 的 `## Crash Analysis` 章节下方
5. 提供修复方案

## Crash Analysis

<!-- 崩溃分析记录（最新在前） -->
<!-- 格式: | 日期 | 类型 | 原因 | 修复 | -->
<!-- 示例: | 2026-05-14 | SIGABRT | Realm schema migration | PR #123 | -->

| 日期 | 类型 | 原因 | 定位 | 修复 |
|------|------|------|------|------|
| 2026-05-20 | SIGTRAP | Notification Debug section header 未加入 card 视图层级就使用 SnapKit `equalToSuperview()`，触发 assertionFailure | SuperApp/Sources/Controllers/Debug/NotificationDebugViewController.swift:219 | 在约束 header 前补 `card.addSubview(header)` |

## Command History Access

### How to Access Command History

The Debug Panel provides access to command execution history with timestamps, status, and results.

**Access Path:**
1. Open Debug Panel: Settings → 测试面板 (or directly in development builds)
2. Navigate to **Logs tab** (tab index 2, labeled "日志" with 📄 icon)
3. View command traces with the following information:
   - **Timestamp**: When the command was executed
   - **Level**: Info/debug/error
   - **Category**: `.handler` for command executions
   - **Action**: Handler name (e.g., `push_notification`, `get_manifest`)
   - **Message**: Detailed log message
   - **Context**: Parameters (if any)
   - **Duration**: Execution time in milliseconds

**Features in Logs Tab:**
- **Filter All**: Shows all logs (default)
- **Filter Errors**: Shows only error-level logs
- **Copy All**: Copies all logs to clipboard
- **Export JSON**: Exports logs as JSON for external analysis

**Log Entry Format:**
Each command trace includes:
```
[TIMESTAMP] [LEVEL] [CATEGORY] action=ACTION_NAME message=MESSAGE context=PARAMS duration=XXXms
```

Example output:
```
2026-05-19 10:30:45.123 INFO [handler] action=push_notification message="Sent push to device" context={"token":"****","data":"..."} duration=125ms
2026-05-19 10:30:45.456 INFO [handler] action=get_manifest message="Manifest fetched successfully" duration=89ms
```

**Note**: Command history is stored in memory via `StructuredLogger.shared.memoryBuffer` with a maximum capacity of 1000 entries.

(暂无记录)

| 日期 | 类型 | 原因 | 定位 | 修复 |
|------|------|------|------|------|
| 2026-05-20 | SIGABRT | SnapKit 约束冲突：固定高度 90pt vs 内容高度超 90pt | ComponentCatalog/LayoutSections.swift:152-166 | 移除固定高度约束，改用 auto-layout 自适应 d9a7a38 |
| 2026-05-19 | SIGABRT | Podfile 重复链接 shared_pods 导致 ObjC runtime 重复类定义 | Podfile:107, WebBridgeKit+SuperApp targets | SuperApp `inherit! :search_paths` 从 WebBridgeKit 继承 pods |

## UI Testing

### Running UI Tests

```bash
# Build and run UI tests
xcodebuild test \
  -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/wbk-dd \
  -only-testing:SuperAppUITests

# Run with component catalog visible
xcrun simctl launch booted com.webbridgekit.superapp --show-component-catalog
```

### Launch Arguments

| Argument | Purpose |
|----------|---------|
| `--ui-testing` | Seeds test data, skips onboarding |
| `--show-component-catalog` | Shows WBK component showcase |

## Release Checklist

### Pre-Release

- [ ] `bash scripts/services.sh start` — all 3 services running
- [ ] `xcodebuild build` — zero build errors
- [ ] Business warnings = 0 (toolchain warnings acceptable)
- [ ] `bash scripts/scan-crash-logs.sh` — zero crashes
- [ ] `xcodebuild test` — all tests pass
- [ ] UI smoke test on simulator (Home/Inbox/Discover/Settings)
- [ ] Dark mode visual check
- [ ] iPhone SE layout check

### Post-Release

- [ ] Update AGENTS.md Recent Commits
- [ ] Tag release: `git tag v{version}`
- [ ] Verify CI green: `gh run list --limit 5`

## Quality Policies

### Warning Policy

- **Business code warnings = 0**: All Swift source warnings in `Sources/` and `SuperApp/` must be zero
- **Toolchain warnings acceptable**: Warnings from CocoaPods, SPM dependencies, or Xcode itself are acceptable
- **Enforcement**: CI `lint` job checks for business warnings

### Crash Policy

- **Crash count must be 0**: No crashes allowed in any build
- **Enforcement**: `bash scripts/scan-crash-logs.sh` must return `total: 0`
- **If crash found**: Fix immediately before any other work, log in `## Crash Analysis`

## Recent Commits

| Commit | Description |
|--------|-------------|
| `e75dccb` | test(device): harden real-device smoke gate |
| `ab062a2` | test(ui): verify about legal deep link path |
| `4b2382e` | test(server): add shanbox backend verification gate |
| `3608f0e` | feat(ui): add screenshot capture tests, visual check scripts, CI design lint |
| `ef2874e` | feat(ui): v3 UI redesign — token system, 11 WBK components, 4 page redesigns (#2) |
| `3d79ccf` | fix(ui): inbox search bar shadow + home bookmark tap opens URL instead of camera |
| `5150fba` | fix(quality): production readiness — remove 559 prints, fix 85 force unwraps, extract hardcoded colors to ThemeTokens, add DEBUG guards |
| `12ebddc` | fix(ui): align all pages to design prototype — home token card, quick actions, app cards, inbox source pills/FAB, discover badges, settings icon tints |
| `864ad2c` | feat(offline): offline fallback, atomic updates, version status model |
| `3a9f9c1` | fix(core): HTML parser URL resolution, deferred WebView loading, crash scan improvements, cache validation tooling |
| `49a0e69` | perf(ci): share build artifacts, 4-group matrix, parallel lint+build, 30min timeout |
| `634cb49` | feat(security): CORS whitelist, third-party licenses page, 39 security tests |
| `d9a7a38` | fix(tests): skip MessageEngine in UI test mode to avoid async race condition |
| `4f53c00` | fix(build): UI build quality pass — warnings 25→4, UI audit, packaging (#1) |
| `d826dc1` | feat(productization): bookmarks, history, manifest preview, diagnostics, UI polish |
| `5218431` | feat(quality): accessibility audit, UI tests, CI hardening, release docs, screenshots |
