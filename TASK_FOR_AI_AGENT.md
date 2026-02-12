# WebBridgeKit 项目修复任务文档

**文档版本：** 1.0  
**创建日期：** 2026-02-10  
**项目：** WebBridgeKit iOS Framework  
**任务类型：** 编译错误修复 + 代码质量改进

---

## 📋 任务概述

本文档包含 WebBridgeKit 项目的待处理任务。项目已完成大部分功能修复（20/28 问题已解决），但存在 Xcode 项目配置错误导致编译失败，以及 8 个轻微的代码质量问题需要改进。

### 当前状态
- ✅ 严重问题：8/8 已修复（100%）
- ✅ 中等问题：12/12 已修复（100%）
- ❌ 轻微问题：0/8 已修复（0%）
- ⚠️ 编译状态：存在路径错误，无法编译

### 项目结构
```
WebBridgeKit/
├── Sources/                    # 框架源代码
│   ├── Models/                # 数据模型
│   ├── Controllers/           # 视图控制器
│   ├── Handlers/              # 处理器
│   ├── Cache/                 # 缓存管理
│   ├── Managers/              # 管理器
│   └── Utils/                 # 工具类
├── DemoApp/                   # 示例应用
│   └── Sources/
├── Tests/                     # 测试文件
├── WebBridgeKit.xcodeproj/   # Xcode 项目文件
├── WebBridgeKit.xcworkspace/  # Xcode 工作空间
└── project.yml                # XcodeGen 配置文件
```

---

## 🔥 优先级 1：修复编译错误（必须完成）

### 问题描述

Xcode 项目文件中存在路径配置错误，导致以下 3 个文件无法找到：

```
错误信息：
error: Build input files cannot be found:
- '/Users/.../WebBridgeKit/Sources/Models/Sources/Models/ManifestError.swift'
- '/Users/.../WebBridgeKit/Sources/Utils/Sources/Utils/PerformanceMonitor.swift'
- '/Users/.../WebBridgeKit/Sources/Utils/Sources/Utils/SignpostLogger.swift'

实际路径：
- Sources/Models/ManifestError.swift          ✅ 文件存在
- Sources/Utils/PerformanceMonitor.swift      ✅ 文件存在
- Sources/Utils/SignpostLogger.swift          ✅ 文件存在
```

### 根本原因

使用 Ruby xcodeproj gem 添加文件时，路径被错误地设置为双重嵌套格式（`Sources/Models/Sources/Models/`）。

### 解决方案选项

#### 方案 A：使用 XcodeGen 重新生成项目（推荐）⭐️

项目根目录存在 `project.yml` 文件，说明使用了 XcodeGen。

**步骤：**
1. 检查 `project.yml` 是否包含这 3 个文件
2. 如果没有，添加到相应的 target 中
3. 运行 `xcodegen generate` 重新生成项目文件
4. 清理构建缓存：`rm -rf ~/Library/Developer/Xcode/DerivedData/WebBridgeKit-*`
5. 重新打开项目并构建

**project.yml 参考配置：**
```yaml
targets:
  WebBridgeKit:
    sources:
      - path: Sources
        excludes:
          - "**/*.md"
```

#### 方案 B：手动编辑 .pbxproj 文件

**步骤：**
1. 关闭 Xcode
2. 打开 `WebBridgeKit.xcodeproj/project.pbxproj`
3. 搜索并替换错误路径：
   - 查找：`Sources/Models/Sources/Models/ManifestError.swift`
   - 替换为：`Sources/Models/ManifestError.swift`
   - 对其他两个文件重复此操作
4. 保存文件
5. 清理缓存并重新打开项目

#### 方案 C：在 Xcode 中手动重新添加文件

**步骤：**
1. 打开 `WebBridgeKit.xcworkspace`
2. 选择 WebBridgeKit target
3. 进入 "Build Phases" → "Compile Sources"
4. 找到并删除这 3 个错误的文件引用
5. 点击 "+" 按钮，重新添加：
   - `Sources/Models/ManifestError.swift`
   - `Sources/Utils/PerformanceMonitor.swift`
   - `Sources/Utils/SignpostLogger.swift`
6. 确保文件被添加到正确的 target
7. 清理构建并重新编译

### 验证步骤

完成修复后，执行以下验证：

```bash
# 1. 清理构建缓存
rm -rf ~/Library/Developer/Xcode/DerivedData/WebBridgeKit-*

# 2. 清理项目
cd /path/to/WebBridgeKit
xcodebuild clean -workspace WebBridgeKit.xcworkspace -scheme WebBridgeKit

# 3. 构建项目
xcodebuild build -workspace WebBridgeKit.xcworkspace -scheme WebBridgeKit

# 4. 检查是否有编译错误
# 预期：构建成功，无错误
```

### 预期结果

- ✅ 项目可以成功编译
- ✅ 所有文件路径正确
- ✅ 无编译错误和警告

---


## 🎯 优先级 2：添加单元测试（重要）

