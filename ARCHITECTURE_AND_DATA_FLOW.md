# WebBridgeKit 架构与数据流转

## 一、整体架构概览

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Demo App Layer                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │ MainVC       │  │ SettingsVC   │  │ ManagementVC │  ...         │
│  │ (首页)       │  │ (设置)       │  │ (管理)       │              │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘              │
│         │                  │                  │                       │
│         └──────────────────┴──────────────────┘                      │
│                            │                                          │
│                            ▼                                          │
│                  ┌─────────────────┐                                 │
│                  │   ViewModels    │                                 │
│                  │  (MVVM Pattern) │                                 │
│                  └────────┬────────┘                                 │
└───────────────────────────┼──────────────────────────────────────────┘
                            │
                            │ Framework API Calls
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      WebBridgeKit Framework                          │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Core Layer (核心层)                       │   │
│  │  ┌──────────────────┐  ┌──────────────────┐                 │   │
│  │  │ WebBrowserManager│  │ WebViewController│                 │   │
│  │  │  (浏览器管理)    │  │  (WebView容器)   │                 │   │
│  │  └────────┬─────────┘  └────────┬─────────┘                 │   │
│  └───────────┼─────────────────────┼───────────────────────────┘   │
│              │                      │                                │
│  ┌───────────┼──────────────────────┼───────────────────────────┐  │
│  │           │    Cache Layer (缓存层)                          │  │
│  │           ▼                      ▼                            │  │
│  │  ┌──────────────────┐  ┌──────────────────┐                 │  │
│  │  │ WebCacheManager  │  │ManifestCacheManager│               │  │
│  │  │ (WKWebView缓存)  │  │ (Manifest缓存)    │               │  │
│  │  └────────┬─────────┘  └────────┬──────────┘                │  │
│  │           │                      │                            │  │
│  │           ▼                      ▼                            │  │
│  │  ┌──────────────────┐  ┌──────────────────┐                 │  │
│  │  │WebPageHistoryMgr │  │ResourceCacheStore│                 │  │
│  │  │  (历史记录)      │  │  (资源缓存)      │                 │  │
│  │  └──────────────────┘  └──────────────────┘                 │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │              Storage Layer (存储层)                          │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │  │
│  │  │    Realm     │  │ FileSystem   │  │ UserDefaults │      │  │
│  │  │  (数据库)    │  │  (文件系统)  │  │   (配置)     │      │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```


## 二、分层架构详解

### 2.1 Demo App Layer (应用层)

**职责：**
- UI 展示和用户交互
- 业务逻辑处理
- 调用框架 API

**主要组件：**
```
DemoApp/
├── Controllers/          # 视图控制器
│   ├── MainViewController.swift
│   ├── SettingsViewController.swift
│   ├── ManagementViewController.swift
│   └── ...
├── ViewModels/          # 视图模型 (MVVM)
│   ├── MainViewModel.swift
│   ├── SettingsViewModel.swift
│   └── ...
├── Views/               # 自定义视图
│   ├── Cells/
│   ├── Components/
│   └── CustomViews/
└── Managers/            # 应用级管理器
    ├── APIKeyManager.swift
    ├── MessageManager.swift
    └── TokenManager.swift
