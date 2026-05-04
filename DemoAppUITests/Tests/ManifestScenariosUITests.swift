
import XCTest
import os.log

/// 自动化回归测试：覆盖 8080 端口的所有 Manifest 典型场景
/// 包括：持久化/懒加载、有/无 AppID、最简配置、版本更新、缺失图标、复杂资源等
final class ManifestScenariosUITests: XCTestCase {

    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["IS_UI_TEST"] = "YES"
        app.launch()
        
        // 确保从干净状态开始
        clearAllCache()
    }

    private func clearAllCache() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        
        let cacheTab = tabBar.buttons["缓存管理"]
        cacheTab.tap()
        
        let clearAllButton = app.navigationBars.buttons["全部清除"]
        if clearAllButton.waitForExistence(timeout: 5) {
            clearAllButton.tap()
            let confirmButton = app.alerts.buttons["确定"]
            if confirmButton.waitForExistence(timeout: 2) {
                confirmButton.tap()
            }
            // 等待清理完成
            Thread.sleep(forTimeInterval: 1.0)
        }
    }

    func testAllManifestScenarios() throws {
        let tabBar = app.tabBars.firstMatch
        let testCaseTab = tabBar.buttons["测试用例"]
        testCaseTab.tap()
        
        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 10))
        
        let casesCount = table.cells.count
        XCTAssertGreaterThanOrEqual(casesCount, 8, "应该至少有 8 个测试用例")
        
        for i in 0..<casesCount {
            let cell = table.cells.element(boundBy: i)
            let cellLabel = cell.staticTexts.firstMatch.label
            
            XCTContext.runActivity(named: "运行测试用例: \(cellLabel)") { _ in
                let runButton = cell.buttons["运行"]
                runButton.tap()
                
                // 1. 等待 Native 加载信号 (由 ViewController 发出)
                let nativeSignal = "SIGNAL[\(i)]: 测试页面已加载"
                let debugLabel = app.staticTexts["DebugLabel"]
                XCTAssertTrue(debugLabel.waitForExistence(timeout: 10), "DebugLabel 未出现")
                
                let nativePredicate = NSPredicate(format: "label CONTAINS %@", nativeSignal)
                let nativeElement = app.staticTexts.matching(nativePredicate).firstMatch
                XCTAssertTrue(nativeElement.waitForExistence(timeout: 30), "未检测到 Native 信号: \(nativeSignal)")
                
                // 2. 等待 JS 成功信号 (由 WebView 内的 JS 发出)
                let jsSignal = "JS_LOADED_SIGNAL[\(i)]"
                let jsPredicate = NSPredicate(format: "label CONTAINS %@", jsSignal)
                let jsElement = app.staticTexts.matching(jsPredicate).firstMatch
                XCTAssertTrue(jsElement.waitForExistence(timeout: 20), "未检测到 JS 信号: \(jsSignal)")
                
                // 3. 返回列表准备下一个测试
                if app.navigationBars.buttons.element(boundBy: 0).exists {
                    app.navigationBars.buttons.element(boundBy: 0).tap()
                }
            }
        }
        
        // 最后验证缓存管理页面是否有 8 个条目 (根据 AppID 聚合后可能会少一点，但至少会有数据)
        tabBar.buttons["缓存管理"].tap()
        let cacheTable = app.tables.firstMatch
        XCTAssertTrue(cacheTable.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(cacheTable.cells.count, 0, "缓存管理页面应该有数据")
    }
}