### 任务描述

为核心功能添加单元测试，提高代码质量和重构安全性。

### 目标

- 核心代码覆盖率达到 80%
- 所有公开 API 都有测试
- 关键业务逻辑有测试

### 需要测试的模块

#### 1. ManifestCacheManager 测试

**文件：** `Tests/Cache/ManifestCacheManagerTests.swift`

**测试用例：**
```swift
import XCTest
@testable import WebBridgeKit

class ManifestCacheManagerTests: XCTestCase {
    var sut: ManifestCacheManager!
    var mockStore: MockManifestStore!
    
    override func setUp() {
        super.setUp()
        mockStore = MockManifestStore()
        sut = ManifestCacheManager(store: mockStore)
    }
    
    override func tearDown() {
        sut = nil
        mockStore = nil
        super.tearDown()
    }
    
    // 测试保存页面
    func testSavePage() {
        // Given
        let pageKey = "test"
        let html = "<html></html>"
        let manifest = Manifest(version: "1.0", resources: [])
        
        // When
        let result = sut.savePage(pageKey: pageKey, html: html, manifest: manifest)
        
        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(mockStore.savedHTML[pageKey], html)
    }
    
    // 测试加载页面
    func testLoadPage() {
        // Given
        let pageKey = "test"
        let html = "<html></html>"
        mockStore.savedHTML[pageKey] = html
        
        // When
        let result = sut.loadHTML(for: pageKey)
        
        // Then
        XCTAssertEqual(result, html)
    }
    
    // 测试加载不存在的页面
    func testLoadNonExistentPage() {
        // When
        let result = sut.loadHTML(for: "nonexistent")
        
        // Then
        XCTAssertNil(result)
    }
    
    // 测试 Manifest 验证
    func testManifestValidation() throws {
        // Given
        let manifest = Manifest(
            version: "99.0",  // 不支持的版本
            resources: []
        )
        
        // When/Then
        XCTAssertThrowsError(try manifest.validate()) { error in
            XCTAssertTrue(error is ManifestError)
        }
    }
}

// Mock 对象
class MockManifestStore {
    var savedHTML: [String: String] = [:]
    var savedManifests: [String: Data] = [:]
    
    func saveHTML(_ html: String, for key: String) {
        savedHTML[key] = html
    }
    
    func getHTML(for key: String) -> String? {
        return savedHTML[key]
    }
}
```

#### 2. WebPageCacheHandler 测试

**文件：** `Tests/Handlers/WebPageCacheHandlerTests.swift`

**测试用例：**
```swift
class WebPageCacheHandlerTests: XCTestCase {
    var sut: WebPageCacheHandler!
    
    override func setUp() {
        super.setUp()
        sut = WebPageCacheHandler()
    }
    
    // 测试缓存大小限制
    func testCacheSizeLimit() {
        // Given
        let maxPages = 10
        
        // When: 添加超过限制的页面
        for i in 0..<20 {
            let html = String(repeating: "test", count: 1000)
            sut.cachePage(pageName: "page\(i)", html: html, baseURL: nil)
        }
        
        // Then: 缓存大小不超过限制
        let cacheInfo = sut.getCacheInfo()
        XCTAssertLessThanOrEqual(cacheInfo.count, maxPages)
    }
    
    // 测试 LRU 淘汰
    func testLRUEviction() {
        // Given: 填满缓存
        for i in 0..<10 {
            sut.cachePage(pageName: "page\(i)", html: "test", baseURL: nil)
        }
        
        // When: 访问第一个页面（更新访问时间）
        _ = sut.getCachedPage(pageName: "page0")
        
        // 添加新页面，应该淘汰 page1（最久未使用）
        sut.cachePage(pageName: "page10", html: "test", baseURL: nil)
        
        // Then
        XCTAssertNotNil(sut.getCachedPage(pageName: "page0"))
        XCTAssertNil(sut.getCachedPage(pageName: "page1"))
        XCTAssertNotNil(sut.getCachedPage(pageName: "page10"))
    }
    
    // 测试内存警告处理
    func testMemoryWarning() {
        // Given: 添加一些页面
        for i in 0..<10 {
            sut.cachePage(pageName: "page\(i)", html: "test", baseURL: nil)
        }
        
        let initialCount = sut.getCacheInfo().count
        
        // When: 模拟内存警告
        NotificationCenter.default.post(
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Then: 缓存应该被清理
        let finalCount = sut.getCacheInfo().count
        XCTAssertLessThan(finalCount, initialCount)
    }
}
```

#### 3. NetworkMonitor 测试

**文件：** `Tests/Utils/NetworkMonitorTests.swift`

