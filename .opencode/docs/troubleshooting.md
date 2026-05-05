# WebBridgeKit 开发排障指南

> 本文档记录了开发过程中遇到的所有编译错误、构建问题及解决方案。
> 子任务在遇到编译/测试问题时，**务必先查阅本文档**。

## 目录
1. [编译错误速查](#编译错误速查)
2. [构建/测试环境问题](#构建测试环境问题)
3. [Swift 并发陷阱](#swift-并发陷阱)
4. [CocoaPods 配置](#cocoapods-配置)
5. [XcodeGen 配置](#xcodegen-配置)
6. [SwiftLint 常见违规](#swiftlint-常见违规)
7. [架构模式参考](#架构模式参考)

---

## 编译错误速查

### 1. Duplicate type declarations（重复类型声明）

**症状**: `Invalid redeclaration of 'CacheStatistics'` / `'CacheMetadata'`

**原因**: 新模块的类型名与现有代码冲突。例如 Cache 模块定义了 `CacheStatistics`，但 `SystemURLCacheManager.swift` 里也有同名 struct。

**解决方案**: 新模块的类型使用命名空间前缀或更具体的名称：
- `CacheStatistics` → 保持新模块的命名
- 旧代码中的同名类型 → 重命名为 `SystemCacheStatistics`、`ResourceCacheMetadata` 等
- 搜索全项目: `grep -rn "struct CacheStatistics" Sources/ --include="*.swift"`

**预防**: 创建新类型前，先用 grep 检查是否已存在同名类型。

### 2. `any Sendable` cannot conform to `Encodable`

**症状**: `Type 'any Sendable' cannot conform to 'Encodable'`

**原因**: Existential type (`any Protocol`) 不能自动遵循另一个协议。

**解决方案**: 使用具体类型约束：
```swift
// ❌ 错误
func generate(from dictionary: [String: any Sendable]) -> String

// ✅ 正确
func generate(from dictionary: [String: any Encodable & Sendable]) -> String
```

### 3. Actor isolation errors（Actor 隔离错误）

**症状**: `Expression is 'async' but is not marked with 'await'` / `Actor-isolated property 'x' can not be mutated from a '@MainActor' context`

**原因**: Actor 属性只能在 actor 内部同步访问，跨 actor 必须用 `await`。

**解决方案**:
```swift
// ❌ 错误 - 在 @MainActor 方法中直接访问 actor 属性
@MainActor func applyTheme() {
    let theme = currentTheme  // 错误！currentTheme 是 actor 隔离的
}

// ✅ 正确 - 先异步获取，再使用
@MainActor func applyTheme() async {
    let theme = await themeManager.getTheme()
    // 使用 theme...
}

// ❌ 错误 - 在 actor 回调中使用 await MainActor.run
await engine.setOnMessageReceived { message in
    await MainActor.run {  // 编译错误：回调不是 async
        updateUI(message)
    }
}

// ✅ 正确 - 使用 Task 包装
await engine.setOnMessageReceived { message in
    Task { @MainActor in
        updateUI(message)
    }
}
```

### 4. Protocol conformance issues（协议一致性问题）

**症状**: `Type 'HybridCache' does not conform to protocol 'CacheStorage'`

**原因**: 协议使用泛型关联类型，但实现使用了 existential type (`any Codable & Sendable`)。

**解决方案**: 使用泛型替代 existential type：
```swift
// ❌ 错误
public actor HybridCache: CacheStorage {
    public typealias Value = any Codable & Sendable  // existential
}

// ✅ 正确
public actor HybridCache<Value: Codable & Sendable>: CacheStorage {
    // 泛型参数满足协议约束
}
```

### 5. Missing `public` on framework types

**症状**: 外部 target 无法访问框架内部的类型。

**原因**: Swift 默认访问级别是 `internal`，框架消费者看不到。

**解决方案**: 所有需要外部访问的类型、方法、属性必须标记 `public`：
```swift
// ❌ 框架内部可见
class HTMLResourceParser { ... }

// ✅ 框架外部可见
public class HTMLResourceParser { ... }
```

**注意**: 以下类型**不需要** public：
- Rx 代理类（`RxWKUIDelegateProxy` 等）
- 内部 Realm 模型（`PageCacheRuleRealm`）
- UI 内部 ViewModel/Cell

---

## 构建/测试环境问题

### 6. iOS Simulator Runtime 版本不匹配

**症状**: `Unable to find a device matching the provided destination specifier`

**原因**: Xcode SDK 版本与安装的 Simulator Runtime 不匹配。

**排查步骤**:
```bash
# 检查 SDK 版本
xcodebuild -showsdks | grep "iOS Simulator"

# 检查已安装的 Runtime
xcrun simctl list runtimes

# 检查已启动的模拟器
xcrun simctl list devices | grep "Booted"
```

**解决方案**:
- 如果 Runtime 已安装，直接用 `iPhone 16 Pro`（不带 OS 版本号）作为 destination
- 如果 Runtime 未安装，去 Xcode → Settings → Platforms 下载
- **避免**指定 `OS=18.3` 等具体版本号，优先用 `OS=latest` 或不指定

### 7. Scheme 只显示 Mac Catalyst

**症状**: `xcodebuild -list` 显示 scheme 只支持 Mac Catalyst。

**原因**: XcodeGen 生成的 project.pbxproj 中 `SDKROOT = iphoneos` 硬编码。

**解决方案**:
```bash
# 删除 SDKROOT 行
sed -i.bak '/^\t\tSDKROOT = iphoneos;$/d' WebBridgeKit.xcodeproj/project.pbxproj

# 或者使用 -sdk 参数绕过
xcodebuild build -scheme Cache -sdk iphonesimulator -arch arm64
```

### 8. xcodebuild destination 解析失败

**症状**: `No destinations for the scheme 'Cache' and action build`

**可靠方案**: 始终使用 `-sdk iphonesimulator -arch arm64` 替代 `-destination`:
```bash
# ❌ 不可靠（依赖 runtime 版本匹配）
xcodebuild build -scheme Cache -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# ✅ 可靠（直接指定 SDK 和架构）
xcodebuild build -scheme Cache -sdk iphonesimulator -arch arm64
```

对于**测试**，需要用 destination（因为测试需要在模拟器中运行）:
```bash
# 使用已 Booted 的模拟器
xcodebuild test -scheme CacheTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

---

## Swift 并发陷阱

### 9. `for` loop with `if` inside → use `where` clause

**SwiftLint 规则 `for_where`**:
```swift
// ❌ 触发警告
for pattern in excludePatterns {
    if let regex = try? NSRegularExpression(pattern: pattern) {
        // ...
    }
}

// ✅ 正确
for pattern in excludePatterns where let regex = try? NSRegularExpression(pattern: pattern) {
    // ...
}
```

### 10. Sendable conformance in closures

**症状**: `Capture of 'x' with non-sendable type in a @Sendable closure`

**解决方案**:
```swift
// 在 closure 之前拷贝值
let weakSelf = self
await engine.setOnMessageReceived { message in
    Task { @MainActor in
        weakSelf?.handleMessage(message)
    }
}
```

---

## CocoaPods 配置

### 11. Test target 找不到 Pod 依赖

**症状**: `No such module 'RealmSwift'` / `'RxSwift'` in test target

**原因**: Test target 的 Podfile 配置不正确。

**解决方案**: Podfile 中 test target 必须使用 `inherit! :complete`:
```ruby
# Tests
target 'CacheTests' do
  inherit! :complete
end

target 'HandlerTests' do
  inherit! :complete
end
```

**注意**: `inherit! :search_paths` 不够，test target 需要完整继承 pod 链接。

### 12. Material pod asset catalog 不兼容

**症状**: `No simulator runtime version available to use with iphonesimulator SDK version`

**原因**: Material 3.1.8 的 asset catalog 与 Xcode 26+ SDK 不兼容。

**解决方案**: 考虑替换为其他 UI 库，或升级 Material 版本。

---

## XcodeGen 配置

### 13. 新增 test target 的完整步骤

1. 在 `project.yml` 的 `targets` 下添加:
```yaml
NewModuleTests:
  type: bundle.unit-test
  platform: iOS
  sources:
    - Tests/NewModuleTests
  dependencies:
    - target: WebBridgeKit
  settings:
    SUPPORTED_PLATFORMS: "iphonesimulator iphoneos"
```

2. 在 `Podfile` 添加:
```ruby
target 'NewModuleTests' do
  inherit! :complete
end
```

3. 运行:
```bash
xcodegen generate --spec project.yml --project .
pod install
```

4. 验证 scheme 存在:
```bash
xcodebuild -list -workspace WebBridgeKit.xcworkspace | grep NewModuleTests
```

---

## SwiftLint 常见违规

### 14. 高频违规修复速查

| 规则 | 违规写法 | 修复 |
|------|----------|------|
| `for_where` | `for x { if cond { } }` | `for x where cond { }` |
| `unused_closure_parameter` | `{ param in ... }` (未用 param) | `{ _ in ... }` |
| `redundant_string_enum_value` | `case foo = "foo"` | `case foo` |
| `implicit_optional_initialization` | `var x: String? = nil` | `var x: String?` |
| `empty_count` | `.count == 0` | `.isEmpty` |
| `orphaned_doc_comment` | `///` 后面没有声明 | 改为 `//` |
| `trailing_newline` | 文件末尾多余空行 | 删除多余空行 |
| `multiple_closures_with_trailing_closure` | `method { } completion: { }` | `method(…, completion: { })` |
| `notification_center_detachment` | `removeObserver` 在 `viewWillDisappear` | 移到 `deinit` |
| `function_parameter_count` | 超过 5 个参数 | 添加 `// swiftlint:disable:next function_parameter_count` |

**批量修复**: `swiftlint --fix --format` 可自动修复大部分格式问题。

---

## 架构模式参考

### 15. Handler 测试模式

```swift
// 所有 Handler 都遵循 WebNativeAPI 协议
// 测试模式：实例化 → 传参 → 捕获结果 → 断言

func testMyHandler() {
    let handler = WebMyHandler()
    let expectation = XCTestExpectation(description: "completion")
    var result: [String: Any]?
    
    handler.handle(body: ["param": "value"]) { r in
        result = r as? [String: Any]
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 2.0)
    
    XCTAssertEqual(result?["success"] as? Bool, true)
}
```

**注意**:
- 使用 `runOnMainThread` 的 handler 需要用 `XCTestExpectation`
- 不使用 `runOnMainThread` 的 handler 同步返回，不需要 wait
- `webView` 属性默认为 nil，大部分 handler 可以在无 WebView 下测试

### 16. Actor 单例模式

```swift
public actor MyEngine {
    public static let shared = MyEngine()
    private var state: [String: Any] = [:]
    
    private init() {}
    
    public func getState() -> [String: Any] {
        state
    }
}
```

### 17. 处理器管道模式（参考 Bark）

```swift
public protocol MessageProcessor: Sendable {
    var identifier: String { get }
    var priority: Int { get }
    func process(content: MutableMessageContent) async throws -> MutableMessageContent
}

public actor MessageProcessorPipeline {
    private var processors: [any MessageProcessor] = []
    
    public func register(_ processor: any MessageProcessor) {
        processors.append(processor)
        processors.sort { $0.priority < $1.priority }
    }
    
    public func process(content: MutableMessageContent) async throws -> MutableMessageContent {
        var current = content
        for processor in processors {
            current = try await processor.process(content: current)
        }
        return current
    }
}
```

---

## 文件路径参考

| 用途 | 路径 |
|------|------|
| 项目配置 | `project.yml` |
| 依赖管理 | `Podfile` |
| CI 配置 | `.github/workflows/ci.yml` |
| 项目大纲 | `.opencode/outline.md` |
| 排障指南 | `.opencode/docs/troubleshooting.md` (本文档) |
| 日志模块 | `Sources/Infrastructure/Logging/` |
| 诊断模块 | `Sources/Infrastructure/Diagnostic/` |
| Handler 注册 | `Sources/Bridge/Meta/HandlerMetaRegistry.swift` |
| 消息引擎 | `Sources/Message/` |
| 缓存引擎 | `Sources/Cache/` |
| AI 引擎 | `Sources/AI/` |
| 测试目录 | `Tests/{Module}Tests/` |
