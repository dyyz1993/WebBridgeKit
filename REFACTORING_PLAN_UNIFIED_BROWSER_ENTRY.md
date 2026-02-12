# WebBrowserManager 统一入口重构方案

## 一、背景

当前 `WebBrowserManager` 存在两个独立的入口方法，导致代码重复和使用混乱：

| 方法 | Manifest 支持 | 用途 |
|------|---------------|--------|
| `openBrowser()` | ❌ 不支持 | 普通页面打开 |
| `openBrowserWithCache()` | ✅ 支持 | Manifest 缓存页面打开 |

**问题**：
- 两个方法功能重叠，代码重复
- 使用者需要明确选择使用哪个方法
- 容易误用（普通调用导致无 Manifest 缓存）
- 维护成本高，需要同步修改两处

## 二、重构目标

**统一为单一入口**，所有浏览器打开自动支持 Manifest 缓存检测。

```
重构前：openBrowser() + openBrowserWithCache()  (两个方法)
重构后：openBrowser()  (一个方法，自动 Manifest)
```

## 三、设计原则

1. **单一入口** - 只保留 `openBrowser()` 方法
2. **自动检测** - 自动检查并应用 Manifest 缓存
3. **破坏性变更** - 不保留旧方法，强制迁移（编译期发现所有调用点）
4. **参数扩展** - 添加 `forceRefresh` 和 `animated` 可选参数
5. **全模式支持** - Normal/Immersive/Modal 三种模式统一处理

## 四、架构图

### 重构前

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        当前架构 (两个独立入口)                           │
└─────────────────────────────────────────────────────────────────────────────────┘

                    WebBrowserManager
                            │
        ┌───────────────────┴───────────────────┐
        │                                   │
        ▼                                   ▼
 ┌──────────────────────┐      ┌──────────────────────────┐
 │  openBrowser()       │      │ openBrowserWithCache()  │
 │                      │      │                        │
 │ ❌ 无 Manifest       │      │ ✅ 有 Manifest         │
 └──────────┬───────────┘      └──────────┬───────────────┘
            │                           │
            ▼                           ▼
     ┌──────────────────────────────────────────┐
     │  Normal/Immersive/Modal           │
     └──────────┬───────────────────────────┘
                │
                ▼
     ┌──────────────────────────────────────────┐
     │    WebBrowserViewController          │
     └──────────┬───────────────────────────┘
                │
        ┌───────┴────────┐
        │                │
        ▼                ▼
  ┌──────────┐    ┌──────────────────┐
  │ loadURL() │    │loadURLWithCache()│
  │           │    │                 │
  │ 无 Manifest    │    │ 有 Manifest     │
  └──────────┘    └──────────────────┘
```

### 重构后

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    重构后架构 (单一入口，自动 Manifest)                      │
└─────────────────────────────────────────────────────────────────────────────────┘

                    WebBrowserManager
                            │
                            ▼
                   ┌──────────────────┐
                   │  openBrowser()  │
                   │  (统一入口)       │
                   │  - forceRefresh   │
                   │  - animated       │
                   │  - 自动 Manifest  │
                   └────────┬─────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
  ┌──────────┐      ┌──────────┐      ┌──────────┐
  │  Normal   │      │Immersive │      │  Modal    │
  └─────┬────┘      └─────┬────┘      └─────┬────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            │
                            ▼
              ┌──────────────────────────┐
              │WebBrowserViewController │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────────┐
              │loadURLWithCache()     │
              │  (统一加载入口)        │
              │  - 自动 Manifest 检测  │
              │  - LazyManifestLoader    │
              └──────────────────────────┘
```

## 五、修改文件清单

### 核心修改 (3 个文件)

| 文件 | 修改内容 |
|-------|---------|
| `Sources/Core/WebBrowserManager.swift` | 合并方法，统一入口 |
| `Sources/Controllers/WebBrowserViewController.swift` | 修改加载逻辑 |
| `Sources/Services/Protocols/ManagerProtocols.swift` | 更新协议定义 |

### 可选更新 (文档/调用点)

| 文件 | 说明 |
|-------|-------|
| `DemoApp/Sources/AppDelegate.swift` | 移除 `forceRefresh` 显式传参 |
| 各文档 | 更新示例代码 |

## 六、详细修改方案

### 6.1 WebBrowserManager.swift

#### 6.1.1 修改 `openBrowser()` 签名

