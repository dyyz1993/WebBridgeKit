# WebBridgeKit

![CI](https://github.com/dyyz1993/WebBridgeKit/actions/workflows/ci.yml/badge.svg)

iOS WebView 与原生能力桥接框架，面向超级 App 场景设计。

## 项目介绍

WebBridgeKit 是一个 iOS 原生框架，将 WKWebView 与 41 种原生能力（相机、定位、分享、扫码、AI 等）通过统一的 JS Bridge 暴露给 Web 页面。框架内置六大引擎，覆盖缓存、消息推送、AI 集成、主题、技能插件等超级 App 核心需求，开箱即用。

**核心解决的问题：**
- Web 页面无法直接调用 iOS 原生硬件/系统能力
- 超级 App 需要统一的缓存策略、消息通道和 AI 能力
- 多个业务 App 需要共享同一套桥接基础设施

## 架构概览

三层架构，自底向上：

```
┌─────────────────────────────────────────────────┐
│                  SuperApp                        │  业务应用层
│           (业务代码、路由、配置)                    │
├─────────────────────────────────────────────────┤
│                 AppTemplate                      │  应用模板层
│     (AppDelegate、RootVC、TabBar 模板)            │
├─────────────────────────────────────────────────┤
│                WebBridgeKit                      │  框架层
│  ┌──────┬──────┬──────┬──────┬──────┬──────┐    │
│  │Bridge│Cache │Message│ AI  │Theme │Skills│    │
│  └──────┴──────┴──────┴──────┴──────┴──────┘    │
│           41 Handlers · Core · Services          │
└─────────────────────────────────────────────────┘
```

- **Framework（框架层）**：WebBridgeKit 静态库，包含全部引擎和 Handler
- **AppTemplate（模板层）**：新 App 脚手架，提供 AppDelegate/RootVC/TabBar 模板
- **SuperApp（应用层）**：示例/宿主 App，演示完整用法

## 六大引擎

| 引擎 | 核心类 | 说明 |
|------|--------|------|
| **Bridge Engine** | `WebJavaScriptBridge` | JS ↔ 原生双向通信，Handler 自动注册与懒加载 |
| **Cache Engine** | `CacheManager` / `ManifestCacheManager` | 三级缓存（内存/磁盘/Manifest 离线），URL Scheme 拦截 |
| **Message Engine** | `MessageEngine` | 消息推送（Bark/Webhook 通道）+ 处理器管道 + 路由 |
| **AI Engine** | `AIHTTPServer` / `AIRouter` | 本地 HTTP API + MCP 工具协议，供 AI Agent 调用 |
| **Theme Engine** | `ThemeManager` | 亮/暗主题切换，UIKit 全局样式注入 |
| **Skills Engine** | `SkillRegistry` | 可插拔技能模块，按类别注册/执行/启用/禁用 |

## 快速开始

### 环境要求

- Xcode 15+
- iOS 14.0+
- CocoaPods

### 安装

```bash
# 克隆项目
git clone <repo-url> && cd WebBridgeKit

# 安装依赖
pod install

# 生成 Xcode 工程（使用 XcodeGen）
xcodegen generate

# 打开工作区
open WebBridgeKit.xcworkspace
```

### 初始化

```swift
import WebBridgeKit

// AppDelegate 中
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: ...) -> Bool {
    WebBridgeKit.shared.initialize()  // 注册 Handler + 预热 WebView 池
    return true
}
```

### 创建新 App

基于 AppTemplate 模板创建：

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

Web 页面通过 JS 调用原生能力：

```javascript
// Web 端
window.BarkBridge.callNative('camera', { mode: 'photo' }, function(result) {
    console.log('拍照结果:', result);
});

// Promise 风格
const info = await window.WebBridgeKit.getSystemInfo();
```

原生端注册自定义 Handler：

```swift
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
// 通用缓存
let cache = CacheManager.shared
await cache.set(data, for: "key", expiration: 3600)
let data = await cache.get(for: "key", as: MyData.self)

// Manifest 离线缓存
let manifestCache = ManifestCacheManager.shared
manifestCache.loadPage(url: url) { result in
    switch result {
    case .success(let webView): self.view.addSubview(webView)
    case .failure(let error):   print(error)
    }
}
```

Manifest 格式：

```json
{
  "url": "https://example.com/app",
  "version": "1.0.0",
  "resources": [
    { "url": "https://example.com/app/index.html", "type": "text/html" },
    { "url": "https://example.com/app/style.css",  "type": "text/css" },
    { "url": "https://example.com/app/app.js",     "type": "application/javascript" }
  ]
}
```

### Message Engine

消息通道 + 处理器管道：

```swift
let engine = MessageEngine.shared

// 注册通道
await engine.registerChannel(BarkChannel(serverUrl: "https://api.day.app/xxx"))
await engine.registerChannel(WebhookChannel(url: "https://hooks.example.com/xxx"))

// 设置处理器管道
let pipeline = MessageProcessorPipeline()
pipeline.addProcessor(FilterProcessor())
pipeline.addProcessor(TransformProcessor())
await engine.setPipeline(pipeline)

// 启动所有通道
await engine.startAll()
```

### AI Engine

内置本地 HTTP Server，支持 REST API 和 MCP 工具协议：

```swift
let server = AIHTTPServer(port: 8765)

// 注册自定义路由
await server.router.register(method: .POST, path: "/api/chat") { request in
    return AIResponse.ok(["reply": "Hello"])
}

// 注册 MCP 工具
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

// 应用主题
await themeManager.apply(Theme.dark)

// 监听主题变化
await themeManager.observe { theme in
    // 更新 UI
}

// 应用到 Window
await themeManager.applyToWindow(window)
```

### Skills Engine

```swift
let registry = SkillRegistry.shared

// 注册技能
await registry.register(MySkill())

// 按类别查询
let tools = await registry.listByCategory(.navigation)

// 执行技能
let result = try await registry.execute("mySkill", context: skillContext)
```

## Handler 列表

框架注册了 41 个 Handler，按 12 个分类组织：

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
# 运行全部单元测试（通过 xcodebuild）
xcodebuild test \
  -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# 运行特定模块测试
xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme CacheTests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme MessageTests ...
xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme AITests ...
xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme SkillsTests ...
xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme HandlerTests ...
```

### 集成测试脚本

```bash
./run_tests.sh          # 全部测试
./run_tests.sh basic    # 基础功能测试
./run_tests.sh manifest # Manifest 缓存测试
./run_tests.sh display  # 显示模式测试
```

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

### ci.yml — 持续集成

| Job | 说明 | 触发条件 |
|-----|------|----------|
| **Build** | 编译 SuperApp | push/PR 到 main/develop |
| **Unit Tests** | CacheTests、MessageTests、AITests、SkillsTests、HandlerTests（矩阵并行） | Build 通过后 |
| **Smoke Tests** | 主流程冒烟测试 + 截图收集 | Build 通过后 |
| **Core UI Tests** | 核心功能 UI 测试（并行 3 workers） | Smoke Tests 通过后 |
| **Manifest Tests** | Manifest 缓存专项测试（顺序执行） | Smoke Tests 通过后 |
| **SwiftLint** | 代码风格检查 | 独立运行 |

特性：
- CocoaPods 缓存加速
- 并发控制（同分支取消旧运行）
- 自动截图收集与上传
- JUnit 测试报告发布

### build-ipa.yml — 打包发布

- 触发条件：推送 `v*` tag 或手动触发
- 生成 unsigned IPA，上传 Artifact

## 项目结构

```
WebBridgeKit/
├── Sources/                          # 框架源码
│   ├── AI/                           # AI Engine
│   │   ├── Router/AIRouter.swift     # 路由分发
│   │   ├── Server/AIHTTPServer.swift # HTTP 服务器
│   │   └── Tools/BuiltinAITools.swift
│   ├── Base/                         # 基类
│   │   ├── BaseViewController.swift
│   │   └── ViewModel.swift
│   ├── Bridge/                       # Bridge Engine
│   │   ├── Error/                    # 错误定义
│   │   ├── Meta/HandlerMeta.swift    # Handler 元数据
│   │   └── Registry/                 # 注册表
│   │       ├── HandlerMetaRegistry.swift
│   │       └── HandlerRegistry.swift
│   ├── Cache/                        # Cache Engine
│   │   ├── Implementations/          # Memory/Disk/Hybrid 缓存
│   │   ├── Protocols/                # 缓存协议
│   │   ├── Utils/                    # 缓存工具
│   │   ├── CacheManager.swift        # 通用缓存管理
│   │   ├── ManifestCacheManager.swift
│   │   ├── ManifestURLSchemeHandler.swift
│   │   └── ...
│   ├── Controllers/                  # VC（浏览器、缓存管理等）
│   ├── Core/                         # 核心模块
│   │   ├── WebBridgePool.swift       # Bridge 预热池
│   │   ├── WebBrowserManager.swift
│   │   ├── WebJavaScriptBridge.swift # JS Bridge 核心
│   │   ├── WebViewPool.swift         # WebView 池
│   │   └── ...
│   ├── Extensions/                   # Swift 扩展
│   ├── Handlers/                     # 41 个原生能力 Handler
│   ├── Infrastructure/               # 日志/调试/诊断
│   ├── Managers/                     # 管理器
│   ├── Message/                      # Message Engine
│   │   ├── Channels/                 # Bark/Webhook 通道
│   │   ├── Processors/               # 消息处理器管道
│   │   ├── Protocols/                # 消息协议
│   │   ├── Router/MessageRouter.swift
│   │   ├── Stores/                   # 消息存储
│   │   └── MessageEngine.swift
│   ├── Models/                       # 数据模型
│   ├── Services/                     # 服务层（DI + Mock）
│   ├── Skills/                       # Skills Engine
│   │   ├── BuiltinSkills.swift
│   │   └── SkillRegistry.swift
│   ├── Theme/                        # Theme Engine
│   │   └── ThemeManager.swift
│   ├── Utils/                        # 工具类
│   ├── ViewModels/                   # ViewModel
│   ├── Views/                        # UI 组件
│   └── WebBridgeKit.swift            # 框架入口
├── AppTemplate/                      # 应用模板
│   └── Sources/
│       ├── AppDelegate.swift
│       ├── RootViewController.swift
│       └── TabBarController.swift
├── SuperApp/                         # 示例应用
│   ├── Sources/
│   └── Resources/
├── Tests/                            # 测试
├── Resources/                        # 框架资源（WebBridge.js）
├── docs/                             # 文档
├── scripts/                          # 脚本
├── test-server/                      # 测试服务器
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

## License

MIT License
