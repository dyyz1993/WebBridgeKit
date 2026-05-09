# WebBridgeKit 架构总览

> 生成时间: 2026-05-09 | 基于 Phase 1-11 全部完成状态

---

## 1. 项目概览

**WebBridgeKit** 是一个面向 iOS 的「推送 + 缓存 + 原生桥接」超级应用框架，提供 JS↔Native Bridge、离线缓存引擎、消息推送路由、WebSocket 双通道通信等核心能力，支持任意 iOS App 集成。

### 技术栈总览

| 层 | 技术 | 说明 |
|---|------|------|
| **客户端语言** | Swift 5 / Swift 6 (Server) | 全量 Swift |
| **UI 框架** | UIKit | 原生 UIKit，无第三方 UI 依赖 |
| **依赖管理** | CocoaPods (10 pods) + XcodeGen | 多 Target 管理 |
| **服务端框架** | Hummingbird 2 | Swift 异步 HTTP 框架 |
| **服务端运行时** | swift-nio + swift-crypto | 非阻塞 I/O + HMAC 签名 |
| **数据持久化** | Realm | 本地数据库 |
| **图标库** | Lucide Icons (1703 PDF) | 开源矢量图标 |
| **CI/CD** | GitHub Actions (macos-15) | Xcode 16.4 锁定 |
| **代码规范** | SwiftLint (0 violations / 274 files) | 严格 lint |

### 代码量统计

| 模块 | 文件数 | 代码行数 | 说明 |
|------|--------|---------|------|
| Framework (`Sources/`) | 196 | ~45,896 | 底层框架核心 |
| App (`SuperApp/`) | 87 | ~23,716 | 业务层（VC + VM + View） |
| Server (`Server/`) | 15 | ~735 | Swift Hummingbird 后端 |
| Tests (`Tests/`) | 168 | ~35,984 | 测试套件 |
| **合计** | **466** | **~106,331** | |

---

## 2. 系统架构

### 2.1 三层架构

```
┌─────────────────────────────────────────────────────────────┐
│                    SuperApp (业务层)                         │
│  首页 / 收信箱 / 发现 / 设置 / Debug Panel / Token 管理     │
│  87 个 Swift 文件 · MVVM 架构 · 22+ ViewControllers         │
└───────────────────────┬─────────────────────────────────────┘
                        │ 调用框架能力
┌───────────────────────▼─────────────────────────────────────┐
│              WebBridgeKit Framework (核心层)                 │
│                                                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │ Bridge   │ │ Cache    │ │ Message  │ │ WebSocket    │   │
│  │ Engine   │ │ Engine   │ │ Engine   │ │ Engine       │   │
│  │ 35+ Handler│ Manifest │ Push/Bark │ JSON-RPC 2.0   │   │
│  │ JS↔Native│ Resource  │ Webhook   │ 双通道 Actor   │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │ AI       │ │ Command  │ │ Theme    │ │ Skills       │   │
│  │ Interface│ │ Parser   │ │ System   │ │ Registry     │   │
│  │ HTTP:8765│ 口令解析  │ Design    │ Agent Schema  │   │
│  │ MCP 协议 │ Clipboard │ Tokens    │ 5 内置技能    │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Infrastructure (日志 + 诊断) + Utils + Models + Services│   │
│  └──────────────────────────────────────────────────────┘   │
└───────────────────────┬─────────────────────────────────────┘
                        │ HTTP / WebSocket
┌───────────────────────▼─────────────────────────────────────┐
│              WebBridgeServer (服务层)                       │
│  Swift 6 + Hummingbird 2 · Port 8080                       │
│  Push API · Manifest CRUD · Command API · APNs · Health    │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 核心操作链路（秒开闭环）

```
推送到达 (含 appid/URL/deeplink)
        │
        ▼
  用户点击通知 → SuperApp 打开
        │
        ▼
  解析推送字段 → MessageRouter 路由
        │
        ▼
  匹配缓存页面 → CacheEngine 加载本地 HTML
        │
        ▼
  离线秒开（HTML 资源已本地缓存）
        │
        ▼
  HTML 页面调用 41 个原生 Bridge API
        │
        ▼
  缓存管理：刷新策略 / 持久化 / 过期清理
