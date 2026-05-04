//
//  BaseUITestCase.swift
//  DemoAppUITests
//
//  Created by Claude on 2025-02-01.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import XCTest

/// 基础 UI 测试用例类
/// 提供自动截图功能和通用测试辅助方法
public class BaseUITestCase: XCTestCase {

    // MARK: - Properties

    /// 应用实例
    var app: XCUIApplication!

    /// 是否启用截图
    var screenshotsEnabled: Bool = true

    // MARK: - Setup / Teardown

    public override func setUpWithError() throws {
        continueAfterFailure = false

        // 初始化截图目录
        TestScreenshotHelper.setupScreenshotsDirectory()

        // 启动应用
        app = XCUIApplication()
        app.launchArguments = ["UITesting"]
        app.launchEnvironment = [
            "UITesting": "1",
            "DISABLE_ANIMATIONS": "1"
        ]
        app.launch()

        // 测试开始时截图
        if screenshotsEnabled {
            captureSetupScreenshot(app: app)
        }

        print("✅ Test started: \(name)")
    }

    public override func tearDownWithError() throws {
        // 测试结束时截图
        if screenshotsEnabled, let app = app {
            captureTeardownScreenshot(app: app)
        }

        // 终止应用
        if let app = app {
            app.terminate()
        }

        print("🔚 Test finished: \(name)")
    }

    // MARK: - Screenshot Helpers

    /// 在关键步骤捕获截图
    func captureStepScreenshot(stepName: String) {
        guard screenshotsEnabled, let app = app else { return }
        let filename = "\(name)_\(stepName)"
        TestScreenshotHelper.captureScreenshot(app, testName: filename, phase: .test)
    }

    /// 验证元素存在并截图
    func verifyAndScreenshot(_ element: XCUIElement,
                            description: String = "Element verification") -> Bool {
        let exists = element.waitForExistence(timeout: 5)

        if screenshotsEnabled {
            let phase = exists ? ScreenshotPhase.test : .failure
            let testName = "\(name)_\(description)"
            TestScreenshotHelper.captureScreenshot(app, testName: testName, phase: phase)
        }

        if !exists {
            XCTFail("Element not found: \(description)")
            captureFailureScreenshot(app: app, error: "Element not found: \(description)")
        }

        return exists
    }
}

// MARK: - DemoAppUITests 基类扩展

/// DemoApp 专用测试基类
/// 包含 DemoApp 特定的页面和辅助方法
public class DemoAppUITestCase: BaseUITestCase {

    // MARK: - Page Objects

    var mainPage: MainPage!
    var webAccessPage: WebAccessPage!

    // MARK: - Setup / Teardown

    public override func setUpWithError() throws {
        try super.setUpWithError()

        // 初始化页面对象
        mainPage = MainPage(app: app)
        webAccessPage = WebAccessPage(app: app)
    }

    // MARK: - Navigation Helpers

    /// 导航到主页
    func navigateToMain() -> Bool {
        return mainPage.verifyPageLoaded()
    }

    /// 导航到 Web 访问页面
    func navigateToWebAccess() -> Bool {
        return webAccessPage.navigateViaTab()
    }

    /// 等待 WebView 加载
    func waitForWebView(timeout: TimeInterval = 10) -> Bool {
        return webAccessPage.waitForElementToAppear(webAccessPage.webView, timeout: timeout)
    }
}