```

**与框架的交互方式：**
- 通过单例模式访问框架管理器
- 使用 RxSwift 进行响应式编程
- 监听框架发出的通知


### 2.2 WebBridgeKit Framework (框架层)

#### Core Layer (核心层)

**WebBrowserManager (浏览器管理器)**
- 单例模式
- 管理浏览器页面的打开、关闭
- 维护导航历史栈
- 支持多种显示模式（normal/modal/immersive）

**WebViewController (WebView 容器)**
- 封装 WKWebView
- 处理页面加载
- 支持缓存模式
- 提供 JavaScript 桥接

#### Cache Layer (缓存层)

**WebCacheManager (Web 缓存管理器)**
- 管理 WKWebView 的网站数据
- 统计缓存大小
- 自动清理过期缓存
- 支持按域名清理

**ManifestCacheManager (Manifest 缓存管理器)**
- 管理 Manifest 文件
- 处理资源映射
- 拦截资源请求
- 实现离线加载

**WebPageHistoryManager (历史记录管理器)**
- 记录访问历史
- 支持置顶和收藏
- 统计访问次数
- 清理低频记录

**ResourceCacheStore (资源缓存存储)**
- 缓存静态资源（JS/CSS/图片等）
- 支持压缩存储
- 提供快速查询
- 管理缓存生命周期



#### Storage Layer (存储层)

**Realm (数据库)**
- 存储历史记录
- 存储收藏数据
- 存储缓存统计
- 支持复杂查询

**FileSystem (文件系统)**
- 存储 Manifest 文件
- 存储资源缓存
- 存储日志文件
- 管理临时文件

**UserDefaults (配置存储)**
- 存储用户设置
- 存储服务器配置
- 存储 API 密钥
- 存储应用状态



## 三、核心数据流转

### 3.1 打开网页流程

```
用户点击 URL
    │
    ▼
MainViewController
    │
    ├─> MainViewModel (处理业务逻辑)
    │
    ▼
WebBrowserManager.shared.openBrowserWithCache()
    │
    ├─> 检查是否有 Manifest
    │   │
    │   ├─ 有 Manifest ──> ManifestCacheManager
    │   │                      │
    │   │                      ├─> 检查 HTML 缓存
    │   │                      │   ├─ 有缓存 ──> 直接加载
    │   │                      │   └─ 无缓存 ──> 下载并缓存
    │   │                      │
    │   │                      └─> 拦截资源请求
    │   │                          ├─> ResourceCacheStore
    │   │                          │   ├─ 有缓存 ──> 返回缓存
    │   │                          │   └─ 无缓存 ──> 下载并缓存
    │   │                          │
    │   │                          └─> 返回资源数据
    │   │
    │   └─ 无 Manifest ──> 普通加载
    │                          │
    │                          └─> WKWebView 加载
    │
    ▼
WebViewController (显示页面)
    │
    └─> WebPageHistoryManager.addOrUpdateHistory()
        │
        └─> Realm 存储历史记录
```



### 3.2 Manifest 缓存流程

```
┌─────────────────────────────────────────────────────────────┐
│                    Manifest 缓存机制                         │
└─────────────────────────────────────────────────────────────┘

1. 扫描 Manifest URL
   │
   ▼
2. PersistentManifestLoader.fetchManifest()
   │
   ├─> 下载 manifest.json
   │   {
   │     "appid": "com.example.app",
   │     "name": "示例应用",
   │     "resources": {
   │       "index.html": "https://example.com/index.html",
   │       "app.js": "https://example.com/app.js",
   │       "style.css": "https://example.com/style.css"
   │     }
   │   }
   │
   ▼
3. ManifestCacheManager.savePage()
   │
   ├─> 保存 HTML 到 ManifestStore
   │   (Key: pageKey, Value: HTML String)
   │
   ├─> 保存 Manifest 到 ManifestStore
   │   (Key: pageKey, Value: Manifest Object)
   │
   └─> 下载并缓存资源
       │
       ├─> app.js ──> ResourceCacheStore
       ├─> style.css ──> ResourceCacheStore
       └─> images ──> ResourceCacheStore

4. 打开缓存页面
   │
   ▼
5. ManifestCacheManager.loadPage()
   │
   ├─> 从 ManifestStore 读取 HTML
   │
   ├─> 使用 custom:// scheme 加载
   │   webView.loadHTMLString(html, baseURL: "custom://")
   │
   └─> 资源请求被拦截
       │
       ▼
6. ManifestURLSchemeHandler.webView(_:start:)
   │
   ├─> 解析相对路径 (如 "app.js")
   │
   ├─> 从 Manifest 查找真实 URL
   │
   ├─> 检查 ResourceCacheStore
   │   ├─ 有缓存 ──> 返回缓存数据 ✅
   │   └─ 无缓存 ──> 下载并缓存 ⬇️
   │
   └─> 返回资源给 WebView
```



### 3.3 历史记录流程

```
访问网页
    │
    ▼
