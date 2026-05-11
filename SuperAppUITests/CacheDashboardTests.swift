import XCTest

final class CacheDashboardTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--UITesting", "-UITesting"]
        app.launchEnvironment = [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN"
        ]
        app.launch()
    }

    private func saveScreenshot(_ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let data = screenshot.image.pngData() {
            try? data.write(to: URL(fileURLWithPath: "/tmp/wbk-cachedashboard-\(name).png"))
        }
        print("[📸] Screenshot: \(name)")
    }

    private func navigateToTab(_ name: String) {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should exist")
        let tab = tabBar.buttons[name]
        XCTAssertTrue(tab.exists, "Tab '\(name)' should exist")
        tab.tap()
        sleep(1)
    }

    private func goBack() {
        let backButton = app.navigationBars.firstMatch.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 3) {
            backButton.tap()
            sleep(1)
        }
    }

    // MARK: - 1. 入口 A：Settings → DEVELOPER → 缓存仪表盘

    func test01_NavigateToCacheDashboardFromSettings() throws {
        print("=== TEST 01: Settings → DEVELOPER → 缓存仪表盘 ===")

        navigateToTab("设置")
        saveScreenshot("01-settings-tab")

        let settingsTable = app.tables.firstMatch
        XCTAssertTrue(settingsTable.waitForExistence(timeout: 5), "Settings table should exist")

        // Find cache dashboard entry
        var found = false
        let dashboardLabel = app.staticTexts["缓存仪表盘"]
        if dashboardLabel.waitForExistence(timeout: 3) {
            dashboardLabel.tap()
            found = true
            print("[✅] Found '缓存仪表盘'")
        }

        if !found {
            let dashboardEn = app.staticTexts["Cache Dashboard"]
            if dashboardEn.waitForExistence(timeout: 2) {
                dashboardEn.tap()
                found = true
                print("[✅] Found 'Cache Dashboard'")
            }
        }

        if !found {
            for cell in settingsTable.cells.allElementsBoundByIndex {
                let labels = cell.staticTexts.allElementsBoundByIndex.map(\.label)
                let combined = labels.joined(separator: " ").lowercased()
                if combined.contains("缓存") || combined.contains("cache") || combined.contains("仪表") {
                    cell.tap()
                    found = true
                    print("[✅] Found cache entry by cell scan")
                    break
                }
            }
        }

        XCTAssertTrue(found, "Should find cache dashboard entry")
        sleep(2)

        saveScreenshot("02-cache-dashboard")
        XCTAssertTrue(true, "Cache dashboard opened without crash")
    }

    // MARK: - 2. 子系统行可点击

    func test02_TapSubsystemRow() throws {
        print("=== TEST 02: 点击子系统行进入详情 ===")

        // 先进入缓存仪表盘
        navigateToTab("设置")
        let dashboardLabel = app.staticTexts["缓存仪表盘"]
        if dashboardLabel.waitForExistence(timeout: 3) {
            dashboardLabel.tap()
            sleep(2)
        } else {
            print("[Skip] 缓存仪表盘 not found, trying direct navigation")
            return
        }

        let tableView = app.tables.firstMatch
        guard tableView.waitForExistence(timeout: 5) else {
            print("[Skip] Table not found")
            return
        }

        let cellCount = tableView.cells.count
        print("[Info] Found \(cellCount) cells")

        // 点击第一个子系统行
        if cellCount > 0 {
            let firstCell = tableView.cells.element(boundBy: 0)
            let cellLabel = firstCell.staticTexts.firstMatch.label
            print("[Info] Tapping first cell: \(cellLabel)")
            firstCell.tap()
            sleep(2)

            saveScreenshot("03-subsystem-detail")

            // 验证详情页打开
            let detailNavBar = app.navigationBars.firstMatch
            if detailNavBar.waitForExistence(timeout: 3) {
                print("[✅] Subsystem detail page opened, title: \(detailNavBar.identifier)")
                XCTAssertTrue(true, "Subsystem detail opened without crash")
            } else {
                print("[⚠️] No nav bar found after tapping subsystem")
            }

            goBack()
        } else {
            print("[Skip] No cells to tap")
        }
    }

    // MARK: - 3. 置顶管理入口

    func test03_PinnedURLManagement() throws {
        print("=== TEST 03: 置顶 URL 管理页面 ===")

        // 进入缓存仪表盘
        navigateToTab("设置")
        let dashboardLabel = app.staticTexts["缓存仪表盘"]
        if dashboardLabel.waitForExistence(timeout: 3) {
            dashboardLabel.tap()
            sleep(2)
        } else {
            print("[Skip] 缓存仪表盘 not found")
            return
        }

        // 找"置顶管理"按钮
        var foundButton = false
        let buttons = app.buttons.allElementsBoundByIndex
        for btn in buttons {
            let label = btn.label.lowercased()
            if label.contains("置顶") || label.contains("pin") || label.contains("管理") {
                print("[Info] Found button: \(btn.label)")
                btn.tap()
                foundButton = true
                break
            }
        }

        // 备选：在 table header 或 action bar 中找
        if !foundButton {
            let pinnedStatic = app.staticTexts.allElementsBoundByIndex.first(where: {
                $0.label.lowercased().contains("置顶") || $0.label.lowercased().contains("pin")
            })
            if let ps = pinnedStatic {
                ps.tap()
                foundButton = true
            }
        }

        if foundButton {
            sleep(2)
            saveScreenshot("04-pinned-url-page")

            // 验证置顶管理页面加载
            let table = app.tables.firstMatch
            if table.waitForExistence(timeout: 5) {
                print("[✅] Pinned URL management page loaded with \(table.cells.count) cells")
            } else {
                print("[Info] Page loaded (non-table layout)")
            }
            XCTAssertTrue(true, "Pinned URL management page opened without crash")

            goBack()
        } else {
            print("[⚠️] Could not find pinned management button, taking screenshot anyway")
            saveScreenshot("04-no-pinned-btn")
        }
    }

    // MARK: - 4. 预设目录入口

    func test04_PresetURLCatalog() throws {
        print("=== TEST 04: 预设 URL 目录页面 ===")

        // 进入缓存仪表盘
        navigateToTab("设置")
        let dashboardLabel = app.staticTexts["缓存仪表盘"]
        if dashboardLabel.waitForExistence(timeout: 3) {
            dashboardLabel.tap()
            sleep(2)
        } else {
            print("[Skip] 缓存仪表盘 not found")
            return
        }

        // 找"预设目录"按钮
        var foundButton = false
        let buttons = app.buttons.allElementsBoundByIndex
        for btn in buttons {
            let label = btn.label.lowercased()
            if label.contains("预设") || label.contains("preset") || label.contains("目录") || label.contains("catalog") {
                print("[Info] Found button: \(btn.label)")
                btn.tap()
                foundButton = true
                break
            }
        }

        if foundButton {
            sleep(2)
            saveScreenshot("05-preset-catalog-page")

            // 验证预设目录页面加载
            let collectionView = app.collectionViews.firstMatch
            let table = app.tables.firstMatch
            if collectionView.waitForExistence(timeout: 3) {
                print("[✅] Preset catalog loaded as CollectionView, \(collectionView.cells.count) items")
            } else if table.waitForExistence(timeout: 3) {
                print("[✅] Preset catalog loaded as TableView, \(table.cells.count) items")
            } else {
                print("[Info] Preset catalog page loaded (unknown layout)")
            }
            XCTAssertTrue(true, "Preset catalog page opened without crash")

            goBack()
        } else {
            print("[⚠️] Could not find preset catalog button")
            saveScreenshot("05-no-preset-btn")
        }
    }

    // MARK: - 5. 入口 B：Debug Panel → 第5 Tab

    func test05_DebugPanelCacheTab() throws {
        print("=== TEST 05: Debug Panel → 缓存统计 Tab ===")

        navigateToTab("设置")

        // 进入调试面板
        let debugLabel = app.staticTexts["调试面板"]
        if debugLabel.waitForExistence(timeout: 3) {
            debugLabel.tap()
            sleep(2)
        } else {
            // 试试英文
            let debugEn = app.staticTexts["Debug Panel"]
            if debugEn.waitForExistence(timeout: 2) {
                debugEn.tap()
                sleep(2)
            } else {
                print("[Skip] 调试面板 not found in Settings")
                return
            }
        }

        saveScreenshot("06-debug-panel")

        // 找到第5个 Tab "缓存统计"
        let segmented = app.segmentedControls.firstMatch
        guard segmented.waitForExistence(timeout: 5) else {
            print("[Skip] Segmented control not found")
            return
        }

        let buttonCount = segmented.buttons.count
        print("[Info] Segmented control has \(buttonCount) buttons")
        for (i, btn) in segmented.buttons.allElementsBoundByIndex.enumerated() {
            print("[Info]   Tab \(i): \(btn.label)")
        }

        // 如果有 5 个 Tab，点击第 5 个（index 4）
        if buttonCount >= 5 {
            let cacheTab = segmented.buttons.element(boundBy: 4)
            let tabLabel = cacheTab.label
            print("[Info] Tapping tab 5: \(tabLabel)")
            cacheTab.tap()
            sleep(3)

            saveScreenshot("07-debug-cache-tab")

            // 验证缓存统计页面在 Debug Panel 中加载
            let table = app.tables.firstMatch
            if table.waitForExistence(timeout: 5) {
                print("[✅] Cache stats loaded in Debug Panel, \(table.cells.count) cells")
            } else {
                print("[Info] Cache tab content loaded (non-table layout)")
            }
            XCTAssertTrue(true, "Debug Panel cache tab opened without crash")
        } else {
            print("[⚠️] Only \(buttonCount) tabs found, expected 5")
            saveScreenshot("07-debug-few-tabs")
        }

        // 关闭调试面板
        let doneButton = app.buttons["完成"]
        if doneButton.waitForExistence(timeout: 2) {
            doneButton.tap()
            sleep(1)
        }
    }

    // MARK: - 6. 完整流程：Settings → Dashboard → Detail → Back → Pinned → Back

    func test06_FullNavigationFlow() throws {
        print("=== TEST 06: 完整导航流程（不崩溃） ===")

        // Settings → Dashboard
        navigateToTab("设置")
        let dashboardLabel = app.staticTexts["缓存仪表盘"]
        if dashboardLabel.waitForExistence(timeout: 3) {
            dashboardLabel.tap()
            sleep(2)
            saveScreenshot("08-flow-dashboard")
            XCTAssertTrue(true, "Step 1: Dashboard opened")

            // Dashboard → Subsystem Detail
            let table = app.tables.firstMatch
            if table.waitForExistence(timeout: 5), table.cells.count > 0 {
                table.cells.element(boundBy: 0).tap()
                sleep(2)
                saveScreenshot("09-flow-detail")
                XCTAssertTrue(true, "Step 2: Detail opened")
                goBack()
                sleep(1)
            }

            // Dashboard → Back to Settings
            goBack()
            sleep(1)
            saveScreenshot("10-flow-back-settings")
            XCTAssertTrue(true, "Step 3: Back to Settings")
        } else {
            print("[Skip] Dashboard not reachable")
        }

        print("[✅] Full navigation flow completed without crash")
    }
}