**测试用例：**
```swift
class NetworkMonitorTests: XCTestCase {
    var sut: NetworkMonitor!
    
    override func setUp() {
        super.setUp()
        sut = NetworkMonitor.shared
    }
    
    // 测试网络状态检测
    func testNetworkStatusDetection() {
        // Given/When
        let isConnected = sut.isConnected
        
        // Then
        XCTAssertNotNil(isConnected)
    }
    
    // 测试状态变化通知
    func testNetworkStatusChangeNotification() {
        // Given
        let expectation = XCTestExpectation(description: "Status changed")
        
        sut.onStatusChange = { isConnected in
            print("Network status: \(isConnected)")
            expectation.fulfill()
        }
        
        // When: 手动切换飞行模式
        // Then: 等待通知
        wait(for: [expectation], timeout: 30.0)
    }
}
```

#### 4. RequestDeduplicator 测试

**文件：** `Tests/Utils/RequestDeduplicatorTests.swift`

**测试用例：**
```swift
class RequestDeduplicatorTests: XCTestCase {
    var sut: RequestDeduplicator!
    
    override func setUp() {
        super.setUp()
        sut = RequestDeduplicator.shared
    }
    
    // 测试请求去重
    func testRequestDeduplication() async throws {
        // Given
        let key = "test"
        var executionCount = 0
        
        // When: 同时发起 10 个相同请求
        let tasks = (0..<10).map { _ in
            Task {
                try await sut.deduplicate(key: key) {
                    executionCount += 1
                    try await Task.sleep(nanoseconds: 100_000_000)
                    return "result"
                }
            }
        }
        
        // 等待所有任务完成
        let results = try await withThrowingTaskGroup(of: String.self) { group in
            for task in tasks {
                group.addTask { try await task.value }
            }
            
            var results: [String] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
        
        // Then: 所有请求都成功，但只执行了一次
        XCTAssertEqual(results.count, 10)
        XCTAssertEqual(executionCount, 1)
    }
}
```

#### 5. PerformanceMonitor 测试

**文件：** `Tests/Utils/PerformanceMonitorTests.swift`

**测试用例：**
```swift
class PerformanceMonitorTests: XCTestCase {
    var sut: PerformanceMonitor!
    
    override func setUp() {
        super.setUp()
        sut = PerformanceMonitor.shared
    }
    
    // 测试性能测量
    func testPerformanceMeasurement() {
        // Given/When
        for _ in 0..<10 {
            sut.measure("test_operation") {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        
        // Then
        let stats = sut.getStatistics(for: "test_operation")
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.count, 10)
        XCTAssertGreaterThan(stats?.average ?? 0, 0.09)
        XCTAssertLessThan(stats?.average ?? 0, 0.15)
    }
    
    // 测试慢操作检测
    func testSlowOperationDetection() {
        // Given
        var warningLogged = false
        
        // When: 执行慢操作（>1秒）
        sut.measure("slow_operation") {
            Thread.sleep(forTimeInterval: 1.5)
        }
        
        // Then: 应该记录警告
        // 验证日志中包含 "Slow operation"
    }
}
```

### 运行测试

```bash
# 运行所有测试
xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme WebBridgeKit -destination 'platform=iOS Simulator,name=iPhone 15'

# 运行特定测试
xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme WebBridgeKit -only-testing:WebBridgeKitTests/ManifestCacheManagerTests

# 查看代码覆盖率
# Xcode → Report Navigator → Coverage
```

### 预期结果

- ✅ 所有测试通过
- ✅ 代码覆盖率 > 80%
- ✅ 无测试失败

---


## 📝 优先级 3：完善 API 文档（中等）

### 任务描述

为所有公开 API 添加详细的文档注释，提高代码可维护性。

### 文档标准

使用 Swift 标准文档格式：

```swift
/// 简短的一句话描述
///
/// 详细的功能说明，可以多行。
/// 解释方法的用途、行为和注意事项。
///
/// - Parameters:
///   - param1: 参数1的说明
///   - param2: 参数2的说明
///
/// - Returns: 返回值的说明
///
/// - Throws:
///   - `ErrorType.case1`: 错误情况1
///   - `ErrorType.case2`: 错误情况2
///
/// - Note: 重要提示或注意事项
///
/// - Warning: 警告信息
///
/// - Example:
///   ```swift
///   let result = try method(param1: value1, param2: value2)
///   ```
///
/// - SeeAlso: `RelatedType`, `relatedMethod()`
public func method(param1: Type1, param2: Type2) throws -> ReturnType {
    // 实现
}
```

### 需要添加文档的文件

#### 1. WebBrowserManager.swift

```swift
/// Web 浏览器管理器
///
/// 负责管理 Web 浏览器的创建、配置和导航。
/// 支持多种显示模式（全屏、模态、导航栏）和自定义参数。
///
/// - Note: 使用单例模式，通过 `shared` 访问
public class WebBrowserManager {
    
