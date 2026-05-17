# WebBridgeKit

![CI](https://github.com/dyyz1993/WebBridgeKit/actions/workflows/ci.yml/badge.svg)
![Platform](https://img.shields.io/badge/platform-iOS%2014.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

iOS WebView 与原生能力桥接框架，面向超级 App 场景设计。

## 项目简介

WebBridgeKit 是一个 iOS 原生框架，将 WKWebView 与 **41 种原生能力**（相机、定位、分享、扫码、AI 等）通过统一的 JS Bridge 暴露给 Web 页面。框架内置 **6 大引擎 + WebSocket + CommandParser**，覆盖缓存、消息推送、实时通信、AI 调试、主题切换、技能插件等超级 App 核心需求，开箱即用。

**核心解决的问题：**

- Web 页面无法直接调用 iOS 原生硬件/系统能力
- 超级 App 需要统一的缓存策略、消息通道、实时通信和 AI 调试能力
- 多个业务 App 需要共享同一套桥接基础设施

## 架构概览

三层架构，自底向上：

```
┌─────────────────────────────────────────────────┐
│                  SuperApp                        │  业务应用层
│           (业务代码、路由、UI 逻辑)                │
├─────────────────────────────────────────────────┤
│                 AppTemplate                      │  应用模板层
│     (AppDelegate、RootVC、TabBar 模板)            │
├─────────────────────────────────────────────────┤
│                WebBridgeKit                      │  框架层
│  ┌──────┬──────┬──────┬──────┬──────┬──────┐    │
│  │Bridge│Cache │Message│ AI  │Theme │Skills│    │
│  ├──────┴──────┴──────┴──────┴──────┴──────┤    │
│  │       WebSocket · CommandParser           │    │
│  └──────────────────────────────────────────┘    │
│           41 Handlers · Core · Services          │
└─────────────────────────────────────────────────┘
```

| 层级 | 说明 |
|------|------|
| **WebBridgeKit（框架层）** | 静态库，包含全部引擎和 41 个 Handler |
| **AppTemplate（模板层）** | 新 App 脚手架，提供 AppDelegate/RootVC/TabBar 模板，展示 100% 框架能力 |
| **SuperApp（应用层）** | 示例/宿主 App，在模板基础上叠加 UI 业务和交互逻辑 |

## 核心特性

### 6 大引擎

| 引擎 | 核心类 | 说明 |
|------|--------|------|
| **Bridge Engine** | `WebJavaScriptBridge` | JS ↔ 原生双向通信，Handler 自动注册与懒加载，WebView 池化复用 |
| **Cache Engine** | `CacheManager` / `ManifestCacheManager` | 三级缓存（内存/磁盘/Manifest 离线），URL Scheme 拦截，离线秒开 |
| **Message Engine** | `MessageEngine` | 消息推送（Bark/Webhook 通道）+ 处理器管道 + 路由分发 |
| **AI Engine** | `AIHTTPServer` / `AIRouter` | 本地 HTTP API + MCP 工具协议，供 AI Agent 调试框架状态 |
| **Theme Engine** | `ThemeManager` | 亮/暗主题切换，UIKit 全局样式注入，实时主题监听 |
| **Skills Engine** | `SkillRegistry` | 可插拔技能模块，按类别注册/执行/启用/禁用 |

### 基础设施

| 模块 | 核心类 | 说明 |
|------|--------|------|
| **WebSocket Engine** | `WebSocketEngine` / `WebSocketConnection` | 基于 JSON-RPC 协议的实时双向通信，连接池管理，心跳保活，自动重连 |
| **CommandParser** | `CommandParser` / `CommandRouter` | 统一命令解析与路由分发，支持命令注册、参数校验、中间件链 |

## 快速开始

### 环境要求

- Xcode 15+
- iOS 14.0+
- CocoaPods
- XcodeGen

### 安装

```bash
# 克隆项目
git clone git@github.com:dyyz1993/WebBridgeKit.git && cd WebBridgeKit

# 安装依赖
pod install

# 生成 Xcode 工程
xcodegen generate

# 打开工作区
open WebBridgeKit.xcworkspace
```

### 一键开发初始化

仓库内置了开发引导脚本，适合第一次拉起环境或切回项目时快速复位：

```bash
bash scripts/bootstrap-dev.sh
```

它会完成这些事情：

- 检查 `xcodegen`、`pod`、`swiftlint` 等核心工具
- 重新生成 `WebBridgeKit.xcodeproj`
- 执行 `pod install`
- 安装仓库自带 git hooks
- 启动并验证本地 3 个测试服务

如果你只想准备工程、不启动服务：

```bash
bash scripts/bootstrap-dev.sh --no-services
```

如果缺少工具并希望脚本尝试自动安装：

```bash
bash scripts/bootstrap-dev.sh --install-tools
```

### XcodeBuildMCP

仓库已内置项目级 `.xcodebuildmcp/config.yaml`，默认启用了：

- `session-management`
- `project-discovery`
- `simulator`
- `simulator-management`
- `debugging`
- `ui-automation`
- `device`
- `xcode-ide`

基础上下文已经预设为 `WebBridgeKit.xcworkspace` + `SuperApp` + `Debug`。模拟器机型则做成 profile，方便在 MCP 客户端里按本机环境切换：

- `simulator-iphone-16-pro`
- `simulator-iphone-17-pro`
- `ui-tests`

如果你是直接使用 CLI，而不是通过 MCP 客户端管理 session defaults，可以运行：

```bash
xcodebuildmcp setup
```

### 初始化

```swift
import WebBridgeKit

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: ...) -> Bool {
    WebBridgeKit.shared.initialize()  // 注册 Handler + 预热 WebView 池
    return true
}
```

### 创建新 App

```bash
# 1. 复制 AppTemplate 目录
cp -r AppTemplate/ MyNewApp/

# 2. 在 project.yml 中添加新 target
# 3. 在 Podfile 中添加新 target
# 4. 运行 xcodegen generate && pod install
```

AppTemplate 提供的模板文件：
- `AppDelegate.swift` — 框架初始化
- `RootViewController.swift` — 根视图控制器
- `TabBarController.swift` — TabBar 布局

## 引擎使用

### Bridge Engine

```javascript
// Web 端 - 回调风格
window.BarkBridge.callNative('camera', { mode: 'photo' }, function(result) {
    console.log('拍照结果:', result);
});

// Web 端 - Promise 风格
const info = await window.WebBridgeKit.getSystemInfo();
```

```swift
// 原生端 - 注册自定义 Handler
class MyHandler: WebNativeAPI {
    func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        completion(WebBridgeResponse.success(data: ["key": "value"]))
    }
}
bridge.registerHandler(MyHandler(), forAction: "myAction")
```

### Cache Engine

三级缓存架构：Memory → Disk → Manifest 离线包

```swift
let cache = CacheManager.shared
await cache.set(data, for: "key", expiration: 3600)
let data = await cache.get(for: "key", as: MyData.self)

let manifestCache = ManifestCacheManager.shared
manifestCache.loadPage(url: url) { result in
    switch result {
    case .success(let webView): self.view.addSubview(webView)
    case .failure(let error):   print(error)
    }
}
```

### Message Engine

```swift
let engine = MessageEngine.shared

await engine.registerChannel(BarkChannel(serverUrl: "https://api.day.app/xxx"))
await engine.registerChannel(WebhookChannel(url: "https://hooks.example.com/xxx"))

let pipeline = MessageProcessorPipeline()
pipeline.addProcessor(FilterProcessor())
pipeline.addProcessor(TransformProcessor())
await engine.setPipeline(pipeline)
await engine.startAll()
```

### WebSocket Engine

```swift
let ws = WebSocketEngine.shared

await ws.connect(to: URL(string: "wss://example.com/ws")!)

// JSON-RPC 调用
let result = try await ws.call(method: "subscribe", params: ["channel": "updates"])

// 注册事件监听
ws.on("notification") { message in
    print("收到通知: \(message)")
}
```

### AI Engine

```swift
let server = AIHTTPServer(port: 8765)

await server.router.register(method: .POST, path: "/api/chat") { request in
    return AIResponse.ok(["reply": "Hello"])
}

await server.router.registerTool(AITool(
    name: "navigate",
    description: "导航到指定页面",
    category: "navigation"
) { params in ... })

try await server.start()
```

### Theme Engine

```swift
let themeManager = ThemeManager.shared

await themeManager.apply(Theme.dark)

await themeManager.observe { theme in
    // 更新 UI
}

await themeManager.applyToWindow(window)
```

### Skills Engine

```swift
let registry = SkillRegistry.shared

await registry.register(MySkill())
let tools = await registry.listByCategory(.navigation)
let result = try await registry.execute("mySkill", context: skillContext)
```

## Handler 列表

框架注册了 **41 个 Handler**，按 12 个分类组织：

| 分类 | Handler | action | 说明 |
|------|---------|--------|------|
| **硬件** | `WebCameraHandler` | `camera` | 相机拍照/录像 |
| | `WebBluetoothHandler` | `bluetooth` | BLE 蓝牙扫描 |
| | `WebLocationHandler` | `getLocation` | GPS 定位 |
| | `WebScanHandler` | `scan` | QR/条形码扫描 |
| **媒体** | `WebPhotoHandler` | `photo` | 相册选取照片 |
| | `WebMediaHandler` | `media` | 保存图片/文件/上传 |
| | `WebShareHandler` | `share` | 系统分享面板 |
| **反馈** | `WebHapticHandler` | `haptic` | 触感反馈 |
| | `WebVibrateHandler` | `vibrate` | 设备振动 |
| **传感器** | `WebAudioLevelHandler` | `audioLevel` | 麦克风音量监听 |
| | `WebSensorsHandler` | `sensors` | 加速度计/陀螺仪 |
| **语音** | `WebSpeechHandler` | `speech` | 语音识别（STT） |
| | `WebSpeechSynthesisHandler` | `tts` | 语音合成（TTS） |
| **剪贴板** | `WebClipboardHandler` | `clipboard` | 读写剪贴板 |
| **系统** | `WebSystemInfoHandler` | `getSystemInfo` | 设备/电量/版本信息 |
| | `WebNetworkHandler` | `getNetworkInfo` | 网络连接状态 |
| | `WebSystemExtraHandler` | `systemExtra` | Face ID/手电筒/Badge |
| | `WebOpenSettingsHandler` | `openSettings` | 跳转系统设置 |
| | `WebContactsHandler` | `contacts` | 通讯录访问 |
| | `WebLayoutHandler` | `layout` | 横竖屏/全屏控制 |
| | `WebScreenHandler` | `screen` | 防偷窥黑屏/常亮 |
| | `WebGestureHandler` | `gesture` | 手势配置 |
| | `WebMirroringHandler` | `mirroring` | 投屏检测 |
| **权限** | `WebPermissionHandler` | `requestPermission` | 请求系统权限 |
| | `WebPermissionStatusHandler` | `getPermissionStatus` | 查询权限状态 |
| **导航** | `WebOpenPageHandler` | `openPage` | 打开新页面 |
| | `WebClosePageHandler` | `closePage` | 关闭当前页面 |
| | `WebGoBackHandler` | `goBack` | 导航后退 |
| | `WebGetHistoryHandler` | `getHistory` | 导航历史栈 |
| | `WebPayloadHandler` | `getPayload` | 获取原生传参 |
| | `WebSetModalHandler` | `setModal` | 动态调整弹窗 |
| **文件** | `WebFileHandler` | `file` | 文件选择器 |
| **缓存** | `WebPageCacheHandler` | `page` | 预加载/缓存页面 |
| **调试** | `WebCacheDebugHandler` | `cacheDebug` | 缓存调试 API |
| **基础设施** | `WebResourceURLSchemeHandler` | — | wb-resource:// 拦截 |
| | `WebPermissionManager` | — | 权限管理器 |
| | `WebGestureInterceptor` | — | 手势拦截器 |
| | `LazyManifestLoader` | — | 懒加载 Manifest |
| | `PersistentManifestLoader` | — | 持久化 Manifest |
| | `BaseWebNativeHandler` | — | Handler 基类 |
| | `FullScreenProgressViewController` | — | 全屏进度条 |

## 测试

### 单元测试

```bash
xcodebuild test \
  -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### 集成测试脚本

```bash
./run_tests.sh          # 全部测试
./run_tests.sh basic    # 基础功能测试
./run_tests.sh manifest # Manifest 缓存测试
./run_tests.sh display  # 显示模式测试
```

### 测试覆盖

| 模块 | 测试文件数 | 说明 |
|------|-----------|------|
| Bridge | — | 101 测试（含高级注册、并发、错误处理） |
| Handlers | — | 200+ 测试（21 个 Handler 类） |
| WebSocket | — | 41 测试（连接池、心跳、重连、JSON-RPC） |
| Cache | ✓ | 缓存管理、Manifest 离线 |
| Message | ✓ | 通道、处理器管道、路由 |
| AI | ✓ | HTTP Server、Router、MCP 工具 |
| Skills | ✓ | 注册、执行、类别查询 |
| Core / Utils / Services / Infrastructure | ✓ | 基础模块 |

**总计：34 个测试文件，520+ 测试方法**

### 测试目录

```
Tests/
├── AITests/          # AI Engine 测试
├── BridgeTests/      # Bridge Engine 测试
├── CacheTests/       # Cache Engine 测试
├── CoreTests/        # Core 模块测试
├── HandlerTests/     # Handler 测试
├── Infrastructure/   # 基础设施测试
├── MessageTests/     # Message Engine 测试
├── ModelsTests/      # Model 测试
├── ServicesTests/    # Service 测试
├── SkillsTests/      # Skills Engine 测试
├── UtilsTests/       # 工具类测试
├── WebBridgeKitTests/# 框架集成测试
└── e2e/              # 端到端测试
```

## CI/CD

GitHub Actions 自动化流程（`.github/workflows/`）：

| Workflow | Job | 说明 |
|----------|-----|------|
| **ci.yml** | Build | 编译 SuperApp（push/PR → main/develop） |
| | Unit Tests | Cache/Message/AI/Skills/Handler 测试矩阵并行 |
| | Smoke Tests | 主流程冒烟测试 + 截图收集 |
| | Core UI Tests | 核心功能 UI 测试（3 workers 并行） |
| | SwiftLint | 代码风格检查 |
| **build-ipa.yml** | Build IPA | 推送 `v*` tag 或手动触发，生成 unsigned IPA |

特性：CocoaPods 缓存加速、同分支并发取消、自动截图收集、JUnit 测试报告

## 项目结构

```
WebBridgeKit/
├── Sources/                          # 框架源码
│   ├── AI/                           # AI Engine（HTTP Server + Router + MCP Tools）
│   ├── Base/                         # 基类（BaseViewController, ViewModel）
│   ├── Bridge/                       # Bridge Engine（注册表 + 元数据 + 错误）
│   ├── Cache/                        # Cache Engine（Memory/Disk/Manifest 三级缓存）
│   ├── Controllers/                  # VC（浏览器、缓存管理等）
│   ├── Core/                         # 核心模块（Bridge 池、WebView 池、Browser Manager）
│   ├── Extensions/                   # Swift 扩展
│   ├── Handlers/                     # 41 个原生能力 Handler
│   ├── Infrastructure/               # 日志/调试/诊断
│   ├── Managers/                     # 管理器
│   ├── Message/                      # Message Engine（通道 + 处理器 + 路由 + 存储）
│   ├── Models/                       # 数据模型
│   ├── Services/                     # 服务层（DI + Mock）
│   ├── Skills/                       # Skills Engine
│   ├── Theme/                        # Theme Engine
│   ├── Utils/                        # 工具类
│   ├── ViewModels/                   # ViewModel
│   ├── Views/                        # UI 组件
│   ├── WebSocket/                    # WebSocket Engine（JSON-RPC + 连接池 + 心跳）
│   ├── CommandParser/                # 命令解析与路由
│   └── WebBridgeKit.swift            # 框架入口
├── AppTemplate/                      # 应用模板（展示 100% 框架能力）
│   └── Sources/
│       ├── AppDelegate.swift
│       ├── RootViewController.swift
│       └── TabBarController.swift
├── SuperApp/                         # 示例应用（模板 + UI 业务）
│   ├── Sources/
│   └── Resources/
├── Tests/                            # 34 个测试文件，520+ 测试方法
├── Resources/                        # 框架资源（WebBridge.js）
├── docs/                             # 文档
├── scripts/                          # 脚本
├── .github/workflows/                # CI/CD
├── project.yml                       # XcodeGen 配置
├── Podfile                           # CocoaPods 依赖
└── .swiftlint.yml                    # SwiftLint 配置
```

## 依赖

| 库 | 版本 | 用途 |
|----|------|------|
| RxSwift / RxCocoa | ~> 6.0 | 响应式编程 |
| RxDataSources | ~> 5.0 | 列表数据源 |
| Moya / RxSwift | ~> 15.0 | 网络抽象层 |
| Kingfisher | ~> 7.0 | 图片加载缓存 |
| SwiftSoup | ~> 2.6 | HTML 解析 |
| RealmSwift | ~> 10.42 | 本地数据库 |
| ZIPFoundation | ~> 0.9 | ZIP 压缩/解压 |
| Material | ~> 3.1 | Material Design 组件 |
| SnapKit | — | 自动布局 |
| SVProgressHUD | ~> 2.2 | HUD 加载指示器 |

## 贡献

1. Fork 本仓库
2. 创建功能分支：`git checkout -b feature/your-feature`
3. 提交变更：`git commit -m "feat: add your feature"`
4. 推送分支：`git push origin feature/your-feature`
5. 提交 Pull Request

请确保所有测试通过，并遵循 SwiftLint 规范。

## License

MIT License
