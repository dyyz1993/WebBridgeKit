//
//  ScreenshotExampleTests.swift
//  DemoAppUITests
//
//  Created by Claude on 2025-02-01.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

/// 示例测试类，展示如何使用自动截图功能
///
/// 使用方法:
/// 1. 继承自 DemoAppUITestCase 而不是 XCTestCase
/// 2. 在 setUp/tearDown 时会自动截图
/// 3. 测试失败时自动截图
/// 4. 可以手动调用 captureStepScreenshot() 在关键步骤截图

import XCTest

final class ScreenshotExampleTests: DemoAppUITestCase {

    // MARK: - Tests

    /// 示例 1: 基础测试（自动截图）
    func testBasicExample() throws {
        // Given: 主页已加载
        XCTAssertTrue(mainPage.verifyPageLoaded(), "Main page should load")

        // When: 点击扫描按钮
        captureStepScreenshot(stepName: "before_scan_tap")
        mainPage.tapScanButton()

        // Then: 应该导航到 Web 访问页面
        captureStepScreenshot(stepName: "after_navigation")
        XCTAssertTrue(webAccessPage.verifyPageLoaded(), "Web access page should load")
    }

    /// 示例 2: 带验证的测试
    func testWithVerification() throws {
        // 使用 verifyAndScreenshot 方法
        let urlFieldExists = verifyAndScreenshot(
            webAccessPage.urlTextField,
            description: "URL_text_field"
        )

        if urlFieldExists {
            // 输入测试 URL
            webAccessPage.enterURL("http://localhost:8080/main_test.html")
            captureStepScreenshot(stepName: "url_entered")

            // 等待加载
            Thread.sleep(forTimeInterval: 2.0)
            captureStepScreenshot(stepName: "page_loaded")
        }
    }

    /// 示例 3: 测试失败时的自动截图
    func testFailureExample() throws {
        // 这个测试会故意失败，以展示失败截图功能
        navigateToWebAccess()

        // 故意触发失败
        XCTFail("This is an intentional failure to demonstrate failure screenshots")

        // 失败时会在 tearDown 中自动捕获截图
    }

    /// 示例 4: 多步骤流程测试
    func testMultiStepFlow() throws {
        // 步骤 1: 启动应用
        captureStepScreenshot(stepName: "01_app_launched")
        XCTAssertTrue(mainPage.verifyPageLoaded())

        // 步骤 2: 导航到 Web 访问
        captureStepScreenshot(stepName: "02_navigating_to_web_access")
        navigateToWebAccess()

        // 步骤 3: 输入 URL
        captureStepScreenshot(stepName: "03_entering_url")
        webAccessPage.enterURL("http://localhost:8080/navigation_test.html")

        // 步骤 4: 等待页面加载
        Thread.sleep(forTimeInterval: 2.0)
        captureStepScreenshot(stepName: "04_page_loaded")

        // 步骤 5: 测试导航控制
        captureStepScreenshot(stepName: "05_testing_navigation")

        // 验证页面加载成功
        XCTAssertTrue(webAccessPage.verifyPageLoaded())
    }
}

// MARK: - 测试完成后的截图报告生成

extension ScreenshotExampleTests {

    public override func tearDown() {
        super.tearDown()

        // 每次测试完成后，生成截图报告
        TestScreenshotHelper.generateScreenshotReport()
    }
}