    /// 打开浏览器并加载指定 URL
    ///
    /// 此方法会创建一个新的浏览器视图控制器并导航到指定 URL。
    /// 如果 URL 无效或导航失败，会抛出相应的错误。
    ///
    /// - Parameters:
    ///   - url: 要加载的 URL，必须是有效的 HTTP/HTTPS/自定义 scheme URL
    ///   - params: 浏览器配置参数，如果为 nil 则使用默认配置
    ///   - sourceViewController: 来源视图控制器，用于导航
    ///
    /// - Throws:
    ///   - `WebBrowserError.invalidURLScheme`: URL scheme 不被支持
    ///   - `WebBrowserError.invalidHost`: URL host 无效
    ///   - `WebBrowserError.navigationFailed`: 导航失败
    ///
    /// - Note: 此方法会自动记录访问历史
    ///
    /// - Example:
    ///   ```swift
    ///   let url = URL(string: "https://example.com")!
    ///   let params = WebBrowserParams(displayMode: .fullScreen)
    ///   try WebBrowserManager.shared.openBrowser(url: url, params: params)
    ///   ```
    ///
    /// - SeeAlso: `WebBrowserParams`, `WebBrowserError`
    public func openBrowser(url: URL, params: WebBrowserParams? = nil) throws {
        // 实现
    }
}
```

#### 2. ManifestCacheManager.swift

```swift
/// Manifest 缓存管理器
///
/// 负责管理 Web 页面的 manifest 文件和相关资源的缓存。
/// 支持页面预加载、资源下载、缓存验证等功能。
///
/// - Note: 使用单例模式，通过 `shared` 访问
public class ManifestCacheManager {
    
    /// 保存页面及其 manifest
    ///
    /// 将 HTML 内容和 manifest 配置保存到缓存中。
    /// 会自动验证 manifest 的有效性和安全性。
    ///
    /// - Parameters:
    ///   - pageKey: 页面的唯一标识符
    ///   - html: HTML 内容
    ///   - manifest: Manifest 配置对象
    ///
    /// - Returns: 保存结果，成功返回 .success，失败返回 .failure
    ///
    /// - Note: 
    ///   - pageKey 不能为空
    ///   - html 不能为空
    ///   - manifest 必须通过验证
    ///
    /// - Example:
    ///   ```swift
    ///   let manifest = Manifest(version: "1.0", resources: [])
    ///   let result = manager.savePage(
    ///       pageKey: "home",
    ///       html: "<html>...</html>",
    ///       manifest: manifest
    ///   )
    ///   ```
    public func savePage(pageKey: String, html: String, manifest: Manifest) -> Result<Void, ManifestError> {
        // 实现
    }
}
```

#### 3. NetworkMonitor.swift

```swift
/// 网络状态监控器
///
/// 实时监控设备的网络连接状态和类型。
/// 支持 WiFi、蜂窝网络、以太网等多种连接类型的检测。
///
/// - Note: 使用单例模式，通过 `shared` 访问
/// - Important: 需要在应用启动时调用 `startMonitoring()` 开始监控
public class NetworkMonitor {
    
    /// 当前网络连接状态
    ///
    /// - Returns: `true` 表示已连接，`false` 表示未连接
    public private(set) var isConnected: Bool
    
    /// 当前连接类型
    ///
    /// - Returns: WiFi、蜂窝网络、以太网等，如果未连接则为 nil
    public private(set) var connectionType: NWInterface.InterfaceType?
    
    /// 网络状态变化回调
    ///
    /// 当网络状态发生变化时会调用此闭包。
    ///
    /// - Parameter isConnected: 新的连接状态
    ///
    /// - Example:
    ///   ```swift
    ///   NetworkMonitor.shared.onStatusChange = { isConnected in
    ///       if isConnected {
    ///           print("网络已连接")
    ///       } else {
    ///           print("网络已断开")
    ///       }
    ///   }
    ///   ```
    public var onStatusChange: ((Bool) -> Void)?
}
```

#### 4. PerformanceMonitor.swift

```swift
/// 性能监控器
///
/// 用于测量和统计应用中各种操作的性能指标。
/// 支持同步和异步操作的测量，提供详细的统计信息。
///
/// - Note: 使用单例模式，通过 `shared` 访问
public class PerformanceMonitor {
    
    /// 测量同步操作的执行时间
    ///
    /// 自动记录操作的开始和结束时间，计算耗时。
    /// 如果操作耗时超过 1 秒，会记录警告日志。
    ///
    /// - Parameters:
    ///   - operation: 操作名称，用于标识和统计
    ///   - metadata: 可选的元数据，用于记录额外信息
    ///   - block: 要测量的操作闭包
    ///
    /// - Returns: 操作的返回值
    ///
    /// - Throws: 如果操作抛出错误，会重新抛出
    ///
    /// - Example:
    ///   ```swift
    ///   let result = PerformanceMonitor.shared.measure("load_data") {
    ///       return loadDataFromDatabase()
    ///   }
    ///   ```
    public func measure<T>(_ operation: String, 
                          metadata: [String: Any]? = nil,
                          block: () throws -> T) rethrows -> T {
        // 实现
    }
}
```

### 文档生成

使用 Jazzy 生成 HTML 文档：

```bash
# 安装 Jazzy
gem install jazzy