WebBrowserManager.openBrowser()
    │
    └─> WebPageHistoryManager.addOrUpdateHistory()
        │
        ├─> 检查是否已存在
        │   │
        │   ├─ 存在 ──> 更新记录
        │   │           ├─ visitCount++
        │   │           ├─ lastVisitDate = now
        │   │           └─ 更新 title/favicon
        │   │
        │   └─ 不存在 ──> 创建新记录
        │               ├─ url
        │               ├─ title
        │               ├─ visitCount = 1
        │               └─ lastVisitDate = now
        │
        └─> Realm.write() 保存到数据库

查询历史
    │
    ▼
MainViewModel.refreshData()
    │
    └─> WebPageHistoryManager.getAllHistories()
        │
        ├─> Realm.objects(WebPageHistory.self)
        │
        ├─> 按 lastVisitDate 降序排序
        │
        └─> 返回 Results<WebPageHistory>
            │
            ▼
        MainViewController 显示列表
            │
            ├─> 置顶项 (isPinned = true)
            ├─> 收藏项 (isFavorite = true)
            └─> 最近访问
```



### 3.4 缓存管理流程

```
┌─────────────────────────────────────────────────────────────┐
│                    缓存管理数据流                            │
└─────────────────────────────────────────────────────────────┘

查看缓存列表
    │
    ▼
CacheManagementViewController
    │
    └─> CacheManagementViewModel.transform()
        │
        └─> ManifestCacheManager.shared.getStats()
            │
            ├─> ManifestStore.getAllPageKeys()
            │   └─> 返回所有 pageKey 列表
            │
            ├─> 遍历每个 pageKey
            │   │
            │   ├─> getManifest(for: pageKey)
            │   │   └─> 获取 Manifest 信息
            │   │
            │   └─> ResourceCacheStore.getSize(for: pageKey)
            │       └─> 计算资源缓存大小
            │
            └─> 返回 [CacheAppInfo]
                │
                ▼
            显示缓存列表

删除缓存
    │
    ▼
用户点击删除
    │
    └─> ManifestCacheManager.removeCacheByAppID()
        │
        ├─> 查找所有匹配的 pageKey
        │
        ├─> 遍历删除
        │   │
        │   ├─> ManifestStore.removeHTML()
        │   ├─> ManifestStore.removeManifest()
        │   └─> ResourceCacheStore.removeAll(for: pageKey)
        │
        ├─> 删除物理文件
        │   └─> FileManager.removeItem()
        │
        └─> 发送通知
            └─> NotificationCenter.post("ManifestCacheDidUpdate")
                │
                ▼
            UI 自动刷新
```



## 四、通讯机制

### 4.1 Demo App → Framework

**方式一：直接调用单例方法**
```swift
// Demo App 代码
WebBrowserManager.shared.openBrowserWithCache(
    url: url,
    params: params,
    from: navigationController
)

// Framework 处理
// 1. 创建 WebViewController
// 2. 检查缓存
// 3. 加载页面
// 4. 记录历史
```

**方式二：通过 ViewModel 封装**
```swift
// Demo App - ViewModel
class MainViewModel {
    func openURL(_ url: URL) {
        // 业务逻辑处理
        WebBrowserManager.shared.openBrowser(url: url)
    }
}

// Demo App - ViewController
viewModel.openURL(url)
```

**方式三：RxSwift 响应式调用**
```swift
// Demo App
output.openURL
    .drive(onNext: { [weak self] url in
        WebBrowserManager.shared.openBrowser(url: url)
    })
    .disposed(by: rx)
```



### 4.2 Framework → Demo App

**方式一：NotificationCenter 通知**
```swift
// Framework 发送通知
NotificationCenter.default.post(
    name: NSNotification.Name("ManifestCacheDidUpdate"),
    object: nil
)

// Demo App 监听通知
NotificationCenter.default.rx
    .notification(NSNotification.Name("ManifestCacheDidUpdate"))
    .subscribe(onNext: { [weak self] _ in
        self?.viewModel.refreshData()
    })
    .disposed(by: rx)
