import XCTest

/// 巡游实拍：按产品流程逐屏导航并输出 PNG 到 xcresult attachments，
/// 供 Figma 真机原型区使用。仅用于工具链，不作为回归断言。
/// 经验：按钮 label 常带前导空格（如 "  复制验证码"），必须用 CONTAINS 谓词匹配。
final class ScreenshotTourTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    var app: XCUIApplication!

    private func shoot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        sleep(1)
    }

    private func dump(_ name: String) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = "dump-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 谓词模糊匹配：label CONTAINS，依次尝试 buttons/cells/staticTexts
    @discardableResult
    private func goPred(_ fragment: String, timeout: TimeInterval = 4) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", fragment)
        let candidates: [XCUIElement] = [
            app.buttons.containing(predicate).firstMatch,
            app.cells.containing(predicate).firstMatch,
            app.collectionViews.cells.containing(predicate).firstMatch,
            app.staticTexts.containing(predicate).firstMatch,
            app.otherElements.containing(predicate).firstMatch
        ]
        for candidate in candidates where candidate.waitForExistence(timeout: timeout) {
            candidate.tap()
            return true
        }
        return false
    }

    private func tapOutsideSheet() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        sleep(1)
    }

    private func tab(_ name: String) {
        tapOutsideSheet()
        let button = app.tabBars.buttons[name]
        if button.waitForExistence(timeout: 6) { button.tap() }
        sleep(1)
    }

    private func back() {
        for label in ["返回", "Back"] {
            let btn = app.navigationBars.buttons.containing(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
            if btn.waitForExistence(timeout: 2) { btn.tap(); sleep(1); return }
        }
        app.navigationBars.buttons.element(boundBy: 0).tapIfExists()
        sleep(1)
    }

    func testCaptureTour() throws {
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        sleep(5)

        // ── PWA 模块 ─────────────────────────────
        tab("应用")
        shoot("01-home")

        // 我的应用 → 权限中心（种子应用 Demo Chat）
        if goPred("Demo Chat", timeout: 3) {
            sleep(2)
            if goPred("权限与原生能力", timeout: 3) {
                sleep(2)
                shoot("02-permission-center")
                goPred("关闭", timeout: 2)
            }
            tapOutsideSheet()
            sleep(1)
        }

        app.swipeUp()
        sleep(1)
        if goPred("手册与调试") {
            sleep(2)
            if goPred("推送铃声") {
                sleep(3)
                shoot("04-ringtones")
                back()
            }
        }
        app.swipeUp()
        sleep(1)
        if goPred("手册与调试") {
            sleep(2)
            if goPred("推送加密") {
                sleep(2)
                shoot("05-encryption")
                back()
            }
        }
        tapOutsideSheet()

        goPred("全部 API 示例")
        sleep(3)
        shoot("03-api-catalog")
        back()

        // ── 消息模块 ─────────────────────────────
        tab("通知")
        sleep(2)
        shoot("06-inbox-latest")

        let grouped = app.segmentedControls.buttons["分组"]
        if grouped.waitForExistence(timeout: 3) {
            grouped.tap()
            sleep(2)
            shoot("07-inbox-grouped")
            app.segmentedControls.buttons["最新"].tapIfExists()
            sleep(1)
        }

        if goPred("需处理", timeout: 2) {
            sleep(2)
            if app.cells.firstMatch.waitForExistence(timeout: 3) {
                app.cells.firstMatch.tap()
                sleep(2)
                shoot("08-approval-detail")
                back()
            }
            goPred("全部")
            sleep(1)
        }

        if app.cells.firstMatch.waitForExistence(timeout: 4) {
            app.cells.firstMatch.tap()
            sleep(2)
            shoot("09-message-detail")
            back()
        }

        // 带 URL 的消息 → 打开链接 → 内置浏览器（无系统弹窗）
        if goPred("天气预报", timeout: 2) || goPred("安全告警", timeout: 2) {
            sleep(2)
            shoot("19-url-message-detail")
            if goPred("打开链接") {
                sleep(10)
                shoot("18-browser")
                dump("browser")
                app.navigationBars.buttons.element(boundBy: 0).tapIfExists()
                sleep(1)
            } else {
                back()
            }
        }

        if goPred("快速审阅") {
            sleep(3)
            shoot("10-review")
            back()
        }

        // ── 口令 / 设置 ─────────────────────────
        tab("设置")
        sleep(2)
        shoot("11-settings")

        goPred("口令管理")
        sleep(2)
        shoot("12-token-manage")
        back()

        goPred("服务器配置")
        sleep(3)
        shoot("13-gateway")
        back()
    }

    func testCaptureRemaining() throws {
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        sleep(5)

        // 铃声库 + 推送加密（手册与调试 Sheet）
        tab("应用")
        app.swipeUp(); sleep(1)
        if !goPred("手册与调试") { dump("fail-manual") }
        sleep(2)
        if !goPred("推送铃声") { dump("fail-ringtones") }
        sleep(3)
        shoot("04-ringtones")
        back()
        app.swipeUp(); sleep(1)
        if goPred("手册与调试") {
            sleep(2)
            if !goPred("推送加密") { dump("fail-encryption") }
            sleep(2)
            shoot("05-encryption")
        }

        // 浏览器：搜索定位带 URL 消息 → 打开链接
        tab("通知")
        sleep(2)
        let search = app.textFields.containing(NSPredicate(format: "label CONTAINS '搜索'")).firstMatch
        let fallbackSearch = app.textFields.firstMatch
        let field = search.exists ? search : (fallbackSearch.waitForExistence(timeout: 4) ? fallbackSearch : search)
        if field.waitForExistence(timeout: 4) {
            field.tap()
            sleep(1)
            field.typeText("天气")
            sleep(2)
            let weatherCell = app.cells.containing(NSPredicate(format: "label CONTAINS '天气'")).firstMatch
            if weatherCell.waitForExistence(timeout: 4) {
                weatherCell.tap()
                sleep(2)
                if app.navigationBars.firstMatch.waitForExistence(timeout: 4) {
                    shoot("19-url-message-detail")
                    if !goPred("打开链接") { dump("fail-openlink") }
                    sleep(10)
                    shoot("18-browser")
                } else {
                    dump("fail-nav-after-cell")
                }
            } else {
                dump("fail-search-cells")
            }
        } else {
            dump("fail-searchfield")
        }
    }
}

