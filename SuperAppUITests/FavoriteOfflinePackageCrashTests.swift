import XCTest

/// 离线包已下载后的收藏夹重开：用户手机下载过强离线包（sim 之前没有），
/// 点击收藏命中 PersistentManifestLoader 缓存 → file:// 加载分支。
/// 前置：Drel Offline Demo 已注册且已收藏（FavoriteAppReopenCrashTests 跑过）。
final class FavoriteOfflinePackageCrashTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testDownloadOfflinePackageThenReopenFavoriteDoesNotCrash() throws {
        let app = XCUIApplication()
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.buttons["不允许粘贴"].waitForExistence(timeout: 3) {
            springboard.buttons["不允许粘贴"].tap()
        }
        returnToMainFrame(app)

        // 首页 → 应用格子 → 详情面板 → 下载离线包
        let homeTab = app.tabBars.buttons["首页"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 15), "首页 tab 不存在")
        homeTab.tap()

        let demoTile = app.staticTexts["Drel Offline Demo"].firstMatch
        XCTAssertTrue(demoTile.waitForExistence(timeout: 8), "首页没有 Drel Offline Demo")
        demoTile.tap()

        // 详情面板：包未下载时是「下载离线包」；已下载过则是「删除离线包」
        // （容器状态保留，测试可重复跑），两者都视为包已就位。
        let download = app.buttons["下载离线包"].firstMatch
        let downloadTarget = download.exists ? download : app.sheets.buttons["下载离线包"].firstMatch
        let remove = app.buttons["删除离线包"].firstMatch
        let removeTarget = remove.exists ? remove : app.sheets.buttons["删除离线包"].firstMatch
        let packageReady = removeTarget.waitForExistence(timeout: 3)
        if packageReady {
            captureScreenshot(named: "50-package-already-installed")
            // 已下载分支没有触发下载动作，面板还开着——点「关闭」收起
            let close = app.buttons["关闭"].firstMatch
            let closeTarget = close.exists ? close : app.sheets.buttons["关闭"].firstMatch
            if closeTarget.waitForExistence(timeout: 3) {
                closeTarget.tap()
                sleep(1)
            }
        } else {
            XCTAssertTrue(downloadTarget.waitForExistence(timeout: 5), "没有下载离线包入口")
            downloadTarget.tap()
            captureScreenshot(named: "50-download-tapped")
            sleep(12)
            captureScreenshot(named: "51-after-download")
        }

        // 收藏夹点开（离线包已就位）
        let settingsTab = app.tabBars.buttons["设置"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 8), "设置 tab 不存在")
        settingsTab.tap()

        let favoritesRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "收藏夹"))
            .firstMatch
        var found = favoritesRow.waitForExistence(timeout: 5)
        var attempts = 0
        while !found && attempts < 5 {
            app.swipeUp()
            found = favoritesRow.waitForExistence(timeout: 3)
            attempts += 1
        }
        XCTAssertTrue(found, "设置页没有收藏夹入口")
        favoritesRow.tap()

        let demoRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "离线示例", "Drel Offline Demo")
        ).firstMatch
        var rowFound = demoRow.waitForExistence(timeout: 8)
        var swipes = 0
        while !rowFound && swipes < 3 {
            app.swipeUp()
            rowFound = demoRow.waitForExistence(timeout: 3)
            swipes += 1
        }
        XCTAssertTrue(rowFound, "收藏夹里没有 Drel Offline Demo 条目")
        demoRow.tap()

        sleep(6)
        captureScreenshot(named: "52-reopen-with-offline-package")
        XCTAssertEqual(app.state, .runningForeground, "离线包就位后从收藏夹打开 App 不在前台（闪退复现）")
    }

    private func returnToMainFrame(_ app: XCUIApplication) {
        var backs = 0
        while !app.tabBars.firstMatch.exists && backs < 8 {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            if back.exists {
                back.tap()
                sleep(1)
            } else if app.buttons["browserManager.closeButton"].waitForExistence(timeout: 1) {
                app.buttons["browserManager.closeButton"].tap()
                sleep(1)
            } else {
                break
            }
            backs += 1
        }
    }

    private func captureScreenshot(named name: String) {
        let shot = XCUIScreen.main.screenshot()
        let url = URL(fileURLWithPath: "/tmp/drel-fav-crash/\(name).png")
        try? shot.pngRepresentation.write(to: url)
    }
}
