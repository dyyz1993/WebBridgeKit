
import XCTest

final class TestCaseVerificationTests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = true
    }
    
    func testVerifyCases20To30() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-UITesting")
        app.launch()
        
        print("⏳ 等待应用初始化...")
        XCTAssertTrue(app.waitForExistence(timeout: 30), "应用未能启动")
        
        // 1. 确认已进入“用例”页面 (AppDelegate 已经处理了跳转)
        print("⏳ 等待列表加载...")
        let table = app.tables["ManifestTestCasesTableView"]
        
        if !table.waitForExistence(timeout: 30) {
            print("❌ 列表未能在 30s 内加载。尝试点击 TabBar 兜底...")
            let tabBar = app.tabBars.firstMatch
            if tabBar.waitForExistence(timeout: 20) {
                let testTabButton = tabBar.buttons.element(boundBy: 1)
                if testTabButton.waitForExistence(timeout: 10) {
                    testTabButton.tap()
                }
            }
            XCTAssertTrue(table.waitForExistence(timeout: 20), "列表加载失败")
        }
        
        // 3. 循环测试第 20 到 30 个用例
        for index in 19...29 {
            XCTContext.runActivity(named: "测试用例 #\(index + 1)") { activity in
                // 尝试通过 index 获取 Cell，这种方式最稳健
                let cell = table.cells.element(boundBy: index)
                
                // 滚动到该 cell (使用更好的滚动策略)
                var scrollCount = 0
                while !cell.isHittable && scrollCount < 10 {
                    app.swipeUp()
                    scrollCount += 1
                }
                
                // 如果还不可见，尝试直接查找内部文本
                let cellName = cell.staticTexts.firstMatch.exists ? cell.staticTexts.firstMatch.label : "Unknown Case \(index + 1)"
                print("▶️ 正在运行: \(cellName)")
                
                // 找到运行按钮并点击 (使用与 testVerifyNewCases32And33 相同的稳健逻辑)
                let runButton = cell.buttons["testCaseCell.runButton"].firstMatch
                if runButton.exists {
                    runButton.tap()
                } else {
                    let runText = cell.staticTexts.element(matching: NSPredicate(format: "label CONTAINS '运行'")).firstMatch
                    if runText.exists {
                        runText.tap()
                    } else {
                        let coordinate = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
                        coordinate.tap()
                    }
                }
                
                // 4. 等待加载并截图
                Thread.sleep(forTimeInterval: 5.0)
                
                let screenshot = app.screenshot()
                let attachment = XCTAttachment(screenshot: screenshot)
                attachment.name = "Case_\(index + 1)_\(cellName.replacingOccurrences(of: " ", with: "_"))"
                attachment.lifetime = .keepAlways
                activity.add(attachment)
                
                // 6. 返回列表页
                let backButton = app.navigationBars.buttons.element(boundBy: 0)
                if backButton.exists {
                    backButton.tap()
                } else {
                    let closeButton = app.buttons["关闭"]
                    if closeButton.exists {
                        closeButton.tap()
                    } else {
                        app.buttons.matching(identifier: "close").firstMatch.tap()
                    }
                }
                
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
    }
    
    /// 验证应用是否能正常启动并进入首页
    func testAppLaunchStability() {
        let app = XCUIApplication()
        app.launchArguments.append("-UITesting")
        app.launchArguments.append("-NoAutoTab")
        app.launch()
        
        print("⏳ 等待主界面内容加载...")
        
        // 1. 等待首页内容 (CollectionView 或 EmptyStateView)
        // 使用一个组合的 Predicate 来等待其中之一出现
        let collectionView = app.collectionViews["MainCollectionView"]
        let emptyState = app.otherElements["EmptyStateView"]
        
        print("⏳ 正在等待 MainCollectionView 或 EmptyStateView...")
        
        let exists = NSPredicate(format: "exists == true")
        
        // 轮询检查，直到其中一个出现或超时
        let startTime = Date()
        var found = false
        while Date().timeIntervalSince(startTime) < 40 {
            if collectionView.exists || emptyState.exists {
                found = true
                break
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        if !found {
            print("❌ UI 测试超时：未能加载主界面内容")
            print("🔍 当前界面层级: \n\(app.debugDescription)")
            XCTFail("❌ 应用启动后未能进入首页或加载内容")
        } else {
            if collectionView.exists {
                print("✅ 首页 CollectionView 已加载")
                // 验证是否包含内容
                let cell = collectionView.cells.firstMatch
                if cell.waitForExistence(timeout: 10) {
                    print("✅ CollectionView 包含 Cell 内容")
                }
            } else if emptyState.exists {
                print("✅ 首页空状态已加载")
            }
        }
    }

    func testVerifyNewCases32And33() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-UITesting")
        app.launch()
        
        print("⏳ 等待应用初始化...")
        XCTAssertTrue(app.waitForExistence(timeout: 30), "应用未能启动")
        
        // 1. 确认已进入“用例”页面 (AppDelegate 已经处理了跳转)
        print("⏳ 等待列表加载...")
        // 尝试多种方式查找表格
        let table = app.tables["ManifestTestCasesTableView"]
        
        // 增加更长的等待时间，并尝试手动切换 TabBar 如果自动跳转失败
        let listExists = table.waitForExistence(timeout: 30)
        
        if !listExists {
            print("❌ 列表未能在 30s 内加载。尝试点击 TabBar 兜底...")
            let tabBar = app.tabBars.firstMatch
            if tabBar.waitForExistence(timeout: 20) {
                let testTabButton = tabBar.buttons.element(boundBy: 1)
                if testTabButton.waitForExistence(timeout: 10) {
                    testTabButton.tap()
                    print("✅ 已手动点击 TabBar Index 1")
                }
            }
            
            // 再次尝试通过 identifier 查找，如果还不行，用 firstMatch 兜底
            if !table.waitForExistence(timeout: 20) {
                print("⚠️ 通过 identifier 找不到列表，尝试使用 firstMatch 兜底...")
                let fallbackTable = app.tables.firstMatch
                if !fallbackTable.waitForExistence(timeout: 10) {
                    print("❌ 依然找不到表格，捕获当前层级...")
                    print(app.debugDescription)
                }
                XCTAssertTrue(fallbackTable.exists, "列表加载失败")
            }
        }
        
        // 3. 测试目标用例
        let targets = [
            (id: 31, name: "32. User-Agent", index: 31),
            (id: 32, name: "33. 资源加载", index: 32)
        ]
        
        // 尝试向上滑动几次，确保在列表底部附近（用例 32/33 都在最后）
        for _ in 0..<10 {
            app.swipeUp()
        }
        
        for target in targets {
            XCTContext.runActivity(named: "测试用例: \(target.name)") { activity in
                print("🔍 查找用例: \(target.name) (Index: \(target.index))")
                
                // 优先通过索引定位 Cell，这是最可靠的方式
                let cell = table.cells.element(boundBy: target.index)
                
                // 如果不可见，尝试滚动
                var scrollCount = 0
                while !cell.isHittable && scrollCount < 15 {
                    print("⬇️ 未找到 \(target.name)，尝试向上滑动...")
                    app.swipeUp()
                    scrollCount += 1
                }
                
                // 确认 Cell 存在
                XCTAssertTrue(cell.waitForExistence(timeout: 5), "找不到用例: \(target.name) at index \(target.index)")
                
                // 找到运行按钮并点击
                let runButton = cell.buttons["testCaseCell.runButton"].firstMatch
                if !runButton.exists {
                    print("⚠️ 未找到 accessibilityIdentifier 为 testCaseCell.runButton 的按钮，尝试降级逻辑...")
                    let runText = cell.staticTexts.element(matching: NSPredicate(format: "label CONTAINS '运行'")).firstMatch
                    if runText.exists {
                        runText.tap()
                    } else {
                        let coordinate = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
                        coordinate.tap()
                    }
                } else {
                    runButton.tap()
                }
                
                print("✅ 已点击运行: \(target.name)")
                
                // 等待加载并截图
                Thread.sleep(forTimeInterval: 5.0)
                
                let screenshot = app.screenshot()
                let attachment = XCTAttachment(screenshot: screenshot)
                attachment.name = "Verification_\(target.name.replacingOccurrences(of: " ", with: "_"))"
                attachment.lifetime = .keepAlways
                activity.add(attachment)
                
                // 返回列表页
                let backButton = app.navigationBars.buttons.element(boundBy: 0)
                if backButton.waitForExistence(timeout: 5) {
                    backButton.tap()
                } else {
                    // 尝试点击左上角坐标（兜底）
                    let coordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05))
                    coordinate.tap()
                }
                
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
    }
}

extension XCUIElement {
    func scrollToElement() {
        // 如果元素在屏幕上方，向下滚；如果在下方，向上滚
        let window = XCUIApplication().windows.firstMatch
        let elementFrame = self.frame
        let windowFrame = window.frame
        
        if elementFrame.minY < windowFrame.minY {
            // 在上方，向下拖动以显示
            let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            start.press(forDuration: 0.1, thenDragTo: end)
        } else if elementFrame.maxY > windowFrame.maxY {
            // 在下方，向上拖动以显示
            let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
    }
}