```

**常用通知列表：**
- `ManifestCacheDidUpdate` - Manifest 缓存更新
- `WebPageHistoryUpdated` - 历史记录更新
- `QRScannerDidScanURL` - 二维码扫描完成
- `AutomationTestOpenURL` - 自动化测试触发
- `didReceivePushMessage` - 收到推送消息

**方式二：Delegate 回调**
```swift
// Framework 定义协议
public protocol WebViewDelegate: AnyObject {
    func webViewDidFinishLoad(_ webView: WKWebView)
    func webViewDidFail(_ webView: WKWebView, error: Error)
}

// Demo App 实现协议
extension MainViewController: WebViewDelegate {
    func webViewDidFinishLoad(_ webView: WKWebView) {
        // 处理加载完成
    }
}
```

**方式三：RxSwift Observable**
```swift
// Framework 提供 Observable
public func fetchCacheStatistics() -> Observable<[WebCacheStatistics]> {
    return Observable.create { observer in
        // 异步获取数据
        observer.onNext(stats)
        observer.onCompleted()
        return Disposables.create()
    }
}

// Demo App 订阅
WebCacheManager.shared.fetchCacheStatistics()
    .subscribe(onNext: { stats in
        // 更新 UI
    })
    .disposed(by: disposeBag)
```



### 4.3 Framework 内部通讯

**单例之间的调用**
```swift
// WebBrowserManager 调用其他管理器
class WebBrowserManager {
    func openBrowser(url: URL) {
        // 1. 记录历史
        WebPageHistoryManager.shared.addOrUpdateHistory(url: url)
        
        // 2. 检查缓存
        if let manifest = ManifestCacheManager.shared.getCachedManifest(for: pageKey) {
            // 使用缓存
        }
        
        // 3. 创建 WebView
        let webVC = WebViewController(url: url)
    }
}
```

**依赖注入**
```swift
// ManifestCacheManager 依赖其他组件
class ManifestCacheManager {
    private let manifestStore: ManifestStore
    private let resourceCache: ResourceCache
    
    private init() {
        self.manifestStore = ManifestStore.shared
        self.resourceCache = ResourceCache.shared
    }
}
```

**协议解耦**
```swift
// 定义协议
protocol CacheStorageProtocol {
    func save(_ data: Data, for key: String)
    func load(for key: String) -> Data?
}

// 实现协议
class ResourceCache: CacheStorageProtocol {
    func save(_ data: Data, for key: String) { }
    func load(for key: String) -> Data? { }
}
```



## 五、关键数据结构

### 5.1 Manifest 数据结构

```swift
public class Manifest: Codable {
    public var appid: String?           // 应用标识符
    public var name: String?            // 应用名称
    public var version: String?         // 版本号
    public var resources: [String: String] = [:]  // 资源映射
    // Key: 相对路径 (如 "app.js")
    // Value: 真实 URL (如 "https://example.com/app.js")
}
```

### 5.2 WebPageHistory 数据结构

```swift
public class WebPageHistory: Object {
    @Persisted(primaryKey: true) public var id: String
    @Persisted public var url: String
    @Persisted public var title: String?
    @Persisted public var favicon: Data?
    @Persisted public var visitCount: Int = 0
    @Persisted public var lastVisitDate: Date
    @Persisted public var isPinned: Bool = false
    @Persisted public var isFavorite: Bool = false
    @Persisted public var isCached: Bool = false
    @Persisted public var cacheSize: Int64 = 0
}
```

### 5.3 ResourceData 数据结构

```swift
public struct ResourceData {
    public let relativePath: String    // 相对路径
    public let data: Data              // 资源数据
    public let mimeType: String        // MIME 类型
}
```

### 5.4 CacheAppInfo 数据结构

```swift
public struct CacheAppInfo {
    public let appID: String           // 应用 ID
    public let name: String            // 应用名称
    public let pageCount: Int          // 页面数量
    public let totalSize: Int64        // 总大小
    public let lastUpdate: Date        // 最后更新时间
}
```



## 六、完整用例流程图

### 6.1 用户扫码打开应用

```
┌──────────┐
│  用户    │
└────┬─────┘
     │ 1. 点击扫码按钮
     ▼