# 生成文档
jazzy \
  --clean \
  --author "WebBridgeKit Team" \
  --module WebBridgeKit \
  --source-directory Sources \
  --output docs \
  --theme fullwidth

# 查看文档
open docs/index.html
```

### 预期结果

- ✅ 所有公开 API 都有文档注释
- ✅ 文档格式统一、规范
- ✅ 可以生成完整的 HTML 文档

---

## 🔧 优先级 4：消除魔法数字（低）

### 任务描述

将代码中的硬编码数字和字符串提取为常量，提高可维护性。

### 创建配置文件

**文件：** `Sources/Utils/WebBridgeKitConfiguration.swift`

```swift
/// WebBridgeKit 框架配置
///
/// 包含框架使用的所有配置常量。
/// 可以通过修改这些值来调整框架行为。
public struct WebBridgeKitConfiguration {
    
    /// 缓存配置
    public struct Cache {
        /// 内存缓存容量（字节）
        public static let memoryCapacity = 100 * 1024 * 1024  // 100 MB
        
        /// 磁盘缓存容量（字节）
        public static let diskCapacity = 500 * 1024 * 1024    // 500 MB
        
        /// 缓存最大保存时间（秒）
        public static let maxCacheAge: TimeInterval = 7 * 24 * 3600  // 7 天
        
        /// 最大缓存页面数量
        public static let maxPageCount = 50
        
        /// 内存警告时保留的缓存比例
        public static let memoryWarningRetainRatio = 0.5  // 50%
    }
    
    /// 历史记录配置
    public struct History {
        /// 最大历史记录数量
        public static let maxItems = 1000
        
        /// 显示的历史记录数量
        public static let displayLimit = 100
        
        /// 自动清理阈值
        public static let autoCleanupThreshold = 1000
        
        /// 历史记录保存天数
        public static let retentionDays = 30
    }
    
    /// 网络配置
    public struct Network {
        /// 请求超时时间（秒）
        public static let requestTimeout: TimeInterval = 10.0
        
        /// 资源下载超时时间（秒）
        public static let resourceTimeout: TimeInterval = 30.0
        
        /// 最大并发下载数
        public static let maxConcurrentDownloads = 4
        
        /// 重试次数
        public static let maxRetries = 3
        
        /// 重试延迟（秒）
        public static let retryDelay: TimeInterval = 1.0
    }
    
    /// 性能配置
    public struct Performance {
        /// 慢操作阈值（秒）
        public static let slowOperationThreshold: TimeInterval = 1.0
        
        /// 性能数据保留时间（秒）
        public static let metricsRetentionTime: TimeInterval = 3600  // 1 小时
        
        /// 是否启用性能监控
        public static let enableMonitoring = true
    }
    
    /// 日志配置
    public struct Logging {
        /// 日志级别
        public static var minimumLevel: LogLevel = {
            #if DEBUG
            return .debug
            #else
            return .warning
            #endif
        }()
        
        /// 是否启用日志
        public static let enabled = true
        
        /// 日志文件最大大小（字节）
        public static let maxFileSize = 10 * 1024 * 1024  // 10 MB
    }
}
```

### 替换魔法数字

**修改前：**
```swift
// MainViewModel.swift
let histories = Array(historyResults.prefix(100))
    .filter { !favoriteURLs.contains($0.url) }
    .prefix(20)

// WebPageCacheHandler.swift
private let maxCacheSize = 50
private let maxMemorySizeMB = 100

// NetworkHelper.swift
configuration.timeoutIntervalForRequest = 10.0
configuration.timeoutIntervalForResource = 30.0
```

**修改后：**
```swift
// MainViewModel.swift
let histories = Array(historyResults.prefix(WebBridgeKitConfiguration.History.maxItems))
    .filter { !favoriteURLs.contains($0.url) }
    .prefix(WebBridgeKitConfiguration.History.displayLimit)

// WebPageCacheHandler.swift
private let maxCacheSize = WebBridgeKitConfiguration.Cache.maxPageCount
private let maxMemorySizeMB = WebBridgeKitConfiguration.Cache.memoryCapacity / (1024 * 1024)