```swift
/// 打开浏览器（统一入口，自动支持 Manifest 缓存）
/// - Parameters:
///   - url: 要加载的 URL
///   - params: 浏览器配置参数
///   - forceRefresh: 是否强制刷新（绕过缓存），默认 false
///   - animated: 是否使用动画，默认 true
///   - sourceViewController: 来源 ViewController（可选）
///   - completion: 完成回调，返回 Result
public func openBrowser(
    url: URL,
    params: WebBrowserParams? = nil,
    forceRefresh: Bool = false,        // ← 新增
    animated: Bool = true,             // ← 新增
    from sourceViewController: UIViewController? = nil,
    completion: ((Result<Void, Error>) -> Void)? = nil
)
```

#### 6.1.2 修改 `openNormalBrowser()`

```swift
private func openNormalBrowser(
    url: URL,
    params: WebBrowserParams,
    forceRefresh: Bool,               // ← 新增
    animated: Bool,                   // ← 新增
    from sourceViewController: UIViewController?
) {
    os_log("=== openNormalBrowser ===", log: OSLog.default, type: .info)

    guard let navController = getNavigationController(from: sourceViewController) else {
        return
    }

    let webVC = createWebViewController(for: url, params: params)
    addToNavigationStack(webVC, url: url, params: params)

    navController.pushViewController(webVC, animated: animated)  // ← 使用 animated 参数
    currentBrowser = webVC

    // 🔥 统一调用 loadURLWithCache
    if let browserVC = webVC as? WebBrowserViewController {
        browserVC.loadURLWithCache(url, forceRefresh: forceRefresh)
    }
}
```

#### 6.1.3 修改 `openImmersiveBrowser()`

```swift
private func openImmersiveBrowser(
    url: URL,
    params: WebBrowserParams,
    forceRefresh: Bool,               // ← 新增
    animated: Bool,                   // ← 新增
    from sourceViewController: UIViewController?
) {
    guard let navController = getNavigationController(from: sourceViewController) else {
        return
    }

    let webVC = createWebViewController(for: url, params: params)
    addToNavigationStack(webVC, url: url, params: params)

    navController.pushViewController(webVC, animated: animated)  // ← 使用 animated 参数
    currentBrowser = webVC

    // 🔥 统一调用 loadURLWithCache
    if let browserVC = webVC as? WebBrowserViewController {
        browserVC.loadURLWithCache(url, forceRefresh: forceRefresh)
    }
}
```

#### 6.1.4 修改 `openModalBrowser()`

```swift
private func openModalBrowser(
    url: URL,
    params: WebBrowserParams,
    forceRefresh: Bool,               // ← 新增
    animated: Bool,                   // ← 新增
    from sourceViewController: UIViewController?
) {
    let webVC = createWebViewController(for: url, params: params)
    let navController = UINavigationController(rootViewController: webVC)
    navController.modalPresentationStyle = .fullScreen

    if let sourceVC = sourceViewController {
        sourceVC.present(navController, animated: animated, completion: nil)  // ← 使用 animated 参数
    } else {
        getTopViewController()?.present(navController, animated: animated, completion: nil)
    }

    currentBrowser = webVC

    // 🔥 统一调用 loadURLWithCache（Modal 模式也支持缓存）
    if let browserVC = webVC as? WebBrowserViewController {
        browserVC.loadURLWithCache(url, forceRefresh: forceRefresh)
    }
}
```

#### 6.1.5 删除 `openBrowserWithCache()` 方法

```swift
// ❌ 完整删除此方法（约 504-539 行）
// public func openBrowserWithCache(...) { ... }
```

#### 6.1.6 更新内部路由逻辑

```swift
public func openBrowser(
    url: URL,
    params: WebBrowserParams? = nil,
    forceRefresh: Bool = false,
    animated: Bool = true,
    from sourceViewController: UIViewController? = nil,
    completion: ((Result<Void, Error>) -> Void)? = nil
) {
    let finalParams = params ?? WebBrowserParams()

    switch finalParams.displayMode {
    case .normal:
        openNormalBrowser(
            url: url,
            params: finalParams,
            forceRefresh: forceRefresh,      // ← 传递参数
            animated: animated,               // ← 传递参数
            from: sourceViewController
        )
    case .immersive:
        openImmersiveBrowser(
            url: url,
            params: finalParams,
            forceRefresh: forceRefresh,      // ← 传递参数
            animated: animated,               // ← 传递参数
            from: sourceViewController
        )
    case .modal:
        openModalBrowser(
            url: url,
            params: finalParams,
            forceRefresh: forceRefresh,      // ← 传递参数
            animated: animated,               // ← 传递参数
            from: sourceViewController
        )
    }

    completion?(.success(()))
}
```

### 6.2 WebBrowserViewController.swift

#### 6.2.1 修改 `makeUI()` 方法

