import XCTest

/// HEAD(build 80) 复现：注册应用 → 沉浸式收藏应用页 → 收藏夹点开。
/// 用户真机闪退路径（80 已含 9-19 三修复，怀疑在注册应用收藏重开链路）。
final class FavoriteAppReopenCrashTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFavoriteRegisteredAppThenReopenFromFavoritesList() throws {
        let app = XCUIApplication()
        FavoriteTestFixtures.launch(app: app)

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons["不允许粘贴"]
        if deny.waitForExistence(timeout: 3) {
            deny.tap()
        }

        returnToMainFrame(app)

        // 首页 → 我的应用 → 离线示例（推送激活后已注册）
        let homeTab = app.tabBars.buttons["首页"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 15), "首页 tab 不存在")
        homeTab.tap()

        let demoTile = app.staticTexts["Drel Offline Demo"].firstMatch
        var tileReady = demoTile.waitForExistence(timeout: 8)
        var swipes = 0
        while !tileReady && swipes < 3 {
            app.swipeUp()
            tileReady = demoTile.waitForExistence(timeout: 3)
            swipes += 1
        }
        XCTAssertTrue(tileReady, "首页我的应用里没有 Drel Offline Demo（激活失败？）")
        captureScreenshot(named: "40-home-grid")
        demoTile.tap()

        // 应用详情面板 → 打开应用
        let openAction = app.buttons["打开应用"].firstMatch
        if !openAction.exists {
            _ = app.sheets.buttons["打开应用"].firstMatch.waitForExistence(timeout: 3)
        }
        let openTarget = openAction.exists ? openAction : app.sheets.buttons["打开应用"].firstMatch
        XCTAssertTrue(openTarget.waitForExistence(timeout: 5), "应用详情面板没有打开应用")
        openTarget.tap()
        sleep(2)
        captureScreenshot(named: "41a-after-open-tap")

        // 沉浸式打开（loader）→ 菜单收藏
        let menuButton = app.buttons["browserManager.immersiveMenuButton"]
        let menuVisible = menuButton.waitForExistence(timeout: 15)
        if !menuVisible {
            captureScreenshot(named: "41-no-immersive")
        }
        XCTAssertTrue(menuVisible, "沉浸式页面没有出现")
        sleep(2)
        captureScreenshot(named: "41-immersive-open")

        // 左缘胶囊（UIControl 未暴露 a11y，按坐标点）：收起态 sliver 中心 ≈ (0.036, 0.19)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.036, dy: 0.19)).tap()
        sleep(1)
        captureScreenshot(named: "41c-capsule-expanded")
        // 展开态三格 [返回0-44|刷新48-92|收藏96-140]，收藏中心 x=130pt/402 ≈ 0.323
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.323, dy: 0.19)).tap()
        sleep(2)
        captureScreenshot(named: "42-after-capsule-favorite")
        XCTAssertEqual(app.state, .runningForeground, "收藏动作后 App 不在前台")

        // 重启绕过沉浸式退出：收藏已持久化
        app.terminate()
        sleep(1)
        app.launch()
        if springboard.buttons["不允许粘贴"].waitForExistence(timeout: 2) {
            springboard.buttons["不允许粘贴"].tap()
        }
        returnToMainFrame(app)

        // 设置 → 收藏夹 → 点开离线示例收藏
        let settingsTab = app.tabBars.buttons["设置"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 15), "设置 tab 不存在")
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

        // 收藏夹里找离线示例条目（标题可能是「离线示例」或域名 drel.app）
        let demoRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "离线示例", "drel.app")
        ).firstMatch
        var rowFound = demoRow.waitForExistence(timeout: 8)
        var rowSwipes = 0
        while !rowFound && rowSwipes < 3 {
            app.swipeUp()
            rowFound = demoRow.waitForExistence(timeout: 3)
            rowSwipes += 1
        }
        XCTAssertTrue(rowFound, "收藏夹里没有离线示例条目")
        captureScreenshot(named: "43-favorites-with-app")
        demoRow.tap()

        // 关键观察点：注册应用收藏重开（沉浸式 loader）是否闪退
        sleep(5)
        captureScreenshot(named: "44-reopened-app")
        XCTAssertEqual(app.state, .runningForeground, "从收藏夹打开注册应用后 App 不在前台（闪退复现）")
    }

    /// 回主框架：会话恢复的网页壳或 push 的原生页都逐层退掉，直到 tab 栏出现
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
