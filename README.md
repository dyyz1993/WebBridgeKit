# WebBridgeKit

iOS WebView 与原生功能桥接框架

## 📱 功能特性

- 🌐 **WebView 池管理** - 预加载和复用 WebView，提升页面打开速度
- 📦 **ManifestCache 离线缓存** - 基于 manifest.json 的完整离线缓存方案
- 🔗 **JavaScript Bridge** - Web 与原生双向通信
- 📱 **原生功能调用** - 相机、定位、分享、扫码、震动等
- 🎨 **Material Design UI** - 基于 Material Components 的现代化界面
- 📊 **缓存管理** - 智能缓存策略和可视化管理面板

## 🏗️ 架构设计

### 核心模块

```
WebBridgeKit/
├── Sources/
│   ├── Cache/              # 缓存模块
│   │   ├── ManifestCacheManager.swift       # Manifest 缓存管理
│   │   ├── WebResourceCacheManager.swift    # 资源存储管理
│   │   └── ManifestDownloader.swift         # Manifest 下载器
│   ├── Handlers/           # URL Scheme 处理
│   │   └── WebResourceURLSchemeHandler.swift
│   ├── Controllers/        # 视图控制器
│   ├── Services/          # 业务服务
│   ├── Models/            # 数据模型
│   └── Utils/             # 工具类
└── DemoApp/               # 示例应用
```

### 缓存方案

**ManifestCache** (唯一有效方案)

工作流程:
1. 下载 `manifest.json` 获取资源列表
2. 下载所有资源到本地缓存
3. 使用 `loadHTMLString` + `wb-resource://` scheme 加载页面
4. `WebResourceURLSchemeHandler` 拦截请求并返回缓存资源

优势:
- ✅ 完全离线访问
- ✅ 支持所有资源类型 (HTML/CSS/JS/图片/字体等)
- ✅ 版本控制和更新机制
- ✅ 缓存命中率统计

## 🚀 快速开始

### 安装依赖

```bash
pod install
```

### 打开项目

```bash
open WebBridgeKit.xcworkspace
```

### 初始化框架

```swift
import WebBridgeKit

// 在 AppDelegate 中初始化
func application(_ application: UIApplication, 
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    // 初始化 WebBridgeKit (会预热 WebView 池)
    WebBridgeKit.shared.initialize()
    
    return true
}
```

### 使用 ManifestCache

```swift
import WebBridgeKit

// 1. 加载带缓存的页面
let url = URL(string: "https://example.com/app")!
let cacheManager = ManifestCacheManager.shared

cacheManager.loadPage(url: url) { result in
    switch result {
    case .success(let webView):
        // 页面加载成功，可以显示 webView
        self.view.addSubview(webView)
        
    case .failure(let error):
        print("加载失败: \(error)")
    }
}

// 2. 检查缓存状态
if cacheManager.hasCachedManifest(for: url) {
    print("已缓存")
}

// 3. 清理缓存
cacheManager.clearCache(for: url)
```

### JavaScript Bridge 使用

```javascript
// Web 端调用原生功能
window.BarkBridge.callNative('camera', {}, function(result) {
    console.log('拍照结果:', result);
});

// 或使用 Promise 风格 (WebBridgeKit API)
window.WebBridgeKit.camera()
    .then(result => console.log('拍照结果:', result))
    .catch(error => console.error('错误:', error));
```

## 📦 Manifest 格式

```json
{
  "url": "https://example.com/app",
  "version": "1.0.0",
  "resources": [
    {
      "url": "https://example.com/app/index.html",
      "type": "text/html"
    },
    {
      "url": "https://example.com/app/style.css",
      "type": "text/css"
    },
    {
      "url": "https://example.com/app/app.js",
      "type": "application/javascript"
    },
    {
      "url": "https://example.com/app/logo.png",
      "type": "image/png"
    }
  ]
}
```

## 🧪 测试

### 运行单元测试

```bash
xcodebuild test \
  -workspace WebBridgeKit.xcworkspace \
  -scheme DemoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

### 运行 UI 测试

```bash
xcodebuild test \
  -workspace WebBridgeKit.xcworkspace \
  -scheme DemoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:DemoAppUITests
```

## 📚 依赖

- **RxSwift** (6.9.0) - 响应式编程
- **Realm** (10.54.6) - 本地数据库
- **Alamofire** (5.11.0) - 网络请求
- **Kingfisher** (7.12.0) - 图片加载
- **Material** (3.1.8) - Material Design 组件
- **SnapKit** (5.7.1) - 自动布局
- **SwiftSoup** (2.11.3) - HTML 解析

## 🔧 配置

### 缓存配置

```swift
// 设置缓存大小限制
WebResourceCacheManager.shared.maxCacheSize = 100 * 1024 * 1024 // 100MB

// 设置缓存过期时间
WebResourceCacheManager.shared.cacheExpiration = 7 * 24 * 60 * 60 // 7天

// 启用缓存统计
WebResourceCacheManager.shared.enableStatistics = true
```

### WebView 池配置

```swift
// 设置池大小
WebViewPool.shared.poolSize = 3

// 预热 WebView
WebViewPool.shared.warmup {
    print("WebView 池预热完成")
}
```

## 📖 API 文档

### ManifestCacheManager

主要的缓存管理类

```swift
// 加载页面
func loadPage(url: URL, completion: @escaping (Result<WKWebView, Error>) -> Void)

// 检查缓存
func hasCachedManifest(for url: URL) -> Bool

// 清理缓存
func clearCache(for url: URL)
func clearAll()

// 获取缓存统计
func getCacheStats() -> CacheStatistics
```

### WebResourceCacheManager

底层资源存储管理

```swift
// 创建缓存空间
func createCacheSpace(for url: URL) -> String

// 存储资源
func storeResource(cacheID: String, relativePath: String, data: Data, mimeType: String) throws

// 获取资源
func getResource(cacheID: String, relativePath: String) -> (data: Data, mimeType: String)?

// 删除缓存空间
func removeCacheSpace(cacheID: String)
```

## 🐛 已知问题

- iOS 的 `WKNavigationDelegate` 无法拦截子资源加载，因此不支持拦截式缓存
- 大文件缓存可能影响性能，建议设置合理的缓存大小限制

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

## 📞 联系方式

如有问题，请提交 Issue。

---

**版本**: 1.0.0  
**最后更新**: 2026-02-09