```swift
public override func makeUI() {
    // ... 原有代码保持不变 ...

    // 加载初始内容
    if let initialURL = viewModel.initialURL {
        loadURLWithCache(initialURL)  // ✅ 改这里
    } else {
        loadWelcomePage()
    }
}
```

#### 6.2.2 可选：删除旧的 `loadURL()` 方法

如果确认不再需要，可以删除第 393-410 行的旧 `loadURL()` 方法。

### 6.3 ManagerProtocols.swift

#### 6.3.1 更新协议定义

```swift
public protocol WebBrowserManaging {
    // ...

    /// 打开浏览器（统一入口，自动支持 Manifest 缓存）
    /// - Parameters:
    ///   - url: 要加载的 URL
    ///   - params: 浏览器配置参数
    ///   - forceRefresh: 是否强制刷新（绕过缓存）
    ///   - animated: 是否使用动画
    ///   - sourceViewController: 来源 ViewController
    ///   - completion: 完成回调
    func openBrowser(
        url: URL,
        params: WebBrowserParams?,
        forceRefresh: Bool,
        animated: Bool,
        from sourceViewController: UIViewController?,
        completion: ((Result<Void, Error>) -> Void)?
    )

    /// 关闭当前浏览器
    func closeBrowser(animated: Bool, reason: WebBrowserParams.CloseReason)
}
```

#### 6.3.2 删除旧方法定义

```swift
// ❌ 删除 openBrowserWithCache 方法定义
```

## 七、修改后的调用方式

### 7.1 普通调用（自动 Manifest）

```swift
// 默认使用缓存
WebBrowserManager.shared.openBrowser(
    url: URL(string: "https://example.com")!,
    params: WebBrowserParams(
        displayMode: .immersive,
        hideStatusBar: true,
        hideTabBar: true
    ),
    from: self
)
```

### 7.2 强制刷新（绕过缓存）

```swift
// 强制重新下载
WebBrowserManager.shared.openBrowser(
    url: URL(string: "https://example.com")!,
    params: params,
    forceRefresh: true,  // ← 绕过 Manifest 缓存
    from: self
)
```

### 7.3 无动画打开

```swift
// 立即显示，无动画
WebBrowserManager.shared.openBrowser(
    url: url,
    params: params,
    animated: false,  // ← 立即显示
    from: self
)
```

## 八、迁移对照表

| 旧调用方式 | 新调用方式 |
|-----------|-----------|
| `openBrowser(url: params: from:)` | `openBrowser(url: params: from:)` (保持不变，自动 Manifest) |
| `openBrowserWithCache(url: params: forceRefresh: from: animated:)` | `openBrowser(url: params: forceRefresh: animated: from:)` (参数合并到主方法) |

## 九、影响评估与风险分析

### 9.1 代码变更量

| 文件 | 新增行 | 删除行 | 净变化 |
|-------|---------|---------|---------|
| WebBrowserManager.swift | ~40 | ~60 | -20 |
| WebBrowserViewController.swift | ~5 | ~20 | -15 |
| ManagerProtocols.swift | ~10 | ~15 | -5 |
| MainViewController.swift | ~3 | ~5 | -2 |
| **合计** | **58** | **100** | **-42** |

### 9.2 破坏性变更清单

| 变更类型 | 影响范围 | 编译期检测 |
|---------|---------|-----------|
| 删除 `openBrowserWithCache()` 方法 | 所有调用点 | ✅ 编译报错 |
| 修改 `openBrowser()` 参数签名 | 无（新增可选参数） | ✅ 兼容 |
| 修改协议定义 | 协议实现类 | ✅ 编译报错 |
| 修改内部加载逻辑 | 运行时行为 | ❌ 需要测试 |

### 9.3 风险点与缓解措施

| 风险 | 严重程度 | 影响 | 缓解措施 |
|-------|---------|-------|---------|
| Modal 模式未统一处理 | 🔴 高 | 弹窗页面无缓存 | 本次重构一并处理 |
| 现有调用点迁移遗漏 | 🟡 中 | 部分功能失效 | 编译期检查 + 全局搜索 |
| Manifest 检测逻辑变化 | 🟡 中 | 缓存行为异常 | 充分测试三种模式 |
| URL 参数检查时机变化 | 🟢 低 | UI 显示异常 | 保持原有检查逻辑 |
| 性能影响 | 🟢 低 | 加载速度变化 | 性能测试对比 |

### 9.4 调用点清单（需要迁移）

通过全局搜索 `openBrowserWithCache` 找到的调用点：

