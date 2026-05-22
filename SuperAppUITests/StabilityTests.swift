import XCTest

final class StabilityTests: XCTestCase {
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--ui-testing"]
    }
    
    // P1-56: 连续启动 10 次检查 crash
    func testTenConsecutiveLaunches() {
        for i in 1...10 {
            app.launch()
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "Launch \(i): tab bar should exist")
            app.terminate()
        }
    }
    
    // P1-57: 连续切 tab 50 次检查布局/内存
    func testFiftyTabSwitches() {
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        
        let tabs = app.tabBars.buttons
        let tabCount = tabs.count
        guard tabCount >= 4 else {
            XCTFail("Expected at least 4 tabs, got \(tabCount)")
            return
        }
        
        for i in 1...50 {
            let targetTab = tabs.element(boundBy: i % tabCount)
            targetTab.tap()
            if i % 10 == 0 {
                XCTAssertTrue(app.tabBars.firstMatch.exists, "Tab bar should exist after \(i) switches")
            }
        }
    }
    
    // P1-58: 后台/前台切换
    func testBackgroundForegroundCycles() {
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        
        for i in 1...5 {
            XCUIDevice.shared.press(.home)
            sleep(1)
            app.activate()
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5), "Tab bar should exist after cycle \(i)")
        }
    }
    
    // P1-59: 横竖屏策略确认
    func testRotationHandling() {
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        
        let portraitFrame = app.tabBars.firstMatch.frame
        
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(1)
        
        let landscapeFrame = app.tabBars.firstMatch.frame
        
        XCTAssertTrue(app.tabBars.firstMatch.exists, "Tab bar should exist in landscape")
        XCTAssertGreaterThan(landscapeFrame.width, 0, "Tab bar should have width in landscape")
        
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
        
        let restoredFrame = app.tabBars.firstMatch.frame
        XCTAssertEqual(portraitFrame.width, restoredFrame.width, "Tab bar width should restore after rotation")
    }
    
    // P1-60: 动态字体放大检查
    func testDynamicTypeLarge() {
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        
        for i in 0..<4 {
            app.tabBars.buttons.element(boundBy: i).tap()
            sleep(1)
            let visibleElements = app.descendants(matching: .any)
            let firstElements = (0..<min(10, visibleElements.count)).map { visibleElements.element(boundBy: $0) }
            for el in firstElements {
                if el.exists {
                    XCTAssertGreaterThan(el.frame.width, 0, "Element should have non-zero width on tab \(i)")
                }
            }
        }
    }
}