// NetworkHelper.swift
configuration.timeoutIntervalForRequest = WebBridgeKitConfiguration.Network.requestTimeout
configuration.timeoutIntervalForResource = WebBridgeKitConfiguration.Network.resourceTimeout
```

### 需要修改的文件

1. `Sources/Handlers/WebPageCacheHandler.swift`
2. `DemoApp/Sources/ViewModels/MainViewModel.swift`
3. `Sources/Utils/NetworkHelper.swift`
4. `Sources/Cache/ManifestCacheManager.swift`
5. `Sources/Managers/WebPageHistoryManager.swift`

### 预期结果

- ✅ 所有魔法数字都被常量替代
- ✅ 配置集中管理
- ✅ 易于调整和维护

---


## 🏗️ 优先级 5：重构过长的方法和类（低）

### 任务描述

将过长的类和方法拆分为更小的、职责单一的组件。

### 需要重构的文件

#### 1. MainViewController.swift（600+ 行）

**问题：** 职责过多，包含 UI 管理、数据绑定、手势处理、通知监听等。

**重构方案：**

**拆分数据源：**
```swift
// 新建文件：DemoApp/Sources/DataSources/MainDataSource.swift
class MainDataSource: NSObject, UICollectionViewDataSource {
    var sections: [WebPageHistorySection] = []
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, 
                       numberOfItemsInSection section: Int) -> Int {
        return sections[section].items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, 
                       cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // 配置 cell
    }
}
```

**拆分手势处理：**
```swift
// 新建文件：DemoApp/Sources/Handlers/MainGestureHandler.swift
protocol MainGestureHandlerDelegate: AnyObject {
    func gestureHandler(_ handler: MainGestureHandler, 
                       didLongPressItemAt indexPath: IndexPath)
}

class MainGestureHandler {
    weak var delegate: MainGestureHandlerDelegate?
    
    func handleLongPress(_ gesture: UILongPressGestureRecognizer, 
                        in collectionView: UICollectionView) {
        guard gesture.state == .began else { return }
        
        let point = gesture.location(in: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: point) {
            delegate?.gestureHandler(self, didLongPressItemAt: indexPath)
        }
    }
}
```

**简化后的 MainViewController：**
```swift
class MainViewController: BaseViewController<MainViewModel> {
    // MARK: - Properties
    private let dataSource = MainDataSource()
    private let gestureHandler = MainGestureHandler()
    private let notificationHandler = MainNotificationHandler()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupComponents()
        bindViewModel()
    }
    
    // MARK: - Setup
    private func setupComponents() {
        setupDataSource()
        setupGestureHandler()
        setupNotificationHandler()
    }
    
    private func setupDataSource() {
        dataSource.delegate = self
        collectionView.dataSource = dataSource
    }
    
    private func setupGestureHandler() {
        gestureHandler.delegate = self
        let longPress = UILongPressGestureRecognizer(
            target: gestureHandler,
            action: #selector(MainGestureHandler.handleLongPress(_:))
        )
        collectionView.addGestureRecognizer(longPress)
    }
    
    // MARK: - Binding
    private func bindViewModel() {
        viewModel.sections
            .drive(onNext: { [weak self] sections in
                self?.dataSource.sections = sections
                self?.collectionView.reloadData()
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - MainGestureHandlerDelegate
extension MainViewController: MainGestureHandlerDelegate {
    func gestureHandler(_ handler: MainGestureHandler, 
                       didLongPressItemAt indexPath: IndexPath) {
        // 处理长按
    }
}
```

#### 2. MainViewModel.swift - loadHistories() 方法（100+ 行）

**问题：** 做了太多事情，包括数据清理、查询、过滤、转换、异步计算等。

**重构方案：**

**拆分为多个小方法：**
```swift
class MainViewModel {
    // MARK: - Public Methods
    func loadHistories() {
        performAutoCleanup()
        fetchHistoryData()
    }
    
    // MARK: - Private Methods
    private func performAutoCleanup() {
        guard shouldPerformCleanup() else { return }
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.historyService.cleanupOldHistories()
        }
    }
    
    private func shouldPerformCleanup() -> Bool {
        let lastCleanup = UserDefaults.standard.object(forKey: "LastHistoryCleanup") as? Date
        let daysSinceCleanup = lastCleanup.map { Date().timeIntervalSince($0) / 86400 } ?? 7
        return daysSinceCleanup >= 7
    }
    
    private func fetchHistoryData() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let favorites = self.fetchFavorites()
            let histories = self.fetchHistories(excluding: favorites)
            let sections = self.transformToSections(histories: histories, favorites: favorites)
            
            self.updateUI(with: sections)
        }
    }
    
    private func fetchFavorites() -> Set<String> {
        let allFavorites = favoriteService.getAllFavorites()
        return Set(allFavorites.map { $0.url })
    }
    
    private func fetchHistories(excluding favoriteURLs: Set<String>) -> [WebPageHistory] {
        let historyResults = historyService.getAllHistories()
            .sorted(byKeyPath: "lastVisitDate", ascending: false)
        
        return Array(historyResults.prefix(WebBridgeKitConfiguration.History.maxItems))
            .filter { !favoriteURLs.contains($0.url) }
    }
    
    private func transformToSections(histories: [WebPageHistory], 
                                    favorites: Set<String>) -> [WebPageHistorySection] {
        let pinned = histories.filter { $0.isPinned }
        let recent = histories.filter { !$0.isPinned }
        
        var sections: [WebPageHistorySection] = []
        
        if !pinned.isEmpty {
            sections.append(WebPageHistorySection(header: "置顶", items: pinned))
        }
        
        if !recent.isEmpty {
            sections.append(WebPageHistorySection(header: "最近", items: recent))
        }
        
        return sections
    }
    
    private func updateUI(with sections: [WebPageHistorySection]) {
        DispatchQueue.main.async { [weak self] in
            self?.historiesRelay.accept(sections)
        }
    }
}
```

**或者创建专门的服务类：**
```swift
// 新建文件：DemoApp/Sources/Services/HistoryDataService.swift
class HistoryDataService {
    private let historyManager: WebPageHistoryManager
    private let favoriteManager: URLFavoriteManager
    
