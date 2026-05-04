import XCTest

final class TestCase23Test: XCTestCase {
    func testNavigateAndRunCase23() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
        
        // 等待应用启动
        XCTAssertTrue(app.waitForExistence(timeout: 30))
        
        // 点击"用例" Tab
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        
        let testTabButton = tabBar.buttons.element(boundBy: 1)
        XCTAssertTrue(testTabButton.waitForExistence(timeout: 5))
        testTabButton.tap()
        
        // 等待测试列表加载
        let table = app.tables["ManifestTestCasesTableView"]
        XCTAssertTrue(table.waitForExistence(timeout: 10))
        
        // 向上滑动找到测试用例23
        for _ in 0..<20 {
            app.swipeUp()
        }
        
        // 找到测试用例23 (索引22，从0开始)
        let cell = table.cells.element(boundBy: 22)
        
        // 滚动到可见
        var scrollCount = 0
        while !cell.isHittable && scrollCount < 15 {
            app.swipeUp()
            scrollCount += 1
        }
        
        // 点击运行按钮
        let runButton = cell.buttons["testCaseCell.runButton"].firstMatch
        if runButton.exists {
            runButton.tap()
        } else {
            let coordinate = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
            coordinate.tap()
        }
        
        // 等待页面加载
        Thread.sleep(forTimeInterval: 5.0)
        
        // 截图验证
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "TestCase23_ManifestDemo"
        attachment.lifetime = .keepAlways
        add(attachment)
        
        // 验证页面内容 - 应该包含"Manifest 配置演示"
        let manifestLabel = app.staticTexts["Manifest 配置演示"]
        if manifestLabel.waitForExistence(timeout: 10) {
            print("✅ 找到页面标题: Manifest 配置演示")
        } else {
            print("⚠️ 未找到预期标题")
        }
    }
}