```

### 2.3 数据流向

```
                    ┌──────────────┐
                    │   APNs / Bark│
                    └──────┬───────┘
                           │ 推送
                           ▼
              ┌────────────────────────┐
              │   WebBridgeServer :8080  │
              │  PushRoutes             │
              │  ManifestRoutes         │
              │  CommandRoutes          │
              └───────────┬────────────┘
                          │ HTTP REST
                  ┌───────▼────────┐
                  │  SuperApp      │
                  │  MessageEngine │
                  │  CacheEngine   │
                  └───────┬────────┘
                          │
            ┌─────────────┼─────────────┐
            ▼             ▼             ▼
      ┌──────────┐ ┌──────────┐ ┌──────────┐
      │ WKWebView│ │ Realm DB │ │ File Sys │
      │ Bridge   │ │ 消息存储  │ │ 缓存文件  │
      └──────────┘ └──────────┘ └──────────┘
```

---

## 3. 模块结构

### 3.1 Framework — `Sources/` 目录职责

| 目录 | 文件数 | 职责 | 关键文件 |
|------|--------|------|----------|
| **Bridge/** | 4 | JS↔Native 桥接核心 | HandlerRegistry, HandlerMeta, BridgeError |
| **Handlers/** | 41 | 35 个原生 Handler 实现 | BaseWebNativeHandler, 各功能 Handler |
| **Cache/** | 26 | 离线缓存引擎 | CacheManager, MemoryCache, DiskCache, ManifestStore |
| **Message/** | 10 | 消息推送与路由 | MessageEngine(actor), MessageRouter, BarkChannel, WebhookChannel |
| **WebSocket/** | 6 | WebSocket 双通道通信 | WebSocketEngine(JSON-RPC 2.0), WebSocketClient, WebSocketState |
| **Core/** | 6 | 浏览器核心 | WebBrowserParams, WebJavaScriptBridge, WebViewPool |
| **AI/** | 3 | AI 调试接口 | AIHTTPServer(:8765), AIRouter(MCP), BuiltinAITools(13 工具) |
| **CommandParser/** | 5 | 口令解析引擎 | CommandParser(actor), CommandDecoder(Base64/URL/Plain), ClipboardMonitor |
| **Theme/** | 8 | 设计系统 | ThemeManager, ThemeColors, LucideIcon(50+枚举), 6 组件 |
| **Skills/** | 2 | AI Agent 能力 Schema | SkillRegistry, BuiltinSkills(5 技能), AgentSchema |
| **Infrastructure/** | 8 | 日志 + 诊断 | StructuredLogger(4管道), DiagnosticEngine, EnvironmentInfo |
| **Models/** | 10 | 数据模型 | Manifest, CacheModels, WebPageHistory, URLFavorite |
| **Utils/** | 14 | 工具类 | InputValidator, RetryHelper, NetworkMonitor, L10n |
| **Services/** | 8 | 服务定位 | ServiceLocator, RealmHistoryService, RealmFavoriteService |
| **ViewModels/** | 5 | 视图模型 | CacheManagementVM, WebBrowserVM, HistoryVM 等 |
| **Controllers/** | 11 | 框架层控制器 | WebBrowserVC, CacheManagementVC, QRScannerVC 等 |
| **Views/** | 8 | 框架层视图 | EmptyStateView, LoadingView, CacheAppCell 等 |
| **Base/** | — | 基类 | ViewModel, BaseViewController |
| **Extensions/** | — | 扩展 | WKWebView+Rx 等 |
| **Managers/** | — | 管理器 | URLFavoriteManager 等 |

### 3.2 SuperApp — 页面结构

SuperApp 采用 **MVVM 架构**，共 87 个 Swift 文件：

#### Controllers（44 个 VC）

| 分类 | 页面 | 说明 |
|------|------|------|
| **主页面** | MainViewController | 首页：Token 卡片 + 应用网格 + 快速操作 |
| | TabBarController | 4 Tab: 首页/收信箱/发现/设置 |
| | InboxViewController | 收信箱：消息分组列表 |
| | DiscoverViewController | 发现页：缓存应用网格 |
| | SettingsViewController | 设置页：5 分组配置 |
| **详情页** | MessageDetailViewController | 消息详情 |
| | NotificationDebugViewController | 通知调试（发送测试通知） |
| | TokenManageViewController | Token 管理（URL + 二维码） |
| | TokenGenerateViewController | 推送 URL 生成 |
| | ServerConfigViewController | 服务器配置（连接测试） |
| | AboutViewController | 关于页面 |
| | FavoriteViewController | 收藏管理 |
| | WebAccessViewController | Web 访问管理 |
| | ManagementViewController | 缓存管理 |
| | DebugPanelViewController | Debug 面板（摇一摇触发） |
| **展示页** | ComponentCatalogViewController | 组件目录 |
| | *ShowcaseViewController (16个) | 框架能力展示页（每个模块一个） |
| | ShowcaseTabBarController | 展示页 Tab 容器 |

#### ViewModels（12 个）

MainVM, InboxVM, SettingsVM, TokenManageVM, TokenGenerateVM, ServerConfigVM, APIKeyManageVM, APIKeyExampleVM, FavoriteVM, WebAccessVM, ManifestTestCasesVM

#### Views（ Cells + Components + CustomViews ）

- **Cells**: URLGridCell, TokenCell, APIKeyCell, CodeExampleCell, TestCaseCell, FavoriteCell
- **Components**: ButtonCell, SwitchCell, TextFieldCell, MenuCell, SegmentedCell, ActionSheetView, SettingsHeaderView, UIAuditTool
- **CustomViews**: URLInputView, WebViewDisplayViewController
- **MainViewCells**: 首页专用 Cell

#### Managers（7 个）

AccessTokenManager, APIKeyManager, CommandHandler, PassphraseManager, ServerConfigManager, TokenManager, EngineBootstrap

### 3.3 Server — API 路由

基于 **Hummingbird 2** 框架，端口 **8080**：

| 路由模块 | 路径 | 方法 | 功能 |
|----------|------|------|------|
| **HealthRoutes** | `/health` | GET | 服务健康检查 |
| **PushRoutes** | `/:key/:title/:body` | GET/POST | Bark 兼容推送 |
| | `/register` | POST | 设备 Token 注册 |
| **ManifestRoutes** | `/api/v1/manifests` | GET/POST | Manifest 列表/创建 |
| | `/api/v1/manifests/:id` | GET/PUT/DELETE | Manifest CRUD |
| **CommandRoutes** | `/api/v1/command/generate` | POST | 生成口令（HMAC 签名）|
| | `/api/v1/command/resolve` | POST | 解析口令 |

中间件：
- **CORSMiddleware**: 跨域支持（全部允许）
- **AuthMiddleware**: API Key 鉴权

---

## 4. 设计系统

### 4.1 Design Token 体系

单一数据源: `docs/design-tokens.json` → 自动同步生成:

| 目标 | 文件 | 用途 |
|------|------|------|
| iOS | `Sources/Theme/ThemeTokens.swift` | UIColor/UIFont/CGFloat 常量 |
| CSS | `docs/prototype/design-tokens.css` | CSS 变量（原型用）|

Token 分类（95 个 token / 9 大类）:

| 类别 | 数量 | 示例 |
|------|------|------|
| **Colors** | 24 (Light/Dark) | primary, background, error, success, gradientStart/End |
| **Typography** | 9 | body(17), headline(17sb), title1-3, largeTitle(28b) |
| **Spacing** | 6 | xs(4), sm(8), md(16), lg(24), xl(32), xxl(48) |
| **CornerRadius** | 8 | xs(2) ~ xxl(20), full(999) |
| **Shadows** | 5 | Card, Fab, Modal, NavBar, Tooltip |
| **Opacity** | 7 | badge, disabled, overlay, pressed... |
| **Animation** | 5 | fast(0.15), normal(0.25), slow(0.35), spring, modal(0.5) |
| **Icons.Sizes** | 6 | xs(12) ~ xxl(48) |
| **Breakpoints** | 3 | compact(320), regular(375), large(428) |

同步工具: `tools/sync-tokens.sh`（双向同步 JSON ↔ Swift + CSS）

### 4.2 Lucide 图标系统

| 项目 | 规格 |
|------|------|
| 图标库 | Lucide Icons（开源矢量图标集）|
| 总数 | **1703** PDF 图标 |
| 映射 | `Sources/Theme/LucideIcon.swift` — 50+ case enum |
| 加载 | `Sources/Theme/Lucide.swift` — UIImage extension |
| 资源 | `Sources/Theme/icons.xcassets` |

### 4.3 i18n 国际化方案

| 项目 | 说明 |
|------|------|
| 引擎 | `Sources/Utils/L10n.swift` |
| 策略 | 多层级 Bundle 搜索 + 缓存 |
| 搜索顺序 | Bundle.main → allBundles → allFrameworks |
| API | `L10n.tr("key")` / `L10n.tr("key", arg1, arg2)` |
| 语言包 | `zh-Hans.lproj/Localizable.strings`（中文·主要）|
| | `en.lproj/Localizable.strings`（英文）|

---

## 5. 测试体系

### 5.1 测试套件总览（19 个套件 / 168 个测试文件）

| 套件目录 | 测试内容 | 测试数 | 覆盖状态 |
|----------|----------|--------|----------|
| **HandlerTests** | 35 个 Handler 实现 | ~357 | ✅ 100% 文件覆盖 |
| **ServicesTests** | 服务定位 + Realm 持久化 | ~113 | ✅ 覆盖良好 |
| **ViewModelTests** | 5 个 ViewModel | 65 | ✅ 全覆盖 |
| **BridgeTests** | Handler 注册表 + 元数据 + 错误 | 101 | ✅ 全覆盖 |
| **ModelsTests** | Manifest / Cache / History / Favorite | ~92 | ✅ 良好 |
| **WebSocketTests** | JSON-RPC 2.0 + 连接管理 | 41 | ✅ 全覆盖 |
| **ThemeTests** | ThemeManager + 组件 | 20+ | ✅ 全覆盖 |
| **InfrastructureTests** | 日志 + 诊断 + DebugPanel | ~52 | 🟡 部分 |
| **MessageTests** | Engine + Router + Store + Payload | ~52 | 🟡 核心✅/通道🟡 |
| **AITests** | HTTP Server + Router + MCP | ~34 | 🟡 良好 |
| **CacheTests** | Manager + Disk + Memory + KeyGen | ~41 | 🟡 核心✅/高级🟡 |
| **UtilsTests** | Validator + Retry + Deduplicator | ~40 | 🟡 部分 |
| **CoreTests** | BrowserParams + JSBridge | ~31 | 🟡 部分 |
| **CommandParserTests** | Parser + Decoder + Router + Payload | ~49 | ✅ 全覆盖 |
| **SkillsTests** | SkillRegistry + BuiltinSkills | 12 | ✅ 全覆盖 |
| **BaseTests** | 基类测试 | — | — |
| **ExtensionsTests** | 扩展测试 | — | — |
| **ManagersTests** | 管理器测试 | — | — |
| **e2e** | 端到端测试 | — | — |
| **WebBridgeKitTests** | 主入口测试 | — | — |

**总计**: ~1700+ 测试方法 · 覆盖率 **~87%**（168 测试文件 / 193 源文件）

### 5.2 覆盖率分级

| 状态 | 模块数 | 代表模块 |
|------|--------|----------|
| ✅ 完整覆盖 | 7 | Bridge, Handlers, Theme, CommandParser, Skills, WebSocket, Services |
| 🟡 部分覆盖 | 7 | Core, Cache, Message, AI, Infrastructure, Models, Utils |
| ❌ 无单元测试 | 5 | Controllers, Views, Server 部分, SuperApp, AppTemplate |

---

## 6. 服务依赖

### 6.1 三个开发服务

| 服务 | 端口 | URL | 技术栈 | 用途 |
|------|------|-----|--------|------|
| **WebBridgeServer** | 8080 | http://localhost:8080 | Swift/Hummingbird 2 | 推送通知 / Manifest 下载 / 口令解析 / 命令处理 |
| **Test HTTP Server** | 8081 | http://localhost:8081 | Python | 静态资源服务（缓存功能测试）|
| **Prototype Server** | 8083 | http://localhost:8083 | Python | HTML 设计原型浏览 |

### 6.2 管理命令

```bash
bash scripts/services.sh start     # 启动全部 3 个服务
bash scripts/services.sh stop      # 停止全部
bash scripts/services.sh restart   # 重启
bash scripts/services.sh status    # 运行状态
bash scripts/services.sh verify    # curl 健康检查
bash scripts/services.sh logs      # 最近日志
```

### 6.3 启动顺序

```
1. WebBridgeServer (:8080)   ← 核心后端，其他服务依赖其 API
2. Test HTTP (:8081)         ← 静态资源，独立运行
3. Prototype (:8083)         ← 原型预览，独立运行
```

> SuperApp 启动前必须先启动 WebBridgeServer（推送通知和 Manifest 功能依赖后端）

### 6.4 额内服务（DEBUG 模式）

| 服务 | 端口 | 用途 |
|------|------|------|
| **AI HTTP Server** | 8765 | AI 调试接口（REST + MCP），仅 DEBUG 模式 |

---

## 7. CI/CD

### 7.1 Workflow 概览

**触发条件**: push / PR 到 `main`, `master`, `develop` 分支  
**Runner**: `macos-15`  
**Xcode**: **16.4 锁定**（保证一致性构建）  
**并发控制**: 同分支取消旧运行

### 7.2 Job 列表（5 个 Job）

| # | Job 名称 | 依赖 | 超时 | 说明 |
|---|----------|------|------|------|
| 1 | **SwiftLint** | 无 | 30min | 代码规范检查（0 violations 通过）|
| 2 | **Build** | SwiftLint | 30min | xcodebuild 编译 SuperApp scheme |
| 3 | **Unit Tests** | Build | 60min | 9 个测试 scheme 并行（matrix 策略）|
| 4 | **🚀 Smoke Tests** | Build | 30min | iPhone 15 模拟器 UI 冒烟测试（可重试 3 次）|
| 5 | **🎨 UI Fidelity Tests** | Build | 30min | 视觉回归测试（PIL 截图对比）|

### 7.3 Unit Tests Matrix（9 个 Scheme）

| Scheme | 内容 |
|--------|------|
| CacheTests | 缓存引擎 |
| MessageTests | 消息引擎 |
| AITests | AI 接口 |
| SkillsTests | 技能注册 |
| HandlerTests-Part1 | Handler 前半部分 |
| HandlerTests-Part2 | Handler 后半部分 |
| BridgeTests | Bridge 核心 |
| CoreTests | 浏览器核心 |
| ModelsTests | 数据模型 |

### 7.4 CI 特殊处理

- **Smoke Tests 使用 `continue-on-error: true`**: CI 模拟器无法渲染完整 App UI
- **模拟器动态创建**: macOS-15 runner 无预装 iPhone 模拟器，通过 `xcrun simctl create`
- **重试机制**: 3 次重试 + 独立 resultBundlePath + 模拟器重启
- **Pre-boot cleanup**: `simctl shutdown all && erase all` 避免残留污染
- **Artifact 上传**: 编译结果 / 测试结果 / 截图 / 诊断信息均上传

---

## 附录：四大引擎详细说明

### Bridge Engine
- **JS ↔ Native** 通信桥梁
- **35+ Handler**，涵盖导航/媒体/设备/网络/缓存/消息等
- 元数据自动注册发现机制（HandlerRegistry + HandlerMeta）
- 统一异常体系（8 种错误类型 + 修复建议）

### Cache Engine
- **ManifestCache**: 离线页面清单管理
- **ResourceCache**: HTML/CSS/JS 资源缓存
- **MemoryCache**: LRU/LFU 内存缓存
- **DiskCache**: 磁盘持久化 + 过期淘汰
- **规则引擎**: PageCacheRuleManager + URLRuleMatcher
- 独立模块，不依赖 Bridge

### Message Engine
- **Actor-based** 线程安全单例
- **Protocol-driven** 可插拔通道抽象（MessageChannel）
- **Strategy 模式** 路由（appid→缓存 / url→浏览器 / deeplink→应用）
- **BarkChannel**: Bark 推送通知集成
- **WebhookChannel**: HTTP Webhook 消息接收
- **InMemoryMessageStore** + **UserDefaultsMessageStore**

### WebSocket Engine
- **JSON-RPC 2.0** 协议
- **双通道架构**: JS-Native（via HandlerRegistry）+ App-Server（URLSessionWebSocketTask）
- **Actor-based** 线程安全
- **指数退避重连** + 心跳机制
- 6 源文件 / 41 测试 / 全覆盖