┌─────────────────────┐
│ MainViewController  │
└──────────┬──────────┘
           │ 2. 打开扫码页面
           ▼
┌─────────────────────────┐
│ QRScannerViewController │
└──────────┬──────────────┘
           │ 3. 扫描二维码
           │ 获取 Manifest URL
           ▼
┌─────────────────────────┐
│ NotificationCenter      │
│ post("QRScannerDidScan")│
└──────────┬──────────────┘
           │ 4. 通知主页
           ▼
┌─────────────────────┐
│ MainViewController  │
│ handleScannedResult │
└──────────┬──────────┘
           │ 5. 判断 URL 类型
           ├─ Manifest URL ──┐
           │                  │
           │                  ▼
           │         ┌──────────────────────────┐
           │         │ PersistentManifestLoader │
           │         │ fetchManifest()          │
           │         └──────────┬───────────────┘
           │                    │ 6. 下载 manifest.json
           │                    ▼
           │         ┌──────────────────────────┐
           │         │ ManifestCacheManager     │
           │         │ savePage()               │
           │         └──────────┬───────────────┘
           │                    │ 7. 保存 HTML + Manifest
           │                    │    下载并缓存资源
           │                    ▼
           │         ┌──────────────────────────┐
           │         │ ResourceCacheStore       │
           │         └──────────────────────────┘
           │
           └─ 普通 URL ────┐
                           │
                           ▼
                  ┌──────────────────────┐
                  │ WebBrowserManager    │
                  │ openBrowser()        │
                  └──────────┬───────────┘
                             │ 8. 创建 WebViewController
                             │    加载页面
                             ▼
                  ┌──────────────────────┐
                  │ WebViewController    │
                  └──────────┬───────────┘
                             │ 9. 显示页面
                             ▼
                  ┌──────────────────────┐
                  │ WebPageHistoryManager│
                  │ addOrUpdateHistory() │
                  └──────────────────────┘
```



### 6.2 用户查看缓存管理

```
┌──────────┐
│  用户    │
└────┬─────┘
     │ 1. 切换到管理 Tab
     ▼
┌─────────────────────────┐
│ ManagementViewController│
└──────────┬──────────────┘
           │ 2. 选择"缓存"分段
           ▼
┌──────────────────────────────┐
│ CacheManagementViewController│
└──────────┬───────────────────┘
           │ 3. viewWillAppear
           ▼
┌─────────────────────────┐
│ CacheManagementViewModel│
└──────────┬──────────────┘
           │ 4. transform(input)
           │    refresh trigger
           ▼
┌─────────────────────────┐
│ ManifestCacheManager    │
│ .shared                 │
└──────────┬──────────────┘
           │ 5. 获取缓存信息
           ├─> ManifestStore.getAllPageKeys()
           │   └─> 返回所有 pageKey
           │
           ├─> 遍历每个 pageKey
           │   ├─> getManifest(for: pageKey)
           │   │   └─> 读取 Manifest
           │   │
           │   └─> ResourceCacheStore.getSize()
           │       └─> 计算缓存大小
           │
           └─> 返回 [CacheAppInfo]
               │
               ▼
┌─────────────────────────┐
│ CacheManagementViewModel│
│ output.cacheApps        │
└──────────┬──────────────┘
           │ 6. Driver 驱动 UI
           ▼
┌──────────────────────────────┐
│ CacheManagementViewController│
│ tableView.reloadData()       │
└──────────────────────────────┘
           │
           ▼
     显示缓存列表
     ├─ 应用名称
     ├─ AppID
     ├─ 缓存大小
     ├─ 页面数量
     └─ 最后更新时间
```



### 6.3 用户删除缓存

```
┌──────────┐
│  用户    │
└────┬─────┘
     │ 1. 左滑或长按
     │    选择"删除"
     ▼
┌──────────────────────────────┐
│ CacheManagementViewController│
│ confirmDelete(appID)         │
└──────────┬───────────────────┘
           │ 2. 弹出确认对话框
           │    用户确认
           ▼
┌──────────────────────────────┐
│ deleteCacheDirectly(appID)   │
└──────────┬───────────────────┘
           │ 3. 调用框架删除
           ▼