private extension XCUIElement {
    func tapIfExists() {
        if exists { tap() }
    }
}

/// bridge-hub 卡片相对链接：懒加载 custom:// 基址下主框架导航应还原为 https 加载
final class CustomLinkNavTests: XCTestCase {
    func testHubCardNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        sleep(5)
        XCUIDevice.shared.system.open(URL(string: "webbridgekit://open?url=https%3A%2F%2Fae8fcb.shanbox.19930810.xyz%3A8443%2Ftest_resources%2Fbridge-hub.html")!)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.buttons["打开"]
        if open.waitForExistence(timeout: 10) { sleep(2); open.tap(); if open.exists { open.tap() } }
        sleep(12)
        let att1 = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        att1.name = "hub-loaded"; att1.lifetime = .keepAlways; add(att1)
        let dumpAtt = XCTAttachment(string: "LINKS:\n" + app.links.debugDescription + "\nBUTTONS:\n" + app.buttons.debugDescription + "\nWEBVIEWS:\n" + app.webViews.debugDescription + "\nOTHERS:\n" + app.otherElements.debugDescription)
        dumpAtt.name = "hub-dump"; dumpAtt.lifetime = .keepAlways; add(dumpAtt)
        // 点「权限 UI 测试」卡片（WebView 链接暴露为 links/buttons）
        let openLinks = app.links.matching(NSPredicate(format: "label == '打开'"))
        if openLinks.element(boundBy: 2).waitForExistence(timeout: 6) {
            openLinks.element(boundBy: 2).tap()  // 第 3 张卡 = 权限 UI 测试
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.22)).tap()
        }
        sleep(9)
        let att2 = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        att2.name = "after-card-tap"; att2.lifetime = .keepAlways; add(att2)
        // 第二次访问（缓存命中路径）：返回 hub 再点同一张卡
        let back1 = app.buttons["browserManager.backButton"]
        if back1.exists && back1.isEnabled { back1.tap(); sleep(6) }
        if openLinks.element(boundBy: 2).exists {
            openLinks.element(boundBy: 2).tap()
            sleep(9)
            let att5 = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            att5.name = "second-visit"; att5.lifetime = .keepAlways; add(att5)
        }
        let navDump = XCTAttachment(string: "NAVBAR BUTTONS:\n" + app.navigationBars.buttons.debugDescription)
        navDump.name = "navbar-dump"; navDump.lifetime = .keepAlways; add(navDump)
        // 点返回：应回到测试中心
        let back = app.buttons["browserManager.backButton"]
        if back.waitForExistence(timeout: 4) && back.isEnabled {
            back.tap()
            sleep(8)
            let att4 = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            att4.name = "after-back-tap"; att4.lifetime = .keepAlways; add(att4)
        }
    }
}