1. **MainViewController.swift** (第 464 行)
   ```swift
   // 旧代码
   WebBrowserManager.shared.openBrowserWithCache(
       url: url,
       params: WebBrowserParams(displayMode: .normal),
       from: navigationController
   )
   
   // 新代码
   WebBrowserManager.shared.openBrowser(
       url: url,
       params: WebBrowserParams(displayMode: .normal),
       from: navigationController
   )
   ```

2. **其他可能的调用点**
   - 需要在执行前全局搜索确认
   - 包括测试代码中的调用

## 十、执行步骤

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          执行步骤（严格按顺序）                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘

Step 0: 准备工作
   ┌────────────────────────────────────────────────────────────────────────────┐
   │ 0.1 创建新分支: git checkout -b refactor/unified-browser-entry           │
   │ 0.2 全局搜索 openBrowserWithCache 确认所有调用点                         │
   │ 0.3 记录当前测试基准（运行现有测试套件）                                  │
   │ 0.4 备份关键文件（可选）                                                  │
   └────────────────────────────────────────────────────────────────────────────┘

Step 1: 修改 WebBrowserManager.swift
   ┌────────────────────────────────────────────────────────────────────────────┐
   │ 1.1 在 openBrowser() 添加 forceRefresh 和 animated 参数              │
   │ 1.2 修改 openNormalBrowser() 添加 forceRefresh 参数传递              │
   │ 1.3 修改 openNormalBrowser() 调用 loadURLWithCache 替代 loadURL      │
   │ 1.4 修改 openImmersiveBrowser() 添加 forceRefresh 参数传递           │
   │ 1.5 修改 openImmersiveBrowser() 调用 loadURLWithCache 替代 loadURL   │
   │ 1.6 修改 openModalBrowser() 添加 forceRefresh 参数传递               │
   │ 1.7 修改 openModalBrowser() 调用 loadURLWithCache 替代 loadURL       │
   │ 1.8 删除 openBrowserWithCache() 方法（完整删除）                     │
   └────────────────────────────────────────────────────────────────────────────┘

Step 2: 修改 WebBrowserViewController.swift
   ┌────────────────────────────────────────────────────────────────────────────┐
   │ 2.1 检查 makeUI() 中的 loadURL 调用                                      │
   │ 2.2 如果需要，将 loadURL(initialURL) 改为 loadURLWithCache(initialURL)   │
   │ 2.3 确保 checkURLParameters 逻辑不受影响                                 │
   │ 2.4 可选：删除旧的 loadURL() 方法（如果不再使用）                        │
   └────────────────────────────────────────────────────────────────────────────┘

Step 3: 更新 ManagerProtocols.swift
   ┌────────────────────────────────────────────────────────────────────────────┐
   │ 3.1 更新 WebBrowserManaging 协议中的 openBrowser 方法定义              │
   │ 3.2 添加 forceRefresh 和 animated 参数                                   │
   │ 3.3 删除 openBrowserWithCache() 方法定义                                │
   └────────────────────────────────────────────────────────────────────────────┘

Step 4: 更新所有调用点
   ┌────────────────────────────────────────────────────────────────────────────┐
   │ 4.1 修改 MainViewController.swift 中的调用（第 464 行）                  │
   │ 4.2 搜索并修改其他所有 openBrowserWithCache 调用                         │
   │ 4.3 检查测试代码中的调用                                                  │
   └────────────────────────────────────────────────────────────────────────────┘

Step 5: 编译验证
   ┌────────────────────────────────────────────────────────────────────────────┐
   │ 5.1 执行 Clean Build Folder (Cmd+Shift+K)                                │
   │ 5.2 编译项目 (Cmd+B)                                                     │
   │ 5.3 检查所有编译错误和警告                                               │
   │ 5.4 修复所有编译问题                                                     │
   │ 5.5 确保零警告零错误                                                     │
   └────────────────────────────────────────────────────────────────────────────┘

Step 6: 功能测试（详见测试方案）
   ┌────────────────────────────────────────────────────────────────────────────┐
   │ 6.1 运行自动化测试套件                                                   │
   │ 6.2 执行手动测试用例                                                     │
   │ 6.3 验证 Manifest 缓存功能                                               │
   │ 6.4 测试三种显示模式                                                     │
   │ 6.5 性能对比测试                                                         │
   └────────────────────────────────────────────────────────────────────────────┘

Step 7: 代码审查与提交
   ┌────────────────────────────────────────────────────────────────────────────┐
   │ 7.1 自我代码审查（检查遗漏）                                             │
   │ 7.2 运行代码格式化工具                                                   │
   │ 7.3 提交代码: git commit -m "refactor: unify browser entry point"       │
   │ 7.4 推送分支并创建 PR                                                    │
   └────────────────────────────────────────────────────────────────────────────┘