┌─────────────────────────┐
│ ManifestCacheManager    │
│ removeCacheByAppID()    │
└──────────┬──────────────┘
           │ 4. 查找匹配的 pageKey
           │
           ├─> ManifestStore.getAllPageKeys()
           │   └─> 遍历所有 pageKey
           │       └─> 检查 manifest.appid
           │
           ├─> 删除匹配的缓存
           │   ├─> ManifestStore.removeHTML()
           │   ├─> ManifestStore.removeManifest()
           │   └─> ResourceCacheStore.removeAll()
           │
           ├─> 删除物理文件
           │   └─> FileManager.removeItem()
           │
           └─> 发送通知
               │
               ▼
┌─────────────────────────┐
│ NotificationCenter      │
│ post("CacheDidUpdate")  │
└──────────┬──────────────┘
           │ 5. 通知 UI 更新
           ▼
┌──────────────────────────────┐
│ CacheManagementViewController│
│ handleCacheUpdate()          │
└──────────┬───────────────────┘
           │ 6. 刷新列表
           ▼
     显示更新后的缓存列表
```



## 七、线程模型

### 7.1 主线程操作

**必须在主线程执行的操作：**
- 所有 UI 更新
- WKWebView 操作（loadHTMLString, load, etc.）
- WKWebsiteDataStore 操作
- UIViewController 导航操作（push, pop, present, dismiss）
- NotificationCenter 发送通知（建议）

```swift
// 确保在主线程执行
DispatchQueue.main.async {
    webView.loadHTMLString(html, baseURL: baseURL)
    navigationController?.pushViewController(vc, animated: true)
}
```

### 7.2 后台线程操作

**可以在后台线程执行的操作：**
- 网络请求
- 文件读写
- 数据库操作（Realm 需要在同一线程）
- 数据处理和计算
- 缓存管理

```swift
// 后台线程处理
DispatchQueue.global(qos: .userInitiated).async {
    // 数据处理
    let result = processData()
    
    // 回到主线程更新 UI
    DispatchQueue.main.async {
        self.updateUI(with: result)
    }
}
```

### 7.3 Realm 线程安全

**Realm 的线程规则：**
- Realm 对象不能跨线程传递
- 每个线程需要自己的 Realm 实例
- 使用 ThreadSafeReference 或冻结对象跨线程

```swift
// 错误示例 ❌
DispatchQueue.global().async {
    let realm = try! Realm()
    let history = realm.objects(WebPageHistory.self).first
    
    DispatchQueue.main.async {
        // 崩溃！history 对象来自另一个线程
        self.label.text = history?.title
    }
}

// 正确示例 ✅
DispatchQueue.global().async {
    let realm = try! Realm()
    let history = realm.objects(WebPageHistory.self).first
    
    // 创建独立副本
    let historyCopy = history.map { WebPageHistory(value: $0) }
    
    DispatchQueue.main.async {
        self.label.text = historyCopy?.title
    }
}
```



## 八、性能优化策略

### 8.1 缓存策略

**多级缓存架构：**
```
请求资源
    │
    ├─> Level 1: 内存缓存 (ResourceCache)
    │   ├─ 命中 ──> 立即返回 (最快)
    │   └─ 未命中 ──> 继续
    │
    ├─> Level 2: 磁盘缓存 (FileSystem)
    │   ├─ 命中 ──> 读取文件返回 (快)
    │   └─ 未命中 ──> 继续
    │
    └─> Level 3: 网络请求
        └─> 下载 ──> 缓存到 Level 1 & 2 ──> 返回 (慢)
```

### 8.2 懒加载策略

**Manifest 资源懒加载：**
- 只在需要时下载资源
- 优先加载关键资源（HTML/CSS/JS）
- 延迟加载图片和媒体文件
- 支持预加载常用资源

```swift
// 懒加载实现
func fetchResource(relativePath: String) {
    // 1. 检查缓存
    if let cached = resourceCache.get(relativePath) {
        return cached
    }
    
    // 2. 按需下载
    downloadResource(relativePath) { data in
        // 3. 缓存
        resourceCache.set(data, for: relativePath)
    }
}
```

### 8.3 WebView 池化

**WebView 复用机制：**
- 预创建 WebView 实例
- 复用已有的 WebView
- 减少创建开销
- 提升打开速度

```swift
class WebViewPool {
    private var pool: [WKWebView] = []
    