/// 权限授权流端到端：点权限项 → 是否弹品牌面板（判定链实证）→ 授权 →
/// 原生网页授权管理验证账本 → 撤销 → 再触发应重弹面板。
final class PermissionFlowTests: XCTestCase {
    private func shoot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        sleep(1)
    }

    func testPermissionChain() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        sleep(5)
        XCUIDevice.shared.system.open(URL(string: "webbridgekit://open?url=https%3A%2F%2Fae8fcb.shanbox.19930810.xyz%3A8443%2Ftest_resources%2Fbridge-hub.html")!)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.buttons["打开"]
        if open.waitForExistence(timeout: 10) { sleep(2); open.tap(); if open.exists { open.tap() } }
        sleep(12)

        // 点「权限 UI 测试」卡（第 3 个打开链接）
        let openLinks = app.links.matching(NSPredicate(format: "label == '打开'"))
        if openLinks.element(boundBy: 2).waitForExistence(timeout: 6) {
            openLinks.element(boundBy: 2).tap()
        }
        sleep(9)
        shoot("perm-page")

        // 点「相机权限」行（WebView 内 div）
        let cameraRow = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '相机'")).firstMatch
        if cameraRow.waitForExistence(timeout: 5) {
            cameraRow.tap()
            sleep(4)
        }
        // 品牌面板是否出现
        let panel = app.otherElements["pwa.permission.prompt"]
        let panelShown = panel.waitForExistence(timeout: 4)
        shoot("after-camera-tap-panel=\(panelShown)")
        let treeAtt = XCTAttachment(string: app.debugDescription)
        treeAtt.name = "perm-tree"; treeAtt.lifetime = .keepAlways; add(treeAtt)

        if panelShown {
            // 选「始终允许」→ 系统弹窗 → 允许 → 刷新
            let always = app.buttons.containing(NSPredicate(format: "label CONTAINS '始终允许'")).firstMatch
            if always.exists { always.tap() }
            sleep(2)
            let sysAllow = springboard.buttons["允许"].exists ? springboard.buttons["允许"] : springboard.buttons["OK"]
            if sysAllow.waitForExistence(timeout: 6) { sysAllow.tap() }
            sleep(4)
            shoot("after-system-grant")
        }

        // 原生网页授权管理页验证账本
        app.buttons["browserManager.closeButton"].tapIfExistsCompat()
        sleep(2)
        let settingsTab = app.tabBars.buttons["设置"]
        if settingsTab.waitForExistence(timeout: 5) { settingsTab.tap(); sleep(2) }
        let grantsRow = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '网页授权管理'")).firstMatch
        if grantsRow.waitForExistence(timeout: 5) {
            grantsRow.tap(); sleep(3)
            shoot("web-origin-grants")
        }
    }
}

private extension XCUIElement {
    func tapIfExistsCompat() { if exists { tap() } }
}
