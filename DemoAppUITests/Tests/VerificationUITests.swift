
import XCTest

final class VerificationUITests: XCTestCase {
    func testVerifyTestCases() throws {
        let app = XCUIApplication()
        app.launchEnvironment["IS_UI_TEST"] = "YES"
        continueAfterFailure = false
        app.launch()
        
        // Wait for tab bar
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        
        // --- Step 0: Clear Cache to ensure fresh tests ---
        print("🧹 正在清除缓存...")
        let cacheTab = tabBar.buttons["缓存管理"]
        XCTAssertTrue(cacheTab.exists)
        cacheTab.tap()
        
        let clearAllButton = app.navigationBars.buttons["全部清除"]
        if clearAllButton.waitForExistence(timeout: 5) {
            clearAllButton.tap()
            let confirmButton = app.alerts.buttons["确定"]
            if confirmButton.waitForExistence(timeout: 2) {
                confirmButton.tap()
            }
            // Wait for clear to finish (HUD to disappear)
            Thread.sleep(forTimeInterval: 1.0)
        }
        
        // --- Step 1: Go to Test Cases ---
        print("📋 正在进入测试用例页面...")
        let testCaseTab = tabBar.buttons["测试用例"]
        XCTAssertTrue(testCaseTab.exists)
        testCaseTab.tap()
        
        // Wait for the list to load
        let table = app.tables.firstMatch
        if !table.waitForExistence(timeout: 10) {
            print("❌ 未能找到 TableView")
            XCTFail("未能找到 TableView")
        }
        
        // Loop through all 5 cases
        let cells = table.cells
        XCTAssertEqual(cells.count, 5, "应该有 5 个测试用例")
        
        for i in 0..<cells.count {
            let cell = cells.element(boundBy: i)
            XCTAssertTrue(cell.exists)
            
            let cellLabel = cell.label
            print("▶️ 正在运行测试用例 [\(i)]: \(cellLabel)")
            
            // Find the "运行" button in that cell
            let runButton = cell.buttons["运行"]
            XCTAssertTrue(runButton.exists, "单元格 [\(i)] 内应该有 '运行' 按钮")
            runButton.tap()
            
            // 1. 等待 Native 页面加载完成信号
            let nativeSignal = "SIGNAL[\(i)]: 测试页面已加载"
            print("⏳ 正在等待 Native 信号: \(nativeSignal)...")
            
            let debugLabel = app.staticTexts["DebugLabel"]
            XCTAssertTrue(debugLabel.waitForExistence(timeout: 10), "❌ DebugLabel 未能在 10s 内出现")
            
            let nativeSignalPredicate = NSPredicate(format: "label CONTAINS %@", nativeSignal)
            let nativeSignalElement = app.staticTexts.matching(nativeSignalPredicate).firstMatch
            
            XCTAssertTrue(nativeSignalElement.waitForExistence(timeout: 30), "❌ 测试用例 [\(i)] 未能在 30s 内显示 Native 信号: \(nativeSignal)\n当前 DebugLabel 内容: \(debugLabel.label)")
            print("✅ 成功检测到 Native 信号: \(nativeSignalElement.label)")

            // 2. 等待 WebView JS 发回的成功信号 (通过 DebugLabel 中转)
            let jsSignal = "JS_LOADED_SIGNAL[\(i)]"
            print("⏳ 正在等待 WebView JS 信号: \(jsSignal)...")
            
            let jsSignalPredicate = NSPredicate(format: "label CONTAINS %@", jsSignal)
            let jsSignalElement = app.staticTexts.matching(jsSignalPredicate).firstMatch
            
            // JS 信号通常在 Native 信号之后很快出现
            if !jsSignalElement.waitForExistence(timeout: 25) {
                print("❌ ERROR: JS Signal not found in DebugLabel.")
                print("🔍 当前 DebugLabel 内容: \(debugLabel.label)")
                
                // 如果没找到信号，打印所有 staticTexts 以便排查
                print("🔍 当前所有 StaticTexts: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
                
                // 截图并记录层级
                XCTContext.runActivity(named: "Capture Failure Details") { activity in
                    let screenshot = app.screenshot()
                    let attachment = XCTAttachment(screenshot: screenshot)
                    attachment.lifetime = .keepAlways
                    activity.add(attachment)
                    print("📊 [DEBUG] Full Hierarchy:\n\(app.debugDescription)")
                }
                
                XCTFail("❌ 测试用例 [\(i)] WebView JS 未能正确执行 (期望: \(jsSignal))")
            } else {
                print("✅ 成功检测到 WebView JS 信号: \(jsSignalElement.label)")
            }
            
            // 截图记录
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Test_Case_\(i)_Success"
            attachment.lifetime = .keepAlways
            self.add(attachment)
            
            // 3. 返回列表页面
            print("🔙 正在返回列表页面...")
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.exists {
                backButton.tap()
            } else {
                app.swipeDown() 
            }
            
            // 等待列表重新出现
            _ = table.waitForExistence(timeout: 5)
            print("-----------------------------------")
        }
    }
}
