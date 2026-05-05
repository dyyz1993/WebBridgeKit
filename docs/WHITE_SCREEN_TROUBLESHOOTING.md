# 测试用例23白屏问题排查与解决方案

## 问题现象

点击测试用例23（综合演示页面）后，WebView显示白屏，无任何内容。

## 诊断结果

✅ 文件存在：`DemoApp/Resources/manifest_demo.html`
✅ 文件内容完整：548行，17258字节
✅ 已添加到Xcode项目配置
✅ WebBrowserManager文件存在

## 排查步骤

### 步骤1：添加调试日志

在 `ManifestTestCasesViewModel.swift` 的 `executeTest` 方法中添加详细日志：

```swift
// 在第463行之后添加
print("🔍 [DEBUG] 测试用例: \(testCase.name)")
print("🔍 [DEBUG] manifestURL: \(testCase.manifestURL.absoluteString)")
print("🔍 [DEBUG] isFileURL: \(testCase.manifestURL.isFileURL)")

// 构建页面 URL
let pageURL: URL
if testCase.manifestURL.isFileURL {
    pageURL = testCase.manifestURL
    print("🔍 [DEBUG] 使用本地文件URL: \(pageURL.absoluteString)")
} else {
    pageURL = testCase.manifestURL.deletingLastPathComponent()
    print("🔍 [DEBUG] 使用远程URL: \(pageURL.absoluteString)")
}

// 验证文件是否存在
if testCase.manifestURL.isFileURL {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: pageURL.path) {
        print("✅ [DEBUG] 文件存在: \(pageURL.path)")
    } else {
        print("❌ [DEBUG] 文件不存在: \(pageURL.path)")
        print("❌ [DEBUG] 这可能是白屏的原因！")
    }
}
```

### 步骤2：检查WebView加载状态

在 `WebViewController.swift` 中添加 `WKNavigationDelegate` 方法：

```swift
// 在WebViewController类中添加
extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("🌐 [WebView] 开始加载: \(webView.url?.absoluteString ?? "unknown")")
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ [WebView] 加载完成: \(webView.url?.absoluteString ?? "unknown")")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ [WebView] 加载失败: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ [WebView] 临时加载失败: \(error.localizedDescription)")
        print("❌ [WebView] URL: \(webView.url?.absoluteString ?? "unknown")")
    }
}
```

### 步骤3：检查Bundle资源加载

在 `ManifestTestCasesViewModel.swift` 的测试用例定义处添加验证：

```swift
// 在第238行附近修改
let manifestURL = Bundle.main.url(forResource: "manifest_demo", withExtension: "html") ?? URL(string: "about:blank")!

// 添加验证日志
if manifestURL.absoluteString == "about:blank" {
    print("❌ [ERROR] Bundle.main.url返回nil，文件未正确打包到Bundle中")
    print("❌ [ERROR] 请检查:")
    print("   1. 文件是否添加到DemoApp target")
    print("   2. Build Phases -> Copy Bundle Resources中是否包含该文件")
    print("   3. 是否需要Clean Build Folder")
} else {
    print("✅ [SUCCESS] Bundle资源加载成功: \(manifestURL.absoluteString)")
}

cases.append(ManifestTestCase(
    id: "jsbridge_manifest_demo",
    name: "23. 综合演示页面",
    description: "加载 manifest_demo.html，展示框架的综合能力。",
    manifestFileName: "manifest_demo.html",
    manifestURL: manifestURL
))
```

### 步骤4：检查WebBrowserParams配置

在 `WebBrowserParams.from(url:)` 方法中添加日志：

```swift
static func from(url: URL) -> WebBrowserParams {
    print("🔍 [DEBUG] 创建WebBrowserParams")
    print("🔍 [DEBUG] URL: \(url.absoluteString)")
    print("🔍 [DEBUG] scheme: \(url.scheme ?? "nil")")
    print("🔍 [DEBUG] isFileURL: \(url.isFileURL)")
    
    let params = WebBrowserParams()
    // ... 其他配置
    
    return params
}
```

## 常见原因与解决方案

### 原因1：Bundle资源未正确打包

**症状**：`Bundle.main.url(forResource:withExtension:)` 返回nil

**解决方案**：
1. 在Xcode中选择 `manifest_demo.html` 文件
2. 在右侧面板中勾选 `DemoApp` target
3. 清理并重新编译项目：
   ```bash
   xcodebuild clean -workspace WebBridgeKit.xcworkspace -scheme DemoApp
   xcodebuild -workspace WebBridgeKit.xcworkspace -scheme DemoApp -configuration Debug
   ```

### 原因2：WebView配置问题

**症状**：文件加载成功但页面空白

**解决方案**：
检查 `WKWebViewConfiguration` 配置：
```swift
let configuration = WKWebViewConfiguration()
configuration.preferences.javaScriptEnabled = true
configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
```

### 原因3：文件路径错误

**症状**：URL指向错误路径

**解决方案**：
确保使用正确的URL构建方式：
```swift
// 对于本地文件
let fileURL = Bundle.main.url(forResource: "manifest_demo", withExtension: "html")!

// 对于远程文件
let remoteURL = URL(string: "http://localhost:8080/manifest_demo.html")!
```

### 原因4：JavaScript错误

**症状**：页面加载但JavaScript执行失败

**解决方案**：
检查JavaScript控制台错误：
```swift
// 在WKUserContentController中添加脚本消息处理器
configuration.userContentController.add(self, name: "errorHandler")

// 在HTML中添加错误捕获
window.onerror = function(msg, url, line) {
    window.webkit.messageHandlers.errorHandler.postMessage({
        message: msg,
        url: url,
        line: line
    });
};
```

## 快速修复步骤

1. **添加调试日志**（按上述步骤1-4操作）
2. **运行应用**，点击测试用例23
3. **查看Xcode控制台输出**，定位具体错误
4. **根据错误类型**选择对应的解决方案

## 验证修复

修复后，验证以下内容：

1. ✅ 控制台输出正确的URL路径
2. ✅ 文件存在性检查通过
3. ✅ WebView开始加载回调触发
4. ✅ WebView加载完成回调触发
5. ✅ 页面内容正常显示

## 紧急回退方案

如果无法立即修复，可以使用以下回退方案：

```swift
// 在测试用例定义处临时修改
cases.append(ManifestTestCase(
    id: "jsbridge_manifest_demo",
    name: "23. 综合演示页面",
    description: "加载 manifest_demo.html，展示框架的综合能力。",
    manifestFileName: "manifest_demo.html",
    manifestURL: Bundle.main.url(forResource: "test", withExtension: "html") ?? URL(string: "about:blank")!
))
```

## 联系支持

如果以上步骤都无法解决问题，请提供以下信息：

1. Xcode控制台完整日志
2. 设备型号和iOS版本
3. Xcode版本
4. 项目编译配置（Debug/Release）
5. 是否使用CocoaPods或其他依赖管理工具

---

**文档版本**: 1.0
**最后更新**: 2026-02-13
**作者**: Claude Code Assistant
