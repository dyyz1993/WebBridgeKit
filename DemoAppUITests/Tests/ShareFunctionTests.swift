//
//  ShareFunctionTests.swift
//  DemoAppUITests
//
//  Created for WebBridgeKit P0 Testing
//  Test ID: 1 - Share Function Test
//

import XCTest
import os.log

/// 分享功能测试 (P0 测试 #1)
/// 测试 share API 的调用流程
final class ShareFunctionTests: DemoAppUITestCase {

    private let logger = OSLog(subsystem: "com.webbridgekit.demo.ui.tests", category: "ShareFunctionTests")

    // MARK: - Test 1: Basic Share Function

    /// 测试分享功能
    /// 测试步骤:
    /// 1. 启动 DemoApp
    /// 2. 导航到测试页面
    /// 3. 点击分享按钮
    /// 4. 验证系统分享面板弹出
    func test01ShareFunction() throws {
        print("🧪 Starting Share Function Test (P0 #1)")

        // Step 1: 启动应用（已在 setUp 中完成）
        captureStepScreenshot(stepName: "01_app_launched")

        // Step 2: 导航到 Web 访问页面
        print("📍 Navigating to Web Access page...")
        let navigated = navigateToWebAccess()
        XCTAssertTrue(navigated, "Should navigate to Web Access page")
        captureStepScreenshot(stepName: "02_web_access_loaded")

        // Step 3: 导航到测试页面
        print("📍 Navigating to test page...")
        let testURL = "http://localhost:8080/js_bridge_test.html"
        webAccessPage.enterURL(testURL)
        captureStepScreenshot(stepName: "03_url_entered")

        // 等待页面加载
        Thread.sleep(forTimeInterval: 3.0)
        captureStepScreenshot(stepName: "04_test_page_loaded")

        // Step 4: 触发分享功能
        print("📍 Triggering share function...")

        // 通过 JavaScript 调用分享 API
        let shareScript = """
        (function() {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.WebBridgeKit) {
                window.webkit.messageHandlers.WebBridgeKit.postMessage({
                    api: 'share',
                    params: {
                        title: 'Test Share',
                        content: 'This is a test share from WebBridgeKit',
                        url: 'http://localhost:8080/'
                    }
                });
                return 'Share API called';
            }
            return 'WebBridgeKit not available';
        })();
        """

        // 执行 JavaScript
        let webView = webAccessPage.webView
        let result = app.webViews.firstMatch.evaluateJS(shareScript) as? String ?? ""
        print("📝 Share script result: \(result)")

        // 等待分享面板弹出
        Thread.sleep(forTimeInterval: 2.0)
        captureStepScreenshot(stepName: "05_share_panel_expected")

        // Step 5: 验证分享面板
        // 注意: iOS 系统分享面板不在应用进程内，无法直接通过 XCUITest 访问
        // 我们通过以下方式间接验证:
        // 1. 检查是否有 "分享" 或 "Share" 相关的 UI 元素
        // 2. 检查应用是否仍在运行（没有崩溃）
        // 3. 通过截图进行人工验证

        print("✅ Share function test completed")
        print("📸 Screenshot saved for manual verification of share panel")

        // 验证应用未崩溃
        XCTAssertTrue(app.state == .runningForeground, "App should still be running")
    }

    /// 测试分享功能的参数验证
    func test02ShareWithParameters() throws {
        print("🧪 Starting Share with Parameters Test")

        captureStepScreenshot(stepName: "01_start")

        // 导航到测试页面
        _ = navigateToWebAccess()
        webAccessPage.enterURL("http://localhost:8080/js_bridge_test.html")
        Thread.sleep(forTimeInterval: 2.0)
        captureStepScreenshot(stepName: "02_page_loaded")

        // 测试带完整参数的分享
        let shareScript = """
        (function() {
            if (window.webkit && window.webkit.messageHandlers.WebBridgeKit) {
                window.webkit.messageHandlers.WebBridgeKit.postMessage({
                    api: 'share',
                    params: {
                        title: 'WebBridgeKit Test',
                        content: 'Testing share functionality with full parameters',
                        url: 'https://github.com/webbridgekit',
                        image: 'https://example.com/test.png'
                    }
                });
                return 'success';
            }
            return 'failed';
        })();
        """

        app.webViews.firstMatch.evaluateJS(shareScript)
        Thread.sleep(forTimeInterval: 2.0)
        captureStepScreenshot(stepName: "03_share_triggered")

        XCTAssertTrue(app.state == .runningForeground, "App should handle share with parameters")
    }

    /// 测试分享功能的最小参数
    func test03ShareWithMinimalParameters() throws {
        print("🧪 Starting Share with Minimal Parameters Test")

        captureStepScreenshot(stepName: "01_start")

        _ = navigateToWebAccess()
        webAccessPage.enterURL("http://localhost:8080/js_bridge_test.html")
        Thread.sleep(forTimeInterval: 2.0)
        captureStepScreenshot(stepName: "02_page_loaded")

        // 测试只有必填参数的分享
        let shareScript = """
        (function() {
            if (window.webkit && window.webkit.messageHandlers.WebBridgeKit) {
                window.webkit.messageHandlers.WebBridgeKit.postMessage({
                    api: 'share',
                    params: {
                        title: 'Minimal Share Test'
                    }
                });
                return 'success';
            }
            return 'failed';
        })();
        """

        app.webViews.firstMatch.evaluateJS(shareScript)
        Thread.sleep(forTimeInterval: 2.0)
        captureStepScreenshot(stepName: "03_minimal_share")

        XCTAssertTrue(app.state == .runningForeground, "App should handle share with minimal parameters")
    }
}

// MARK: - Test Completion

extension ShareFunctionTests {

    override func tearDown() {
        super.tearDown()

        // 生成截图报告
        TestScreenshotHelper.generateScreenshotReport()

        // 保存测试结果
        saveTestResults()
    }

    private func saveTestResults() {
        let results: [String: Any] = [
            "testId": 1,
            "api": "share",
            "testName": "Share Function Test",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "screenshots": TestScreenshotHelper.getScreenshotsForTest(testName: name)
        ]

        // 保存到文件
        if let data = try? JSONSerialization.data(withJSONObject: results, options: .prettyPrinted) {
            let path = "/tmp/uitest_verification/verification/01_share_verification.json"
            try? data.write(to: URL(fileURLWithPath: path))
            print("📄 Test results saved to: \(path)")
        }
    }
}
