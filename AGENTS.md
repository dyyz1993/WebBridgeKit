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
| 2026-05-19 | SIGABRT | Podfile 重复链接 shared_pods 导致 ObjC runtime 重复类定义 | Podfile:107, WebBridgeKit+SuperApp targets | SuperApp `inherit! :search_paths` 从 WebBridgeKit 继承 pods |

## Recent Commits

| Commit | Description |
|--------|-------------|
| `e632a9a` | fix(warnings): clear remaining 24 business warnings to zero |
| `d826dc1` | feat(productization): bookmarks, history, manifest preview, diagnostics, UI polish |
| `720c61d` | feat(core): WebBridge security + core capabilities + stability baselines |
| `8ef63cf` | feat(ui): empty state unification, destructive confirmations, WebView loading, Debug prod gate |
| `5218431` | feat(quality): accessibility audit, UI tests, CI hardening, release docs, screenshots |
| `703f1e2` | fix(ui): P1/P2 quality pass — tabs, empty states, contrast, WKColor cleanup |
| `4770643` | docs(ui): add UI fidelity audit screenshots and handoff completion report |
| `05ce516` | fix(build): eliminate all business-code warnings (25→4) and fix fragile ThemeTests |