    init(historyManager: WebPageHistoryManager = .shared,
         favoriteManager: URLFavoriteManager = .shared) {
        self.historyManager = historyManager
        self.favoriteManager = favoriteManager
    }
    
    func loadHistorySections() async -> [WebPageHistorySection] {
        let favorites = await fetchFavorites()
        let histories = await fetchHistories(excluding: favorites)
        return transformToSections(histories: histories)
    }
    
    private func fetchFavorites() async -> Set<String> {
        // 实现
    }
    
    private func fetchHistories(excluding favoriteURLs: Set<String>) async -> [WebPageHistory] {
        // 实现
    }
    
    private func transformToSections(histories: [WebPageHistory]) -> [WebPageHistorySection] {
        // 实现
    }
}

// MainViewModel 简化为：
class MainViewModel {
    private let historyDataService = HistoryDataService()
    
    func loadHistories() {
        Task {
            let sections = await historyDataService.loadHistorySections()
            await MainActor.run {
                historiesRelay.accept(sections)
            }
        }
    }
}
```

### 重构原则

1. **单一职责原则（SRP）**：每个类只负责一件事
2. **方法长度**：每个方法不超过 30 行
3. **类长度**：每个类不超过 300 行
4. **嵌套深度**：不超过 3 层
5. **参数数量**：不超过 4 个

### 预期结果

- ✅ 所有类长度 < 300 行
- ✅ 所有方法长度 < 30 行
- ✅ 职责清晰，易于理解
- ✅ 易于测试和维护

---

## 🔍 优先级 6：统一错误处理方式（低）

### 任务描述

统一项目中的错误处理方式，提高一致性。

### 当前问题

项目中混用了多种错误处理方式：
- Result 类型
- throws/try/catch
- completion 回调
- RxSwift Observable

### 统一方案

**推荐使用 async/await + throws（Swift 5.5+）**

#### 1. 统一异步方法签名

**修改前（混乱）：**
```swift
// 方式1：Result
func fetchResource(url: URL) -> Result<Data, Error> { }

// 方式2：throws
func loadManifest() throws -> Manifest { }

// 方式3：completion
func download(completion: @escaping (Data?, Error?) -> Void) { }

// 方式4：RxSwift
func getData() -> Observable<Data> { }
```

**修改后（统一）：**
```swift
// 统一使用 async/await + throws
func fetchResource(url: URL) async throws -> Data { }
func loadManifest() async throws -> Manifest { }
func download() async throws -> Data { }
func getData() async throws -> Data { }
```

#### 2. 统一错误类型

**创建统一的错误枚举：**
```swift
// Sources/Models/WebBridgeError.swift
public enum WebBridgeError: Error, LocalizedError {
    // 网络错误
    case networkUnavailable(reason: String)
    case networkRequestFailed(underlying: Error)
    case timeout
    
    // 缓存错误
    case cacheLoadFailed(reason: String)
    case cacheSaveFailed(underlying: Error)
    case cacheNotFound(key: String)
    
    // 数据库错误
    case databaseOperationFailed(underlying: Error)
    case databaseNotFound
    
    // 验证错误
    case invalidInput(reason: String)
    case validationFailed(field: String, reason: String)
    
    // Manifest 错误
    case manifestError(ManifestError)
    
    public var errorDescription: String? {
        switch self {
        case .networkUnavailable(let reason):
            return "网络不可用: \(reason)"
        case .networkRequestFailed(let error):
            return "网络请求失败: \(error.localizedDescription)"
        case .timeout:
            return "请求超时"
        case .cacheLoadFailed(let reason):
            return "缓存加载失败: \(reason)"
        case .cacheSaveFailed(let error):
            return "缓存保存失败: \(error.localizedDescription)"
        case .cacheNotFound(let key):
            return "缓存未找到: \(key)"
        case .databaseOperationFailed(let error):
            return "数据库操作失败: \(error.localizedDescription)"
        case .databaseNotFound:
            return "数据库未找到"
        case .invalidInput(let reason):
            return "输入无效: \(reason)"
        case .validationFailed(let field, let reason):
            return "验证失败 [\(field)]: \(reason)"
        case .manifestError(let error):
            return "Manifest 错误: \(error.localizedDescription)"
        }
    }
}
```

#### 3. 统一错误处理模式

**在 ViewModel 中：**
```swift
class MainViewModel {
    func loadData() {
        Task {
            do {
                let data = try await dataService.fetchData()
                await MainActor.run {
                    self.updateUI(with: data)
                }
            } catch let error as WebBridgeError {
                await MainActor.run {
                    self.showError(error)
                }
            } catch {
                await MainActor.run {
                    self.showError(.networkRequestFailed(underlying: error))
                }
            }
        }
    }
    
