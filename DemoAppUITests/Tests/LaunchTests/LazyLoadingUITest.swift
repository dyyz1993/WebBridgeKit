//
//  LazyLoadingUITest.swift
//  DemoAppUITests
//
//  Created on 2025-02-03.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import XCTest

/// 懒加载和持久化加载的 UI 测试
/// 测试 Manifest 缓存功能的用户交互流程
final class LazyLoadingUITest: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        // 初始化应用
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]

        // 设置启动超时 (XCUITest doesn't have launchTimeout, use launch arguments instead)

        // 启动应用
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - 测试方法

    /// 测试懒加载模式打开全屏 WebView
    func testLazyLoadingOpensFullScreenWebView() {
        // 导航到缓存测试页面
        navigateToCacheTestPage()

        // 确保是懒加载模式
        let modeSegment = app.segmentedControls["manifest_test.mode_segment"]
        XCTAssertTrue(modeSegment.exists, "模式选择器应该存在")
        modeSegment.buttons["懒加载"].tap()

        // 点击开始测试
        let startButton = app.buttons["manifest_test.start_button"]
        XCTAssertTrue(startButton.exists, "开始测试按钮应该存在")
        XCTAssertTrue(startButton.isEnabled, "开始测试按钮应该可用")
        startButton.tap()

        // 验证：应该看到全屏 WebView 页面
        let webViewDisplayVC = app.otherElements["WebViewDisplayViewController"]
        let fullScreenExists = webViewDisplayVC.waitForExistence(timeout: 10)
        XCTAssertTrue(fullScreenExists, "应该看到全屏 WebView 展示页面")

        // 验证：应该看到关闭按钮
        let closeButton = app.buttons["webview_display.close_button"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "应该看到关闭按钮")

        // 验证：WebView 已加载内容
        let webView = app.webViews["manifest_test.webview"]
        XCTAssertTrue(webView.exists, "WebView 应该存在")

        // 关闭页面
        closeButton.tap()

        // 验证：返回到测试页面
        XCTAssertTrue(startButton.waitForExistence(timeout: 3), "应该返回到测试页面")
    }

    /// 测试持久化模式显示全屏进度条
    func testPersistentLoadingShowsFullScreenProgress() {
        // 导航到缓存测试页面
        navigateToCacheTestPage()

        // 切换到持久化模式
        let modeSegment = app.segmentedControls["manifest_test.mode_segment"]
        XCTAssertTrue(modeSegment.exists, "模式选择器应该存在")
        modeSegment.buttons["持久化"].tap()

        // 点击开始测试
        let startButton = app.buttons["manifest_test.start_button"]
        XCTAssertTrue(startButton.exists, "开始测试按钮应该存在")
        XCTAssertTrue(startButton.isEnabled, "开始测试按钮应该可用")
        startButton.tap()

        // 验证：应该看到全屏进度页面
        let progressVC = app.otherElements["FullScreenProgressViewController"]
        let progressExists = progressVC.waitForExistence(timeout: 5)
        XCTAssertTrue(progressExists, "应该看到全屏进度页面")

        // 验证：应该看到进度条
        let progressIndicator = app.progressIndicators.firstMatch
        XCTAssertTrue(progressIndicator.exists, "应该看到进度条")

        // 验证：进度完成后，WebView 页面打开
        let webViewDisplayVC = app.otherElements["WebViewDisplayViewController"]
        let webViewExists = webViewDisplayVC.waitForExistence(timeout: 30)
        XCTAssertTrue(webViewExists, "进度完成后应该打开全屏 WebView 页面")

        // 关闭页面
        let closeButton = app.buttons["webview_display.close_button"]
        if closeButton.exists {
            closeButton.tap()
        }
    }

    /// 测试懒加载模式的后台下载（不需要等待完成）
    func testLazyLoadingBackgroundDownload() {
        // 导航到缓存测试页面
        navigateToCacheTestPage()

        // 切换到懒加载模式
        let modeSegment = app.segmentedControls["manifest_test.mode_segment"]
        modeSegment.buttons["懒加载"].tap()

        // 点击开始测试
        let startButton = app.buttons["manifest_test.start_button"]
        startButton.tap()

        // 验证：立即打开全屏 WebView（不等待下载完成）
        let webViewDisplayVC = app.otherElements["WebViewDisplayViewController"]
        let openedQuickly = webViewDisplayVC.waitForExistence(timeout: 5)
        XCTAssertTrue(openedQuickly, "懒加载应该快速打开全屏页面（不等待下载）")

        // 关闭页面
        let closeButton = app.buttons["webview_display.close_button"]
        closeButton.tap()
    }

    /// 测试模式切换
    func testModeSwitching() {
        // 导航到缓存测试页面
        navigateToCacheTestPage()

        let modeSegment = app.segmentedControls["manifest_test.mode_segment"]

        // 切换到懒加载
        modeSegment.buttons["懒加载"].tap()
        XCTAssertTrue(modeSegment.buttons["懒加载"].isSelected, "懒加载模式应该被选中")

        // 切换到持久化
        modeSegment.buttons["持久化"].tap()
        XCTAssertTrue(modeSegment.buttons["持久化"].isSelected, "持久化模式应该被选中")

        // 切换回懒加载
        modeSegment.buttons["懒加载"].tap()
        XCTAssertTrue(modeSegment.buttons["懒加载"].isSelected, "懒加载模式应该被选中")
    }

    /// 测试缓存清除功能
    func testClearCache() {
        // 导航到缓存测试页面
        navigateToCacheTestPage()

        let clearCacheButton = app.buttons["manifest_test.clear_cache_button"]
        XCTAssertTrue(clearCacheButton.exists, "清除缓存按钮应该存在")

        // 点击清除缓存
        clearCacheButton.tap()

        // 等待可能的确认对话框（如果有的话）
        let alert = app.alerts.firstMatch
        if alert.exists {
            alert.buttons["确定"].tap()
        }

        // 验证按钮仍然可点击（没有崩溃）
        XCTAssertTrue(clearCacheButton.exists, "清除缓存后按钮应该仍然存在")
    }

    /// 测试 URL 输入字段
    func testURLInputField() {
        // 导航到缓存测试页面
        navigateToCacheTestPage()

        let urlField = app.textFields["manifest_test.url_field"]
        XCTAssertTrue(urlField.exists, "URL 输入框应该存在")

        // 点击输入框
        urlField.tap()

        // 验证可以输入
        let testURL = "https://example.com/test"
        urlField.typeText(testURL)

        // 验证输入成功
        XCTAssertTrue(urlField.value as? String == testURL, "URL 应该被正确输入")
    }

    // MARK: - 辅助方法

    /// 导航到缓存测试页面
    private func navigateToCacheTestPage() {
        // 等待应用启动完成
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab Bar 应该存在")

        // 点击"缓存测试"标签
        let cacheTestTab = tabBar.buttons["缓存测试"]
        XCTAssertTrue(cacheTestTab.exists, "缓存测试标签应该存在")

        if !cacheTestTab.isSelected {
            cacheTestTab.tap()

            // 等待页面加载
            let startButton = app.buttons["manifest_test.start_button"]
            XCTAssertTrue(startButton.waitForExistence(timeout: 5), "应该导航到缓存测试页面")
        }
    }
}