```

## 十一、测试方案

### 11.1 测试策略

```
┌─────────────────────────────────────────────────────────────────┐
│                    测试金字塔                                    │
├─────────────────────────────────────────────────────────────────┤
│                      手动探索测试                                │
│                    ▲ (边界情况、用户体验)                        │
│                   ╱ ╲                                           │
│                  ╱   ╲                                          │
│                 ╱     ╲                                         │
│                ╱       ╲                                        │
│               ╱  UI测试  ╲                                      │
│              ╱ (关键流程)  ╲                                    │
│             ╱───────────────╲                                   │
│            ╱                 ╲                                  │
│           ╱   集成测试         ╲                                │
│          ╱ (模块间交互)         ╲                               │
│         ╱─────────────────────────╲                            │
│        ╱                           ╲                           │
│       ╱        单元测试              ╲                          │
│      ╱    (方法级别、逻辑验证)        ╲                         │
│     ╱─────────────────────────────────╲                        │
└─────────────────────────────────────────────────────────────────┘
```

### 11.2 单元测试（Unit Tests）

#### 测试目标
- 验证 `openBrowser()` 方法参数传递正确
- 验证 `forceRefresh` 参数生效
- 验证三种显示模式的路由逻辑

#### 测试用例

```swift
// WebBrowserManagerTests.swift

class WebBrowserManagerTests: XCTestCase {
    var sut: WebBrowserManager!
    
    override func setUp() {
        super.setUp()
        sut = WebBrowserManager.shared
    }
    
