# WebBridgeKit 框架功能详解

## 版本信息
- **版本**: 1.0.0
- **分析日期**: 2026-02-09

---

## 📋 目录

1. [核心架构](#核心架构)
2. [JavaScript Bridge 功能](#javascript-bridge-功能)
3. [缓存系统](#缓存系统)
4. [WebView 管理](#webview-管理)
5. [浏览器功能](#浏览器功能)
6. [数据存储](#数据存储)
7. [UI 组件](#ui-组件)
8. [工具类](#工具类)

---

## 🏗️ 核心架构

### 模块划分

```
WebBridgeKit/
├── Core/           # 核心功能 (6个文件)
├── Cache/          # 缓存系统 (18个文件)
├── Handlers/       # JS Bridge 处理器 (41个文件)
├── Controllers/    # 视图控制器
├── Services/       # 业务服务
├── Managers/       # 管理器
├── Models/         # 数据模型
├── Storage/        # 数据存储
├── Views/          # UI 视图
├── ViewModels/     # 视图模型
├── Extensions/     # 扩展
└── Utils/          # 工具类
```

### 核心类

1. **WebBridgeKit** - 框架入口
   - 单例模式
   - 初始化 WebView 池和 Bridge 池
   - 版本管理

2. **WebBrowserManager** - 浏览器管理器
   - 页面打开/关闭
   - 导航历史管理
   - 多种显示模式 (Normal/Modal/Immersive)
   - 缓存支持

3. **WebJavaScriptBridge** - JS-Native 桥接
   - 双向通信
   - 懒加载 Handler
   - 自动日志记录
   - 41 个原生功能 Handler

---

## 🌉 JavaScript Bridge 功能

### 支持的原生功能 (41个)

#### 1. 基础功能 (3个)
- **share** - 分享功能
- **getLocation** - 获取地理位置
- **requestPermission** - 请求权限

#### 2. 系统信息 (2个)
- **getSystemInfo** - 获取系统信息
- **getNetworkInfo** - 获取网络信息

#### 3. 交互反馈 (2个)
- **haptic** - 触觉反馈
- **vibrate** - 震动

#### 4. 剪贴板 (1个)
- **clipboard** - 剪贴板操作

#### 5. 扫码与相机 (3个)
- **scan** - 二维码/条形码扫描
- **camera** - 相机拍照
- **videoStream** - 视频流

#### 6. 语音功能 (3个)
- **speech** - 语音识别
- **audioLevel** - 实时音频音量监控
- **tts** - 语音合成 (Text-to-Speech)

#### 7. 通讯录 (1个)
- **contacts** - 通讯录访问

#### 8. 屏幕与布局 (3个)
- **screen** - 屏幕控制
- **layout** - 布局控制
- **mirroring** - 投屏控制

#### 9. 传感器 (1个)
- **sensors** - 传感器数据 (加速度、陀螺仪等)

#### 10. 媒体与文件 (3个)
- **media** - 媒体操作
- **file** - 文件选择
- **photo** - 相册选择 (iOS 14+)

#### 11. 系统增强 (1个)
- **systemExtra** - 系统扩展功能

#### 12. 蓝牙 (1个)
- **bluetooth** - 蓝牙控制

#### 13. 权限管理 (2个)
- **getPermissionStatus** - 查询权限状态
- **openSettings** - 打开系统设置

#### 14. 页面导航 (6个)
- **openPage** - 打开本地页面
- **closePage** - 关闭当前页面
- **getHistory** - 获取导航历史
- **getPayload** - 获取透传参数
- **goBack** - 后退
- **setModal** - 设置弹窗参数

#### 15. 手势监控 (1个)
- **gesture** - 手势监控

#### 16. 缓存管理 (2个)
- **cacheDebug** - 缓存调试
- **page** - 页面缓存管理

### 使用方式

#### Web 端调用 (旧版 API)
```javascript
window.BarkBridge.callNative('camera', {}, function(result) {
    console.log('拍照结果:', result);
});
```

#### Web 端调用 (新版 Promise API)
```javascript
// 使用 WebBridgeKit API (Promise 风格)
window.WebBridgeKit.camera()
    .then(result => console.log('拍照结果:', result))
    .catch(error => console.error('错误:', error));

// 其他功能
window.WebBridgeKit.location()
window.WebBridgeKit.share({ text: 'Hello' })
window.WebBridgeKit.scan()
window.WebBridgeKit.haptic({ type: 'success' })
```

#### Native 端注册 Handler
```swift
// Handler 采用懒加载机制，自动注册
// 在 WebJavaScriptBridge.registerHandlerFactories() 中定义
```

---

## 📦 缓存系统

### ManifestCache (核心缓存方案)

#### 工作原理
```
1. 下载 manifest.json
   ↓
2. 解析资源列表
   ↓
3. 下载所有资源到本地
   ↓
4. 使用 wb-resource:// scheme 加载
   ↓
5. WebResourceURLSchemeHandler 拦截请求
   ↓
6. 从本地缓存返回资源
```

#### 核心组件

1. **ManifestCacheManager** - 清单缓存管理
   - 下载和解析 manifest.json
   - 管理缓存生命周期
   - 版本控制和更新

2. **WebResourceCacheManager** - 资源存储管理
   - 创建独立缓存空间 (UUID)
   - 存储/读取资源
   - LRU 清理策略
   - 缓存统计

3. **ManifestDownloader** - 清单下载器
   - 下载 manifest.json
   - 下载资源文件
   - 进度回调

4. **WebResourceURLSchemeHandler** - URL Scheme 处理
   - 拦截 `wb-resource://` 请求
   - 返回缓存资源
   - MIME 类型处理

#### Manifest 格式
```json
{
  "url": "https://example.com/app",
  "version": "1.0.0",
  "persistent": true,
  "resources": [
    {
      "url": "https://example.com/app/index.html",
      "type": "text/html"
    },
    {
      "url": "https://example.com/app/style.css",
      "type": "text/css"
    }
  ]
}
```

#### 缓存模式

1. **持久化模式** (`persistent: true`)
   - 启动时预加载
   - 长期保存
   - 适合核心功能页面

2. **懒加载模式** (`persistent: false`)
   - 首次访问时下载
   - 可被 LRU 清理
   - 适合普通页面

#### 使用方式

```swift
// 加载带缓存的页面
let url = URL(string: "https://example.com/app")!
ManifestCacheManager.shared.loadPage(url: url) { result in
    switch result {
    case .success(let webView):
        // 显示 webView
    case .failure(let error):
        print("加载失败: \(error)")
    }
}

// 检查缓存状态
if ManifestCacheManager.shared.hasCachedManifest(for: url) {
    print("已缓存")
}

// 清理缓存
ManifestCacheManager.shared.clearCache(for: url)
```

### 其他缓存组件

1. **WebPageOfflineCacheManager** - 离线页面缓存
2. **SystemURLCacheManager** - 系统 URL 缓存
3. **WebPageHistoryManager** - 页面历史管理
4. **PageCacheRuleManager** - 缓存规则管理
5. **WebCompressedCacheStore** - 压缩缓存存储

---

## 🌐 WebView 管理

### WebViewPool - WebView 池

#### 功能
- 预创建 WebView 实例
- 复用 WebView，提升性能
- 自动回收和清理

#### 使用方式
```swift
// 预热 WebView 池
WebViewPool.shared.warmup {
    print("WebView 池预热完成")
}

// 获取 WebView
let webView = WebViewPool.shared.dequeueWebView()

// 归还 WebView
WebViewPool.shared.enqueueWebView(webView)
```

### WebBridgePool - Bridge 池

#### 功能
- 预创建 WebJavaScriptBridge 实例
- 复用 Bridge，减少初始化开销

#### 使用方式
```swift
// 预热 Bridge 池
WebBridgePool.shared.warmup {
    print("Bridge 池预热完成")
}

// 获取 Bridge
let bridge = WebBridgePool.shared.dequeueBridge()
```

### WebViewPerformanceMonitor - 性能监控

#### 功能
- 监控页面加载时间
- 统计资源加载
- 性能指标收集

---

## 🖥️ 浏览器功能

### 显示模式

1. **Normal** - 普通模式
   - 推入导航栈
   - 显示导航栏
   - 支持后退

2. **Modal** - 弹窗模式
   - 全屏弹窗
   - 自定义关闭按钮
   - 支持手势关闭

3. **Immersive** - 沉浸式模式
   - 隐藏导航栏
   - 全屏显示
   - 适合游戏/视频

### 浏览器参数 (WebBrowserParams)

```swift
struct WebBrowserParams {
    var displayMode: DisplayMode = .normal
    var hideTabBar: Bool = false
    var customTitle: String?
    var showCloseButton: Bool = true
    var allowGestureDismiss: Bool = true
    var backgroundColor: UIColor = .white
}
```

### 使用方式

```swift
// 打开普通浏览器
let url = URL(string: "https://example.com")!
WebBrowserManager.shared.openBrowser(url: url)

// 打开弹窗浏览器
var params = WebBrowserParams()
params.displayMode = .modal
params.showCloseButton = true
WebBrowserManager.shared.openBrowser(url: url, params: params)

// 打开带缓存的浏览器
WebBrowserManager.shared.openBrowserWithCache(
    url: url,
    forceRefresh: false
)

// 关闭浏览器
WebBrowserManager.shared.closeBrowser()

// 后退
WebBrowserManager.shared.goBack()
```

---

## 💾 数据存储

### Realm 数据库

#### 数据模型

1. **WebPageHistory** - 页面历史
   - URL
   - 标题
   - 访问时间
   - 访问次数
   - 缩略图

2. **URLFavorite** - 收藏夹
   - URL
   - 标题
   - 图标
   - 创建时间

3. **CacheEntryRealm** - 缓存条目
   - URL
   - 数据
   - 过期时间
   - MIME 类型

4. **WebCacheStatistics** - 缓存统计
   - 总大小
   - 命中率
   - 文件数量

5. **PageCacheRule** - 页面缓存规则
   - URL 模式
   - 缓存策略
   - 优先级

6. **CacheRule** - 通用缓存规则
   - 匹配规则
   - 缓存时长
   - 更新策略

7. **ServerConfig** - 服务器配置
   - 服务器地址
   - API Key
   - 配置参数

8. **AccessToken** - 访问令牌
   - Token 值
   - 过期时间
   - 权限范围

9. **APIKey** - API 密钥
   - 密钥名称
   - 密钥值
   - 创建时间

### 管理器

1. **WebPageHistoryManager** - 历史管理
2. **URLFavoriteManager** - 收藏管理
3. **APIKeyManager** - API 密钥管理
4. **AccessTokenManager** - 令牌管理
5. **ServerConfigManager** - 服务器配置管理
6. **TabConfigurationManager** - 标签配置管理

---

## 🎨 UI 组件

### 视图控制器

1. **WebBrowserViewController** - 浏览器视图控制器
   - WebView 容器
   - 进度条
   - 工具栏
   - 缓存支持

2. **ModalWebViewController** - 弹窗浏览器
   - 全屏弹窗
   - 关闭按钮
   - 手势支持

3. **WebPageHistoryViewController** - 历史记录
   - 列表展示
   - 搜索功能
   - 删除操作

4. **WebCacheDebugPanelViewController** - 缓存调试面板
   - 缓存统计
   - 清理操作
   - 详细信息

### 视图组件

1. **EmptyStateView** - 空状态视图
2. **LoadingView** - 加载视图
3. **FullScreenProgressViewController** - 全屏进度

### ViewModel

1. **WebBrowserViewModel** - 浏览器视图模型
2. **WebPageHistoryViewModel** - 历史记录视图模型
3. **WebBookmarkViewModel** - 书签视图模型

---

## 🛠️ 工具类

### 日志系统

**WebBridgeLogger** - 统一日志管理
- 分级日志 (Debug/Info/Warning/Error)
- 自动请求/响应日志
- Token 机制
- 文件输出

```swift
// 使用方式
WebBridgeLogger.shared.info("信息日志")
WebBridgeLogger.shared.error("错误日志")

// 自动日志 (Token 机制)
let token = WebBridgeLogToken(action: "camera", input: params)
WebBridgeLogger.shared.logResponse(token: token, result: result)
```

### 扩展

1. **WKWebView+Rx** - RxSwift 扩展
   - 响应式事件绑定
   - 加载状态监听

2. **WKColor** - 颜色工具
   - 十六进制颜色
   - 颜色转换

### 其他工具

1. **HTMLResourceParser** - HTML 资源解析
2. **ResourceDownloader** - 资源下载器
3. **URLRuleMatcher** - URL 规则匹配
4. **GlobPattern** - Glob 模式匹配
5. **WebPageThumbnailGenerator** - 页面缩略图生成

---

## 📊 功能统计

### 代码规模
- **总文件数**: 110 个 Swift 文件
- **核心模块**: 6 个文件
- **缓存系统**: 18 个文件
- **JS Bridge Handler**: 41 个文件
- **视图控制器**: 10+ 个文件
- **数据模型**: 10+ 个文件

### 功能覆盖

| 类别 | 功能数量 |
|------|---------|
| JS Bridge 原生功能 | 41 个 |
| 缓存管理器 | 6 个 |
| 数据模型 | 9 个 |
| 视图控制器 | 10+ 个 |
| 管理器 | 6 个 |
| 工具类 | 5+ 个 |

---

## 🎯 核心特性

### 1. 完整的离线缓存
- ✅ ManifestCache 方案
- ✅ 版本控制
- ✅ 增量更新
- ✅ LRU 清理策略

### 2. 强大的 JS Bridge
- ✅ 41 个原生功能
- ✅ 懒加载机制
- ✅ 自动日志记录
- ✅ Promise API 支持

### 3. 高性能 WebView
- ✅ WebView 池复用
- ✅ Bridge 池复用
- ✅ 性能监控
- ✅ 内存优化

### 4. 灵活的浏览器
- ✅ 3 种显示模式
- ✅ 导航历史管理
- ✅ 自定义参数
- ✅ 手势支持

### 5. 完善的数据管理
- ✅ Realm 数据库
- ✅ 历史记录
- ✅ 收藏夹
- ✅ 缓存统计

### 6. 丰富的 UI 组件
- ✅ 浏览器视图
- ✅ 弹窗视图
- ✅ 历史记录
- ✅ 调试面板

---

## 🚀 使用场景

### 1. 混合应用开发
- Web 页面与原生功能无缝集成
- 热更新支持
- 离线访问

### 2. 小程序容器
- 加载远程小程序
- 原生能力开放
- 安全沙箱

### 3. 内容浏览器
- 新闻阅读
- 文档查看
- 视频播放

### 4. 企业应用
- 内部系统集成
- 权限管理
- 数据缓存

---

## 📝 API 快速参考

### 初始化
```swift
WebBridgeKit.shared.initialize()
```

### 打开页面
```swift
WebBrowserManager.shared.openBrowser(url: url)
WebBrowserManager.shared.openBrowserWithCache(url: url)
```

### JS 调用原生
```javascript
window.WebBridgeKit.camera()
window.WebBridgeKit.location()
window.WebBridgeKit.share({ text: 'Hello' })
```

### 缓存管理
```swift
ManifestCacheManager.shared.loadPage(url: url)
ManifestCacheManager.shared.clearCache(for: url)
WebResourceCacheManager.shared.getCacheStats()
```

### 历史管理
```swift
WebPageHistoryManager.shared.addOrUpdateHistory(url: url)
WebPageHistoryManager.shared.getAllHistory()
```

---

**文档版本**: 1.0.0  
**最后更新**: 2026-02-09