    private func showError(_ error: WebBridgeError) {
        errorRelay.accept(error.localizedDescription)
    }
}
```

**在 ViewController 中：**
```swift
class MainViewController: UIViewController {
    func handleError(_ error: WebBridgeError) {
        let alert = UIAlertController(
            title: "错误",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
```

### 需要修改的文件

1. `Sources/Handlers/WebPageCacheHandler.swift`
2. `Sources/Cache/ManifestCacheManager.swift`
3. `Sources/Managers/WebPageHistoryManager.swift`
4. `DemoApp/Sources/ViewModels/MainViewModel.swift`
5. 所有使用 completion 回调的方法

### 预期结果

- ✅ 所有异步方法使用 async/await
- ✅ 所有错误使用统一的错误类型
- ✅ 错误处理模式一致

---

## 📊 验证清单

完成所有任务后，请执行以下验证：

### 编译验证
- [ ] 项目可以成功编译
- [ ] 无编译错误
- [ ] 无编译警告

### 测试验证
- [ ] 所有单元测试通过
- [ ] 代码覆盖率 > 80%
- [ ] 无测试失败

### 内存验证
- [ ] 使用 Instruments Leaks 工具检测
- [ ] 使用 Debug Memory Graph 检查
- [ ] 多次打开关闭页面，内存稳定

### 性能验证
- [ ] 使用 Instruments Time Profiler 分析
- [ ] 关键操作耗时 < 100ms
- [ ] 启动时间 < 2s

### 功能验证
- [ ] 手动测试主要流程
- [ ] 验证错误提示友好
- [ ] 验证离线行为正确

### 代码质量验证
- [ ] 所有公开 API 都有文档
- [ ] 无魔法数字
- [ ] 方法和类长度合理
- [ ] 错误处理统一

---

## 📚 参考文档

### 项目文档
- `REMAINING_ISSUES_WITH_VERIFICATION.md` - 原始问题清单
- `FIXES_SUMMARY_REPORT.md` - 已完成的修复报告
- `FINAL_REPORT.md` - 最终状态报告
- `FRAMEWORK_FEATURES.md` - 框架功能说明
- `DEMO_APP_FEATURES.md` - Demo 应用功能说明
- `ARCHITECTURE_AND_DATA_FLOW.md` - 架构和数据流转

### 代码位置
- 框架源代码：`Sources/`
- Demo 应用：`DemoApp/Sources/`
- 测试文件：`Tests/`
- 工具类：`Sources/Utils/`

### 关键文件
- `Sources/Handlers/WebPageCacheHandler.swift` - 页面缓存处理
- `Sources/Cache/ManifestCacheManager.swift` - Manifest 缓存管理
- `Sources/Controllers/WebViewController.swift` - Web 视图控制器
- `Sources/Utils/NetworkMonitor.swift` - 网络监控
- `Sources/Utils/PerformanceMonitor.swift` - 性能监控

---

## 🎯 任务优先级总结

| 优先级 | 任务 | 预计时间 | 重要性 |
|--------|------|----------|--------|
| 🔥 P1 | 修复编译错误 | 30 分钟 | 必须 |
| ⭐️ P2 | 添加单元测试 | 2-3 天 | 重要 |
| 📝 P3 | 完善 API 文档 | 1-2 天 | 中等 |
| 🔧 P4 | 消除魔法数字 | 半天 | 低 |
| 🏗️ P5 | 重构长方法 | 1-2 天 | 低 |
| 🔍 P6 | 统一错误处理 | 1 天 | 低 |

**总预计时间：** 5-8 天

---

## 💡 提示和建议

### 对于 AI 代理
1. **优先修复编译错误**：这是最紧急的任务，必须先完成
2. **逐步进行**：不要一次性修改太多文件
3. **保持一致性**：遵循现有的代码风格和命名规范
4. **添加注释**：在关键位置添加清晰的注释
5. **测试验证**：每完成一个任务都要测试验证

### 代码风格
- 使用 4 空格缩进
- 遵循 Swift API 设计指南
- 使用有意义的变量名
- 保持代码简洁清晰

### Git 提交
建议每完成一个任务就提交一次：
```bash
git add .
git commit -m "feat: 添加单元测试"
git commit -m "docs: 完善 API 文档"
git commit -m "refactor: 重构 MainViewController"
```

---

## 📞 联系方式

如有问题或需要澄清，请参考：
- 项目文档目录中的其他 Markdown 文件
- 代码中的注释和文档
- Swift 官方文档

---

**文档创建：** 2026-02-10  
**文档版本：** 1.0  
**适用对象：** AI 代理、开发人员  
**预期完成时间：** 5-8 天