    func dequeue() -> WKWebView {
        if let webView = pool.popLast() {
            return webView
        }
        return createNewWebView()
    }
    
    func enqueue(_ webView: WKWebView) {
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        pool.append(webView)
    }
}
```



### 8.4 自动清理机制

**定期清理策略：**
```swift
// 应用启动时执行
func performAutoCleanup() {
    DispatchQueue.global(qos: .utility).async {
        // 1. 清理低频历史记录（保留收藏和置顶）
        WebPageHistoryManager.shared.cleanupLowFrequencyItems(limit: 50)
        
        // 2. 清理未使用的资源缓存（7天未访问）
        WebResourceCacheManager.shared.cleanupUnusedResources(
            olderThan: 7 * 24 * 3600
        )
        
        // 3. 清理旧的缩略图
        WebPageHistoryManager.shared.cleanOldThumbnails(keepLatest: 100)
    }
}
```

## 九、错误处理

### 9.1 网络错误处理

```swift
// 下载资源失败
func fetchResource(url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            // 网络错误
            completion(.failure(error))
            return
        }
        
        guard let data = data else {
            // 数据为空
            completion(.failure(ManifestCacheError.emptyData))
            return
        }
        
        completion(.success(data))
    }.resume()
}
```

### 9.2 缓存错误处理

```swift
enum ManifestCacheError: Error {
    case managerDeallocated      // 管理器已释放
    case resourceNotFound(String) // 资源未找到
    case emptyData               // 数据为空
    case invalidManifest         // 无效的 Manifest
    case storageError(Error)     // 存储错误
}
```

### 9.3 Realm 错误处理

```swift
// 安全的 Realm 操作
func safeRealmWrite(_ block: (Realm) throws -> Void) {
    do {
        let realm = try Realm()
        try realm.write {
            try block(realm)
        }
    } catch {
        print("❌ Realm error: \(error)")
        // 记录错误日志
        WebBridgeLogger.shared.log(.error, "Realm write failed: \(error)")
    }
}
```



## 十、总结

### 10.1 架构特点

**分层清晰：**
- Demo App 层：UI 和业务逻辑
- Framework 层：核心功能和缓存管理
- Storage 层：数据持久化

**职责明确：**
- WebBrowserManager：浏览器管理
- ManifestCacheManager：Manifest 缓存
- WebPageHistoryManager：历史记录
- ResourceCacheStore：资源缓存

**解耦合：**
- 单例模式提供全局访问
- 协议定义接口规范
- 通知机制实现松耦合
- RxSwift 实现响应式编程

### 10.2 数据流转特点

**单向数据流：**
```
User Action → ViewController → ViewModel → Framework → Storage
                                                ↓
                                            Notification
                                                ↓
                                            ViewModel → ViewController → UI Update
```

**异步处理：**
- 网络请求在后台线程
- 数据处理在后台线程
- UI 更新在主线程
- Realm 操作线程安全

**缓存优先：**
- 优先使用缓存数据
- 按需下载网络资源
- 自动缓存新数据
- 定期清理过期数据

### 10.3 通讯机制特点

**多种通讯方式：**
- 直接调用：简单直接
- 通知机制：松耦合
- RxSwift：响应式
- Delegate：回调模式

**线程安全：**
- 主线程处理 UI
- 后台线程处理数据
- Realm 线程隔离
- 使用锁保护共享资源

### 10.4 最佳实践

1. **使用单例模式访问框架功能**
2. **通过 ViewModel 封装业务逻辑**
3. **使用 RxSwift 处理异步操作**
4. **监听通知更新 UI**
5. **确保线程安全**
6. **合理使用缓存**
7. **及时清理资源**
8. **完善错误处理**

---

**文档版本：** 1.0  
**最后更新：** 2026-02-09  
**维护者：** WebBridgeKit Team
