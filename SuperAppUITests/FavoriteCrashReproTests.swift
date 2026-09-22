import XCTest

/// 临时复现：收藏夹点条目闪退（用户真机报告 2026-09-22）。
/// 流程：设置 → 收藏夹 → 逐条进入再返回，断言 App 全程存活。
final class FavoriteCrashReproTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOpenEachFavoriteFromFavoritesListDoesNotCrash() throws {
        let app = XCUIApplication()
        app.launch()

        // 系统粘贴授权弹窗（模拟器 launch 注入剪贴板触发）
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons["不允许粘贴"]
        if deny.waitForExistence(timeout: 3) {
            deny.tap()
        }

        // 会话恢复可能顶出网页壳：先退回主框架
        if app.buttons["browser.moreButton"].waitForExistence(timeout: 3) {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

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

        // 收藏列表行（cell 内域名/标题文本），逐条进入再返回
        let listCells = app.cells
        XCTAssertTrue(listCells.firstMatch.waitForExistence(timeout: 8), "收藏夹列表为空（种子未生效？）")
        _ = app.buttons["browser.moreButton"].waitForExistence(timeout: 2)
        // 收藏夹页若直接因首条自动打开（不应发生），记证据
        captureScreenshot(named: "10-favorites-list")

        let cellCount = min(listCells.count, 9)
        for index in 0..<cellCount {
            let cell = listCells.element(boundBy: index)
            guard cell.exists else { break }
            cell.tap()

            // 进入后等页面稳定：浏览器壳或详情形态都算正常
            _ = app.buttons["browser.moreButton"].waitForExistence(timeout: 6)
            sleep(2)
            XCTAssertEqual(app.state, .runningForeground, "第 \(index) 条收藏点开后 App 不在前台（闪退）")
            captureScreenshot(named: "11-opened-\(index)")

            // 返回收藏夹
            let back = app.navigationBars.buttons.element(boundBy: 0)
            if back.waitForExistence(timeout: 3) {
                back.tap()
            }
            sleep(1)
            XCTAssertEqual(app.state, .runningForeground, "第 \(index) 条返回后 App 不在前台（闪退）")
        }
    }

    private func captureScreenshot(named name: String) {
        let shot = XCUIScreen.main.screenshot()
        let url = URL(fileURLWithPath: "/tmp/drel-fav-crash/\(name).png")
        try? shot.pngRepresentation.write(to: url)
    }
}
