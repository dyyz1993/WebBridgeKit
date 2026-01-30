# WebBridgeKit

一个功能强大的 iOS WebView Bridge 框架，支持 32 个原生功能 Handler。

## ✅ 已完成的工作

- ✅ 创建项目目录结构
- ✅ 配置 Podfile（CocoaPods 依赖）
- ✅ 迁移核心架构文件（7个）
- ✅ 迁移 Native Handlers（32个）
- ✅ 迁移 ViewController 和相关文件
- ✅ 迁移缓存和存储文件
- ✅ 迁移资源文件
- ✅ 调整依赖关系（去 Bark 化）
- ✅ 创建 WebBridgeLogger 替代 BarkLogger
- ✅ 重命名文件（BarkWebViewController → WebViewController）

## 项目结构

```
WebBridgeKit/
├── Podfile                          # CocoaPods 依赖配置
├── README.md                        # 本文档
├── scripts/                         # 辅助脚本
│   ├── fix_dependencies.rb          # 依赖修复脚本（已执行）
│   └── rename_files.rb              # 文件重命名脚本（已执行）
├── Sources/
│   ├── Core/                        # 核心架构（7个文件）
│   │   ├── WebJavaScriptBridge.swift    # JS-OC 通信桥接核心
│   │   ├── WebBrowserManager.swift      # 浏览器管理器
│   │   ├── WebBrowserParams.swift       # 浏览器参数配置
│   │   ├── WebBridgePool.swift          # Bridge 预热池
│   │   ├── WebViewPool.swift            # WebView 实例池
│   │   └── WebViewPerformanceMonitor.swift  # 性能监控
│   ├── Handlers/                    # 32 个 Native Handler
│   │   └── BaseWebNativeHandler.swift   # Handler 基类
│   ├── Controllers/                 # ViewController
│   │   ├── WebViewController.swift      # 主 WebView 容器（已重命名）
│   │   ├── ModalWebViewController.swift # 弹窗 WebView
│   │   ├── WebBrowserViewController.swift # 浏览器控制器
│   │   ├── WebPageHistoryViewController.swift # 历史记录
│   │   └── WebPermissionsViewController.swift # 权限管理
│   ├── ViewModels/                  # ViewModel
│   │   └── WebPageHistoryViewModel.swift
│   ├── Models/                      # 数据模型
│   │   └── WebPageHistory.swift
│   ├── Views/                       # UI 组件
│   │   ├── WebPageHistoryCell.swift
│   │   └── WebPageHistoryGalleryCell.swift
│   ├── Cache/                       # 缓存相关
│   │   ├── CacheURLSchemeHandler.swift  # 自定义 URL Scheme（已重命名）
│   │   ├── WebPageThumbnailGenerator.swift
│   │   └── ...
│   ├── Storage/                     # Realm 数据库
│   │   └── RealmConfiguration.swift
│   ├── Extensions/                  # 扩展
│   │   └── WKWebView+Rx.swift
│   └── Utils/                       # 工具类
│       └── WebBridgeLogger.swift    # 日志系统（新增）
└── Resources/
    └── WebBridge.js                 # JavaScript Bridge 文件
```

## 下一步操作

### 1. 在 Xcode 中创建 Framework 项目

1. 打开 Xcode
2. File → New → Project
3. 选择 **Framework** 模板（iOS → Framework）
4. 项目名称：`WebBridgeKit`
5. 位置选择：`/Users/xuyingzhou/Project/temporary/WebBridgeKit`（覆盖当前目录）
   - 或者选择父目录，然后手动移动文件
6. Language: Swift
7. Interface: None（纯代码，无需 Storyboard）
8. 点击创建

### 2. 添加文件到 Xcode 项目

项目创建后，将 `Sources/` 目录下的所有文件添加到 Xcode 项目中：

1. 在 Xcode 左侧项目导航器中，右键点击 `WebBridgeKit` 组
2. 选择 "Add Files to WebBridgeKit..."
3. 选择整个 `Sources/` 目录和 `Resources/` 目录
4. 确保 "Copy items if needed" **未选中**（文件已经在正确位置）
5. 确保 "Create groups" 已选中
6. 点击 "Add"

**重要：确保目录结构与以下一致：**
```
WebBridgeKit/
├── WebBridgeKit.h          # 公共头文件
├── Info.plist             # Framework 配置
└── Sources/               # 所有源代码
```

### 3. 配置 CocoaPods

```bash
cd /Users/xuyingzhou/Project/temporary/WebBridgeKit
pod install
```

然后打开 `WebBridgeKit.xcworkspace` 而不是 `.xcodeproj`。

### 4. 配置 Framework 设置

在 Xcode 项目设置中：

1. **Deployment Settings**:
   - iOS Deployment Target: 14.0
   - Build Libraries for Distribution: Yes（如果需要作为 XCFramework）

2. **Header Files**:
   - 创建 `WebBridgeKit.h` 作为公共头文件
   - 在 "Build Phases" → "Headers" 中将其设为 **Public**

3. **Target Membership**:
   - 确保所有 .swift 文件的 Target Membership 包含 WebBridgeKit

### 5. 处理剩余问题

代码中可能还有一些需要手动处理的问题：

#### 移除 BarkSnackbarController

在 `WebBrowserManager.swift` 中，将 `BarkSnackbarController` 相关代码简化或删除：

```swift
// 如果有类似代码：
if let barkSnackbar = viewController as? BarkSnackbarController {
    return findNavigationController(from: barkSnackbar.rootViewController)
}

// 简化为：
// 直接忽略这个特殊处理
```

#### 检查编译错误

编译项目，检查是否有：
- 缺失的导入（import 语句）
- 未定义的类型
- 循环依赖

### 6. 创建 Demo App（可选）

在同一 Workspace 中创建一个 App 项目来测试 Framework：

1. File → New → Project
2. 选择 **App** 模板
3. 项目名称：`WebBridgeDemo`
4. 位置：`/Users/xuyingzhou/Project/temporary/WebBridgeKit/WebBridgeDemo`
5. 点击创建

然后在 Demo App 的 "General" → "Frameworks, Libraries, and Embedded Content" 中添加 WebBridgeKit。

## 依赖

- SnapKit - 布局
- RxSwift + RxCocoa - 响应式编程
- Moya/RxSwift - 网络请求
- Kingfisher - 图片加载
- SwiftSoup - HTML 解析
- RealmSwift - 数据库

## 功能特性

- 32 个原生功能 Handler
- WebView 池化复用
- Bridge 预热优化
- 性能监控
- 离线缓存支持
- 页面历史记录

## 使用示例

```swift
import WebBridgeKit

// 打开浏览器
WebBrowserManager.shared.openBrowser(
    url: URL(string: "https://example.com")!,
    params: WebBrowserParams(displayMode: .normal),
    from: self
)

// 预热 WebView（应用启动时调用）
WebViewPool.shared.warmup()
WebBridgePool.shared.warmup()
```

## 文件统计

- Swift 文件总数：57 个
- 核心架构：7 个
- Native Handlers：32 个
- ViewController：5 个
- 其他文件：13 个