    // TC-001: 测试 openBrowser 基本调用
    func testOpenBrowser_WithDefaultParams_ShouldSucceed() {
        let url = URL(string: "https://example.com")!
        let expectation = self.expectation(description: "Browser opened")
        
        sut.openBrowser(url: url, params: nil, from: nil) { result in
            switch result {
            case .success:
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Failed: \(error)")
            }
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    // TC-002: 测试 forceRefresh 参数传递
    func testOpenBrowser_WithForceRefresh_ShouldBypassCache() {
        let url = URL(string: "https://example.com")!
        
        sut.openBrowser(
            url: url,
            params: WebBrowserParams(displayMode: .normal),
            forceRefresh: true,
            from: nil
        )
        
        // 验证 forceRefresh 被正确传递到 loadURLWithCache
        // 可以通过 mock 或者检查内部状态
    }
    
    // TC-003: 测试 Normal 模式
    func testOpenBrowser_NormalMode_ShouldPushViewController() {
        let url = URL(string: "https://example.com")!
        let params = WebBrowserParams(displayMode: .normal)
        
        sut.openBrowser(url: url, params: params, from: nil)
        
        // 验证 navigationController.pushViewController 被调用
    }
    
    // TC-004: 测试 Immersive 模式
    func testOpenBrowser_ImmersiveMode_ShouldHideUI() {
        let url = URL(string: "https://example.com")!
        let params = WebBrowserParams(
            displayMode: .immersive,
            hideStatusBar: true,
            hideTabBar: true
        )
        
        sut.openBrowser(url: url, params: params, from: nil)
        
        // 验证 UI 隐藏逻辑
    }
    
    // TC-005: 测试 Modal 模式
    func testOpenBrowser_ModalMode_ShouldPresentModally() {
        let url = URL(string: "https://example.com")!
        let params = WebBrowserParams(displayMode: .modal)
        
        sut.openBrowser(url: url, params: params, from: nil)
        
        // 验证 present 被调用
    }
}
```

### 11.3 集成测试（Integration Tests）

#### 测试目标
- 验证 Manifest 缓存自动检测
- 验证三种模式的完整加载流程
- 验证 URL 参数处理

#### 测试用例

```swift
// WebBrowserIntegrationTests.swift

class WebBrowserIntegrationTests: XCTestCase {
    
    // TC-101: 测试 Manifest 自动检测
    func testOpenBrowser_WithManifestURL_ShouldLoadFromCache() {
        let manifestURL = URL(string: "https://example.com/app/manifest.json")!
        
        // 1. 预先缓存 Manifest
        let expectation1 = self.expectation(description: "Manifest cached")
        PersistentManifestLoader.shared.fetchManifest(from: manifestURL) { _ in
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 10.0)
        
        // 2. 打开浏览器
        let appURL = URL(string: "https://example.com/app/")!
        let expectation2 = self.expectation(description: "Browser opened")
        
        WebBrowserManager.shared.openBrowser(url: appURL, params: nil, from: nil) { result in
            expectation2.fulfill()
        }
        
        wait(for: [expectation2], timeout: 5.0)
        
        // 3. 验证缓存命中
        // 检查 cacheStatusLabel 显示 "MANIFEST" 或 "INTERCEPT"
    }
    
    // TC-102: 测试 forceRefresh 绕过缓存
    func testOpenBrowser_WithForceRefresh_ShouldReloadFromNetwork() {
        let url = URL(string: "https://example.com/app/")!
        
        WebBrowserManager.shared.openBrowser(
            url: url,
            params: nil,
            forceRefresh: true,
            from: nil
        )
        
        // 验证网络请求被发起，缓存被绕过
    }
    
    // TC-103: 测试 URL 参数处理
    func testOpenBrowser_WithURLParams_ShouldApplyUIChanges() {
        let url = URL(string: "https://example.com?hideNavBar=1&hideStatusBar=1")!
        
        WebBrowserManager.shared.openBrowser(url: url, params: nil, from: nil)
        
        // 验证导航栏和状态栏被隐藏
    }
}
```

### 11.4 UI 测试（UI Tests）

#### 测试目标
- 验证用户可见的行为
- 验证三种模式的 UI 表现
- 验证缓存状态显示

#### 测试用例

```swift
// WebBrowserUITests.swift

class WebBrowserUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    // TC-201: 测试 Normal 模式打开
    func testOpenBrowser_NormalMode_ShowsNavigationBar() {
        // 1. 点击首页的某个链接
        let collectionView = app.collectionViews["MainCollectionView"]
        let firstCell = collectionView.cells.element(boundBy: 0)
        firstCell.tap()
        
        // 2. 验证导航栏可见
        XCTAssertTrue(app.navigationBars.element.exists)
        
        // 3. 验证关闭按钮可见
        let closeButton = app.buttons["browserManager.closeButton"]
        XCTAssertTrue(closeButton.exists)
    }
    
    // TC-202: 测试 Immersive 模式
    func testOpenBrowser_ImmersiveMode_HidesUI() {
        // 打开沉浸式页面
        // 验证导航栏、状态栏、TabBar 都被隐藏
    }
    
    // TC-203: 测试缓存状态显示
    func testOpenBrowser_WithCache_ShowsCacheStatus() {
        // 打开已缓存的页面
        // 验证 cacheStatusLabel 显示 "MANIFEST" 或 "INTERCEPT"
    }
    
    // TC-204: 测试后退按钮
    func testOpenBrowser_AfterNavigation_ShowsBackButton() {
        // 1. 打开页面
        // 2. 点击页面内链接导航
        // 3. 验证后退按钮出现
        // 4. 点击后退
        // 5. 验证返回上一页
    }
}
```

### 11.5 手动测试清单

#### 功能测试

| 测试项 | 测试步骤 | 预期结果 | 状态 |
|-------|---------|---------|------|
| **Normal 模式** | 1. 打开首页<br>2. 点击任意链接 | 页面在导航栈中打开，显示导航栏 | ⬜ |
| **Immersive 模式** | 1. 打开测试用例页<br>2. 点击"沉浸式模式"链接 | 全屏显示，隐藏所有 UI | ⬜ |
| **Modal 模式** | 1. 触发 Modal 打开<br>2. 观察显示方式 | 以弹窗形式显示 | ⬜ |
| **Manifest 缓存** | 1. 扫描 Manifest URL<br>2. 打开应用<br>3. 观察缓存状态 | 显示 "MANIFEST" 标签 | ⬜ |
| **强制刷新** | 1. 打开已缓存页面<br>2. 使用 forceRefresh=true<br>3. 观察网络请求 | 绕过缓存，重新下载 | ⬜ |
| **后退功能** | 1. 打开页面<br>2. 点击页面内链接<br>3. 点击后退按钮 | 返回上一页 | ⬜ |
| **关闭功能** | 1. 打开页面<br>2. 点击关闭按钮 | 返回首页 | ⬜ |
| **URL 参数** | 1. 打开带参数的 URL<br>2. 观察 UI 变化 | 根据参数隐藏/显示 UI | ⬜ |

#### 性能测试

| 测试项 | 测试方法 | 基准值 | 重构后 | 状态 |
|-------|---------|-------|--------|------|
| **首次加载时间** | 打开未缓存页面，记录时间 | ___ ms | ___ ms | ⬜ |
| **缓存加载时间** | 打开已缓存页面，记录时间 | ___ ms | ___ ms | ⬜ |
| **内存占用** | 打开 10 个页面，观察内存 | ___ MB | ___ MB | ⬜ |
| **Manifest 检测时间** | 记录自动检测耗时 | ___ ms | ___ ms | ⬜ |

#### 边界情况测试

| 测试项 | 测试步骤 | 预期结果 | 状态 |
|-------|---------|---------|------|
| **无网络环境** | 1. 关闭网络<br>2. 打开未缓存页面 | 显示错误提示 | ⬜ |
| **无效 URL** | 1. 传入无效 URL<br>2. 观察行为 | 显示错误页面 | ⬜ |
| **Manifest 不存在** | 1. 打开无 Manifest 的页面<br>2. 观察缓存状态 | 显示 "LIVE" | ⬜ |
| **快速切换页面** | 1. 快速连续打开多个页面<br>2. 观察稳定性 | 不崩溃，正常显示 | ⬜ |
| **内存警告** | 1. 模拟内存警告<br>2. 观察应用行为 | 正常处理，不崩溃 | ⬜ |

### 11.6 回归测试

重构后必须验证以下功能未受影响：

- ✅ 首页历史记录显示
- ✅ 扫码功能
- ✅ 收藏功能
- ✅ 缓存清理功能
- ✅ 权限管理
- ✅ JS Bridge 功能
- ✅ 语音控制游戏
- ✅ 性能监控

### 11.7 测试环境

| 环境 | 配置 |
|------|------|
| **iOS 版本** | iOS 15.0+ |
| **设备** | iPhone 12 Pro, iPhone SE, iPad Pro |
| **网络** | WiFi, 4G, 无网络 |
| **Xcode** | 最新稳定版 |

### 11.8 测试通过标准

- ✅ 所有单元测试通过（100% 通过率）
- ✅ 所有集成测试通过
- ✅ 所有 UI 测试通过
- ✅ 手动测试清单全部完成
- ✅ 性能测试无明显退化（±5% 以内）
- ✅ 零崩溃、零内存泄漏
- ✅ 代码覆盖率 ≥ 80%

---

## 十二、关键注意事项

### 12.1 代码修改注意事项

#### ⚠️ 必须注意的点

1. **Modal 模式必须一并处理**
   - 不要遗漏 `openModalBrowser()` 的修改
   - Modal 模式也要调用 `loadURLWithCache()`
   - 确保三种模式行为一致

2. **参数传递链路完整**
   ```
   openBrowser() 
     → openNormalBrowser/openImmersiveBrowser/openModalBrowser
       → loadURLWithCache()
   ```
   - 每一层都要正确传递 `forceRefresh` 参数
   - 不要在中间层丢失参数

3. **删除方法要彻底**
   - 删除 `openBrowserWithCache()` 方法实现
   - 删除协议中的方法定义
   - 删除所有相关注释和文档引用

4. **保持 URL 参数检查逻辑**
   - `checkURLParameters()` 逻辑不能丢失
   - 确保 `hideNavBar`、`hideStatusBar` 等参数仍然生效
   - 在 `loadURLWithCache()` 完成后仍要检查参数

5. **animated 参数的使用**
   - `pushViewController` 和 `present` 都要使用 `animated` 参数
   - 不要硬编码为 `true`

#### 🔍 容易遗漏的点

1. **协议定义同步**
   - `ManagerProtocols.swift` 必须同步更新
   - 否则会导致协议不一致的编译错误

2. **测试代码中的调用**
   - 不要只改业务代码，测试代码也要改
   - 搜索 `openBrowserWithCache` 要包含测试目录

3. **文档和注释更新**
   - README 中的示例代码
   - 代码注释中的方法引用
   - API 文档

4. **错误处理**
   - `loadURLWithCache()` 的失败回调要正确处理
   - 不要吞掉错误

### 12.2 测试注意事项

#### ⚠️ 测试重点

1. **缓存行为验证**
   - 必须验证 Manifest 自动检测是否生效
   - 检查缓存状态标签显示是否正确
   - 验证 `forceRefresh` 是否真正绕过缓存

2. **三种模式全覆盖**
   - Normal、Immersive、Modal 都要测试
   - 不要只测试 Normal 模式

3. **边界情况**
   - 无网络环境
   - Manifest 不存在
   - 无效 URL
   - 快速连续操作

4. **性能对比**
   - 记录重构前的性能基准
   - 重构后对比，确保无明显退化
   - 特别关注首次加载和缓存加载时间

#### 🔍 测试陷阱

1. **缓存干扰**
   - 测试前清理所有缓存
   - 避免上次测试的缓存影响本次结果

2. **异步时序问题**
   - Manifest 加载是异步的
   - 测试时要等待足够时间
   - 使用 `expectation` 正确等待

3. **UI 状态检查时机**
   - 不要在页面加载完成前检查 UI 状态
   - 使用 `waitForExistence` 等待元素出现

4. **设备差异**
   - 在不同设备上测试（iPhone、iPad）
   - 不同 iOS 版本测试

### 12.3 回滚方案

如果重构后发现严重问题，需要快速回滚：

#### 回滚步骤

```bash
# 1. 切换回主分支
git checkout main

# 2. 如果已经合并，回退提交
git revert <commit-hash>

# 3. 如果还在分支，直接删除分支
git branch -D refactor/unified-browser-entry

# 4. 重新编译验证
xcodebuild clean build
```

#### 回滚触发条件

- 发现严重的功能缺陷（如某种模式完全无法打开）
- 性能退化超过 20%
- 出现频繁崩溃
- 缓存功能完全失效

### 12.4 代码审查清单

在提交 PR 前，自我审查以下内容：

- [ ] 所有 `openBrowserWithCache` 调用已替换
- [ ] 三种显示模式都已修改
- [ ] 协议定义已同步更新
- [ ] 所有编译警告已消除
- [ ] 代码格式符合规范
- [ ] 注释和文档已更新
- [ ] 测试代码已更新
- [ ] 所有测试通过
- [ ] 性能测试完成
- [ ] 手动测试清单完成

### 12.5 常见问题 FAQ

**Q1: 为什么不保留 `openBrowserWithCache()` 作为兼容方法？**

A: 因为两个方法功能完全重叠，保留会导致：
- 使用者困惑（不知道该用哪个）
- 维护成本高（需要同步修改两处）
- 代码冗余

破坏性变更可以通过编译期检查快速发现所有调用点，反而更安全。

**Q2: Modal 模式为什么也要支持缓存？**

A: Modal 模式只是显示方式不同，内容加载逻辑应该一致。用户期望所有模式都能享受缓存加速。

**Q3: 如果 Manifest 检测失败会怎样？**

A: `LazyManifestLoader.smartLoad()` 内部会自动降级到普通加载，不会影响页面打开。

**Q4: `forceRefresh` 参数什么时候使用？**

A: 
- 用户手动刷新页面时
- 需要获取最新内容时
- 调试缓存问题时

**Q5: 重构后性能会变差吗？**

A: 不会。重构只是统一入口，内部逻辑没有增加额外开销。反而因为所有模式都支持缓存，整体性能会提升。

---

## 十三、完成标志

### 代码修改完成标志

- [ ] `openBrowser()` 包含 `forceRefresh` 和 `animated` 参数
- [ ] `openNormalBrowser()` 调用 `loadURLWithCache()` 并传递 `forceRefresh`
- [ ] `openImmersiveBrowser()` 调用 `loadURLWithCache()` 并传递 `forceRefresh`
- [ ] `openModalBrowser()` 调用 `loadURLWithCache()` 并传递 `forceRefresh`
- [ ] `openBrowserWithCache()` 方法已完全删除
- [ ] `ManagerProtocols.swift` 协议已更新
- [ ] `MainViewController.swift` 调用已更新
- [ ] 所有其他调用点已更新
- [ ] 编译通过，零警告零错误

### 测试完成标志

- [ ] 所有单元测试通过
- [ ] 所有集成测试通过
- [ ] 所有 UI 测试通过
- [ ] 手动测试清单全部完成
- [ ] 性能测试完成，无明显退化
- [ ] 回归测试完成
- [ ] 边界情况测试完成

### 文档完成标志

- [ ] 代码注释已更新
- [ ] API 文档已更新
- [ ] README 示例代码已更新
- [ ] 变更日志已记录

---

## 十四、时间估算

| 阶段 | 预计时间 | 说明 |
|------|---------|------|
| 准备工作 | 30 分钟 | 创建分支、搜索调用点 |
| 代码修改 | 2 小时 | 修改 3 个核心文件 |
| 调用点迁移 | 1 小时 | 更新所有调用点 |
| 编译修复 | 30 分钟 | 修复编译错误 |
| 单元测试 | 2 小时 | 编写和运行测试 |
| 集成测试 | 1 小时 | 端到端测试 |
| 手动测试 | 2 小时 | 完整功能验证 |
| 性能测试 | 1 小时 | 性能对比 |
| 代码审查 | 30 分钟 | 自我审查 |
| 文档更新 | 30 分钟 | 更新文档 |
| **总计** | **11 小时** | 约 1.5 个工作日 |

---

**文档版本**: 2.0  
**创建日期**: 2025-02-12  
**更新日期**: 2025-02-12  
**状态**: ✅ 待执行  
**负责人**: [待指定]  
**审核人**: [待指定]
