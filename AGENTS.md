# WebBridgeKit Project

## Services

Three services must be running for testing/verification:

| Service | Port | URL | Description |
|---------|------|-----|-------------|
| Backend (Swift) | 8080 | http://localhost:8080 | WebBridgeServer - Hummingbird, routes: /health /push /manifest /command |
| Test HTTP | 8081 | http://localhost:8081 | Static file server for cache testing (project root + test_resources/) |
| Prototype | 8083 | http://localhost:8083 | HTML prototype (index.html, v2-current-implementation.html) |

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

**IMPORTANT**: Always run `bash scripts/services.sh start` before testing the app in simulator. The backend is required for push notification, command handling, and manifest features to work correctly.

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
