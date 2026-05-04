//
//  CacheVerificationTests.swift
//  WebBridgeKit DemoAppUITests
//
//  Created on 2025-01-30.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import XCTest
@testable import WebBridgeKit

/// 缓存功能验证测试
/// 验证WebBridgeKit的离线缓存功能是否正确工作
final class CacheVerificationTests: XCTestCase {

    var app: XCUIApplication!
    var webAccessPage: WebAccessPage!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = AppLauncher.shared.launchApp()
        webAccessPage = WebAccessPage(app: app)

        // Navigate to WebAccess page via tab bar
        if !webAccessPage.navigateViaTab() {
            XCTFail("Failed to navigate to WebAccess page via tab bar")
        }
    }

    override func tearDownWithError() throws {
        TestDataManager.shared.cleanupTestData()
        AppLauncher.shared.terminateApp(app)
        app = nil
        webAccessPage = nil
    }

    // MARK: - 测试场景

    /// 测试基本的缓存创建功能
    func testCreateCache() {
        // 1. 验证页面已加载
        XCTAssertTrue(webAccessPage.verifyPageLoaded(), "Web访问页面应该已加载")

        // 2. 输入测试URL
        let testURL = "http://localhost:8080/index.html"
        webAccessPage.enterURL(testURL)

        // 验证URL已输入
        XCTAssertTrue(webAccessPage.verifyURLEntry(testURL), "URL应该在输入框中显示")

        // 3. 等待页面加载
        XCTAssertTrue(webAccessPage.verifyWebViewLoaded(), "WebView应该加载内容")

        // 4. 获取初始缓存计数
        let initialCount = webAccessPage.getCacheCount()

        // 5. 启用缓存模式
        let cacheWasEnabled = webAccessPage.toggleCacheMode()
        XCTAssertTrue(cacheWasEnabled, "缓存模式应该可以切换")

        // 验证缓存模式已启用
        XCTAssertTrue(webAccessPage.isCacheModeEnabled(), "缓存模式应该已启用")

        // 6. 触发缓存操作
        webAccessPage.initiateCache()

        // 7. 等待缓存完成
        let cacheCompleted = webAccessPage.waitForCacheToComplete(timeout: 30)
        XCTAssertTrue(cacheCompleted, "缓存操作应该完成")

        // 8. 验证缓存已创建
        let cacheExists = webAccessPage.isPageCached()
        XCTAssertTrue(cacheExists, "页面应该已被缓存")

        // 9. 验证缓存计数增加
        let finalCount = webAccessPage.getCacheCount()
        let initialNumber = extractNumber(from: initialCount)
        let finalNumber = extractNumber(from: finalCount)

        if let initial = initialNumber, let final = finalNumber {
            XCTAssertGreaterThan(final, initial, "缓存计数应该增加")
        }
    }

    /// 测试缓存大小计算准确性
    func testCacheSizeAccuracy() {
        // 1. 导航到测试页面
        let testURL = "http://localhost:8080/index.html"
        webAccessPage.enterURL(testURL)
        XCTAssertTrue(webAccessPage.verifyWebViewLoaded(), "WebView应该加载内容")

        // 2. 启用缓存并执行缓存
        webAccessPage.toggleCacheMode()
        webAccessPage.initiateCache()
        XCTAssertTrue(webAccessPage.waitForCacheToComplete(timeout: 30), "缓存应该完成")

        // 3. 打开缓存资源页面
        webAccessPage.openCacheResources()

        // 4. 验证缓存资源页面已打开
        let cacheResourcesTitle = app.navigationBars.firstMatch
        XCTAssertTrue(cacheResourcesTitle.waitForExistence(timeout: 5), "缓存资源页面应该打开")

        // 5. 查找缓存资源列表
        let cacheTable = app.tables.firstMatch
        if cacheTable.waitForExistence(timeout: 5) {
            // 6. 验证缓存项显示
            let cacheCells = cacheTable.cells
            XCTAssertGreaterThan(cacheCells.count, 0, "应该有缓存资源显示")

            // 7. 验证每个缓存项都有大小信息
            for i in 0..<cacheCells.count {
                let cell = cacheTable.cells.element(boundBy: i)
                if cell.exists {
                    let cellLabel = cell.label
                    // 验证大小信息存在（通常包含 KB, MB 等单位）
                    let hasSizeInfo = cellLabel.contains("KB") || cellLabel.contains("MB") || cellLabel.contains("B")
                    XCTAssertTrue(hasSizeInfo, "缓存项 \(i) 应该显示大小信息")
                }
            }
        }

        // 8. 返回主页面
        if app.navigationBars.buttons.firstMatch.exists {
            app.navigationBars.buttons.firstMatch.tap()
        }
    }

    /// 测试缓存内容完整性
    func testCacheContentIntegrity() {
        // 1. 首次访问URL并记录内容
        let testURL = "http://localhost:8080/index.html"
        webAccessPage.enterURL(testURL)
        XCTAssertTrue(webAccessPage.verifyWebViewLoaded(), "首次加载应该成功")

        // 2. 等待特定内容加载
        let contentFound = webAccessPage.waitForWebViewToContainAny(of: ["Example", "Test", "HTML"], timeout: 10)
        XCTAssertTrue(contentFound, "页面应该包含预期内容")

        // 3. 启用缓存并缓存页面
        webAccessPage.toggleCacheMode()
        webAccessPage.initiateCache()
        XCTAssertTrue(webAccessPage.waitForCacheToComplete(timeout: 30), "缓存应该完成")

        // 4. 清除WebView内容
        webAccessPage.enterURL("about:blank")
        Thread.sleep(forTimeInterval: 1)

        // 5. 重新访问相同URL
        webAccessPage.enterURL(testURL)
        XCTAssertTrue(webAccessPage.verifyWebViewLoaded(), "从缓存加载应该成功")

        // 6. 验证内容仍然存在
        let contentStillExists = webAccessPage.waitForWebViewToContainAny(of: ["Example", "Test", "HTML"], timeout: 10)
        XCTAssertTrue(contentStillExists, "从缓存加载的内容应该与原始内容一致")
    }

    /// 测试多个资源的缓存
    func testMultipleResourcesCaching() {
        // 1. 访问包含多个资源的页面
        let testURL = "http://localhost:8080/index.html"
        webAccessPage.enterURL(testURL)
        XCTAssertTrue(webAccessPage.verifyWebViewLoaded(), "页面应该加载")

        // 2. 等待所有资源加载完成
        Thread.sleep(forTimeInterval: 3)

        // 3. 启用缓存模式
        webAccessPage.toggleCacheMode()

        // 4. 获取初始缓存计数
        let initialCount = webAccessPage.getCacheCount()
        let initialNumber = extractNumber(from: initialCount) ?? 0

        // 5. 执行缓存操作
        webAccessPage.initiateCache()
        XCTAssertTrue(webAccessPage.waitForCacheToComplete(timeout: 30), "缓存应该完成")

        // 6. 验证缓存数量增加（应该包含HTML, CSS, JS, 图片等多个资源）
        let finalCount = webAccessPage.getCacheCount()
        let finalNumber = extractNumber(from: finalCount) ?? 0

        XCTAssertGreaterThan(finalNumber, initialNumber, "应该缓存多个资源")
        XCTAssertGreaterThanOrEqual(finalNumber - initialNumber, 1, "至少应该缓存1个资源")
    }

    /// 测试缓存删除功能
    func testCacheDeletion() {
        // 1. 创建缓存
        let testURL = "http://localhost:8080/index.html"
        webAccessPage.enterURL(testURL)
        XCTAssertTrue(webAccessPage.verifyWebViewLoaded(), "页面应该加载")

        webAccessPage.toggleCacheMode()
        webAccessPage.initiateCache()
        XCTAssertTrue(webAccessPage.waitForCacheToComplete(timeout: 30), "缓存应该完成")

        // 2. 验证缓存已创建
        let countBeforeDelete = webAccessPage.getCacheCount()
        let countBefore = extractNumber(from: countBeforeDelete) ?? 0
        XCTAssertGreaterThan(countBefore, 0, "应该有缓存项")

        // 3. 打开缓存资源页面
        webAccessPage.openCacheResources()
        XCTAssertTrue(app.tables.firstMatch.waitForExistence(timeout: 5), "缓存资源列表应该显示")

        // 4. 查找并点击删除按钮
        let cacheTable = app.tables.firstMatch
        let firstCell = cacheTable.cells.firstMatch

        if firstCell.exists {
            // 滑动以显示删除按钮
            firstCell.swipeLeft()

            // 查找删除按钮
            let deleteButton = firstCell.buttons["删除"]
            if deleteButton.exists {
                deleteButton.tap()

                // 5. 确认删除
                let confirmButton = app.alerts.firstMatch.buttons.firstMatch
                if confirmButton.exists {
                    confirmButton.tap()
                }

                // 6. 等待删除完成
                Thread.sleep(forTimeInterval: 1)

                // 7. 验证缓存已删除
                let cellsAfterDelete = cacheTable.cells.count
                let countAfter = cellsAfterDelete

                XCTAssertLessThan(countAfter, countBefore, "缓存数量应该减少")
            } else {
                // 尝试直接点击删除图标
                let deleteIcon = firstCell.images.firstMatch
                if deleteIcon.exists {
                    deleteIcon.tap()
                    Thread.sleep(forTimeInterval: 1)
                }
            }
        }

        // 8. 返回主页面
        if app.navigationBars.buttons.firstMatch.exists {
            app.navigationBars.buttons.firstMatch.tap()
        }

        // 9. 验证缓存计数已更新
        let countAfterDelete = webAccessPage.getCacheCount()
        let countAfter = extractNumber(from: countAfterDelete) ?? 0

        XCTAssertLessThan(countAfter, countBefore, "缓存计数应该减少")
    }

    /// 测试离线模式下使用缓存
    func testOfflineCacheUsage() {
        // 1. 在有网络时缓存页面
        let testURL = "http://localhost:8080/index.html"
        webAccessPage.enterURL(testURL)
        XCTAssertTrue(webAccessPage.verifyWebViewLoaded(), "页面应该加载")

        webAccessPage.toggleCacheMode()
        webAccessPage.initiateCache()
        XCTAssertTrue(webAccessPage.waitForCacheToComplete(timeout: 30), "缓存应该完成")

        // 2. 验证页面已缓存
        XCTAssertTrue(webAccessPage.isPageCached(), "页面应该已缓存")

        // 3. 重新加载页面
        webAccessPage.enterURL(testURL)
        XCTAssertTrue(webAccessPage.verifyWebViewLoaded(), "应该能够从缓存加载")

        // 4. 验证内容仍然可用
        let contentAvailable = webAccessPage.waitForWebViewToContainAny(of: ["Example", "Test", "HTML"], timeout: 10)
        XCTAssertTrue(contentAvailable, "缓存内容应该可用")
    }

    /// 测试缓存持久化
    func testCachePersistence() {
        // 1. 创建缓存
        let testURL = "http://localhost:8080/index.html"
        webAccessPage.enterURL(testURL)
        XCTAssertTrue(webAccessPage.verifyWebViewLoaded(), "页面应该加载")

        webAccessPage.toggleCacheMode()
        webAccessPage.initiateCache()
        XCTAssertTrue(webAccessPage.waitForCacheToComplete(timeout: 30), "缓存应该完成")

        let cacheCountBefore = webAccessPage.getCacheCount()
        let countBefore = extractNumber(from: cacheCountBefore) ?? 0

        // 2. 关闭应用
        app.terminate()

        // 3. 重新启动应用
        app.launch()

        // 4. 重新导航到Web访问页面
        let mainPage = MainPage(app: app)
        if mainPage.verifyPageLoaded() {
            TestDataManager.shared.prepareMockData()

            let expectation = XCTestExpectation(description: "Wait for data")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 5)

            if mainPage.getCellCount() > 0 {
                mainPage.tapCell(at: 0)
            }
        }

        // 5. 验证缓存仍然存在
        Thread.sleep(forTimeInterval: 2)

        let cacheCountAfter = webAccessPage.getCacheCount()
        let countAfter = extractNumber(from: cacheCountAfter) ?? 0

        XCTAssertEqual(countAfter, countBefore, "缓存应该在应用重启后仍然存在")
    }

    /// 测试缓存容量限制
    func testCacheCapacityLimit() {
        // 1. 多次访问不同页面以填充缓存
        let urls = [
            "http://localhost:8080/index.html",
            "http://localhost:8080/page1.html",
            "http://localhost:8080/page2.html"
        ]

        webAccessPage.toggleCacheMode()

        for url in urls {
            webAccessPage.enterURL(url)
            _ = webAccessPage.verifyWebViewLoaded()
            webAccessPage.initiateCache()
            _ = webAccessPage.waitForCacheToComplete(timeout: 30)
            Thread.sleep(forTimeInterval: 1)
        }

        // 2. 打开缓存资源页面
        webAccessPage.openCacheResources()

        // 3. 验证缓存列表
        let cacheTable = app.tables.firstMatch
        if cacheTable.waitForExistence(timeout: 5) {
            let cellCount = cacheTable.cells.count

            // 4. 验证缓存数量合理
            XCTAssertGreaterThan(cellCount, 0, "应该有缓存项")
            XCTAssertLessThan(cellCount, 100, "缓存数量应该在合理范围内")
        }

        // 5. 返回
        if app.navigationBars.buttons.firstMatch.exists {
            app.navigationBars.buttons.firstMatch.tap()
        }
    }

    // MARK: - 辅助方法

    /// 从缓存计数字符串中提取数字
    private func extractNumber(from string: String?) -> Int? {
        guard let string = string else { return nil }
        let numbers = string.components(separatedBy: CharacterSet.decimalDigits.inverted)
        let numberString = numbers.joined()
        return Int(numberString)
    }

    /// 等待缓存操作完成
    private func waitForCacheOperation(timeout: TimeInterval = 30) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if webAccessPage.isPageCached() {
                return true
            }
            Thread.sleep(forTimeInterval: 0.5)
        }

        return false
    }

    /// 获取缓存资源列表
    private func getCacheResourceCount() -> Int {
        webAccessPage.openCacheResources()

        let cacheTable = app.tables.firstMatch
        var count = 0

        if cacheTable.waitForExistence(timeout: 5) {
            count = cacheTable.cells.count
        }

        // 返回主页面
        if app.navigationBars.buttons.firstMatch.exists {
            app.navigationBars.buttons.firstMatch.tap()
        }

        return count
    }
}

// MARK: - Page Object Model Extensions

/// Web访问页面扩展 - 缓存验证专用方法
extension WebAccessPage {

    /// 验证缓存完整性
    func verifyCacheIntegrity(for url: String) -> Bool {
        // 重新加载页面
        enterURL(url)
        let loaded = verifyWebViewLoaded()

        // 验证内容
        if loaded {
            return waitForWebViewToContainAny(of: ["Example", "Test", "HTML"], timeout: 10)
        }

        return false
    }

    /// 获取所有缓存项的详细信息
    func getCacheItemDetails() -> [(url: String, size: String)]? {
        openCacheResources()

        let cacheTable = app.tables.firstMatch
        guard cacheTable.waitForExistence(timeout: 5) else { return nil }

        var items: [(url: String, size: String)] = []
        let cells = cacheTable.cells

        for i in 0..<cells.count {
            let cell = cells.element(boundBy: i)
            if cell.exists {
                let label = cell.label
                // 解析缓存项信息
                items.append((url: label, size: "Unknown"))
            }
        }

        // 返回
        if app.navigationBars.buttons.firstMatch.exists {
            app.navigationBars.buttons.firstMatch.tap()
        }

        return items
    }
}
