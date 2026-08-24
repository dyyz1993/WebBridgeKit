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
        // 第二次访问：返回 hub 再点同一张卡
        let back1 = app.buttons["browserManager.backButton"]
        if back1.exists && back1.isEnabled { back1.tap(); sleep(6) }
        if openLinks.element(boundBy: 2).exists {
            openLinks.element(boundBy: 2).tap()
            sleep(9)
            let att5 = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            att5.name = "second-visit"; att5.lifetime = .keepAlways; add(att5)
            // 回归用例：第二次进入后返回按钮必须仍可用，且能退回 hub
            let back2 = app.buttons["browserManager.backButton"]
            let secondBackEnabled = back2.exists && back2.isEnabled
            let att6 = XCTAttachment(string: "SECOND_BACK_ENABLED=\(secondBackEnabled)")
            att6.name = "second-back-state"; att6.lifetime = .keepAlways; add(att6)
            if secondBackEnabled {
                back2.tap()
                sleep(7)
                let att7 = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                att7.name = "after-second-back"; att7.lifetime = .keepAlways; add(att7)
            }
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
            let always = app.buttons.containing(NSPredicate(format: "label CONTAINS '允许'")).firstMatch
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

/// 网页授权管理页（带数据版）：种子授权后截图 origin 分组 + 撤销按钮
final class WebGrantsScreenshotTests: XCTestCase {
    func testGrantsPageWithData() {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-testing", "--register-pwa-permission-fixture", "--seed-pwa-permission-grant"]
        app.launch()
        sleep(6)
        let settingsTab = app.tabBars.buttons["设置"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 8))
        settingsTab.tap()
        sleep(2)
        let row = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '网页授权管理'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 6))
        row.tap()
        sleep(3)
        let att = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        att.name = "web-grants-with-data"
        att.lifetime = .keepAlways
        add(att)
    }
}

/// 权限全生命周期连续剧：申请 → 面板 → 允许 → 成功 → 原生管理页 → 撤销 → 空 → 复测
final class PermissionLifecycleShotTests: XCTestCase {
    private func snap(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
        sleep(1)
    }

    func testLifecycle() {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-testing", "--register-pwa-permission-fixture"]
        app.launch()
        sleep(6)

        // 1. 应用首页宫格：原生能力演示卡
        let appButton = app.buttons["pwaHome.app.com.webbridgekit.fixture.permissions"]
        XCTAssertTrue(appButton.waitForExistence(timeout: 12))
        snap("01-app-grid")

        // 2. 打开演示页（宫格 → 详情弹层 → 打开应用）
        appButton.tap()
        sleep(2)
        let launch = app.buttons.containing(NSPredicate(format: "label CONTAINS '打开应用'")).firstMatch
        XCTAssertTrue(launch.waitForExistence(timeout: 5))
        snap("02-app-details")
        launch.tap()
        sleep(7)
        snap("03-fixture-initial")

        // 3. 点「读取剪贴板」→ 原生授权面板
        let clipboardBtn = app.buttons.containing(NSPredicate(format: "label CONTAINS '读取剪贴板'")).firstMatch
        XCTAssertTrue(clipboardBtn.waitForExistence(timeout: 6))
        clipboardBtn.tap()
        let prompt = app.otherElements["pwa.permission.prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        sleep(1)
        snap("04-consent-panel")

        // 4. 选「始终允许」
        let always = app.buttons.containing(NSPredicate(format: "label CONTAINS '允许'")).firstMatch
        XCTAssertTrue(always.waitForExistence(timeout: 3))
        always.tap()
        sleep(3)
        snap("05-after-accept")

        // 5. 再次读取（应免面板直接成功）
        clipboardBtn.tap()
        sleep(3)
        snap("06-second-call-granted")

        // 7. 浏览器菜单 → 应用设置 → 权限中心（应用维度，带授权记录）
        let menu = app.descendants(matching: .any)["browserManager.immersiveMenuButton"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()
        sleep(2)
        // 沉浸式菜单直开权限中心（pwa-permission.headerCard 出现即为中心）
        XCTAssertTrue(app.descendants(matching: .any)["pwa-permission.headerCard"].waitForExistence(timeout: 6))
        sleep(1)
        snap("07-permission-center-granted")

        // 8. 中心内撤销：剪贴板
        let revoke = app.buttons["pwa-permission.revoke.clipboard"]
        if revoke.waitForExistence(timeout: 4) {
            revoke.tap()
            sleep(2)
            snap("08-revoke-confirm")
            let confirm = app.buttons["pwa-permission.revokeConfirm.confirm"]
            if confirm.waitForExistence(timeout: 3) {
                confirm.tap()
                sleep(2)
            }
            snap("09-after-revoke")
        }

        // 9. 关闭中心回网页，再读剪贴板 → 面板应重新弹出
        let closeCenter = app.navigationBars.buttons.element(boundBy: 0)
        if closeCenter.exists { closeCenter.tap() }
        sleep(2)
        let cb2 = app.buttons.containing(NSPredicate(format: "label CONTAINS '读取剪贴板'")).firstMatch
        if cb2.waitForExistence(timeout: 6) {
            cb2.tap()
            sleep(3)
            snap("10-reprompt-after-revoke")
        }

    }
}

/// 系统拒绝引导流：先在系统层拒绝相机 → PWA 调相机 → 弹「前往系统设置」引导
final class SystemDeniedFlowTests: XCTestCase {
    private func snap(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
        sleep(1)
    }

    func testSystemDeniedGuide() {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-testing", "--register-pwa-permission-fixture"]
        app.launch()
        sleep(6)

        // 打开演示应用
        let appButton = app.buttons["pwaHome.app.com.webbridgekit.fixture.permissions"]
        XCTAssertTrue(appButton.waitForExistence(timeout: 12))
        appButton.tap()
        sleep(2)
        let launch = app.buttons.containing(NSPredicate(format: "label CONTAINS '打开应用'")).firstMatch
        XCTAssertTrue(launch.waitForExistence(timeout: 5))
        launch.tap()
        sleep(7)
        snap("sysdenied-01-fixture-page")

        // 查看蓝牙状态 → 品牌面板（系统 notDetermined 会先弹系统询问）
        let btBtn = app.buttons.containing(NSPredicate(format: "label CONTAINS '查看蓝牙状态'")).firstMatch
        XCTAssertTrue(btBtn.waitForExistence(timeout: 6))
        btBtn.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // 面板出现
        let prompt = app.otherElements["pwa.permission.prompt"]
        if prompt.waitForExistence(timeout: 5) {
            snap("sysdenied-02-consent-panel")
            // 拒绝品牌面板（取消）
            let cancel = app.buttons.containing(NSPredicate(format: "label CONTAINS '取消'")).firstMatch
            if cancel.exists { cancel.tap(); sleep(2) }
        }

        // 权限中心（系统拒绝后通过界面看引导——系统拒绝需要真机/设置；
        // 模拟器上蓝牙系统弹窗出现在面板取消后）
        let sysDeny = springboard.buttons["不允许"].exists ? springboard.buttons["不允许"] : springboard.buttons["Don't Allow"].exists ? springboard.buttons["Don't Allow"] : nil
        if sysDeny != nil {
            sysDeny!.tap()
            sleep(3)
            snap("sysdenied-03-after-system-deny")
        }

        // 再调蓝牙 → 应弹「系统权限已关闭」引导（或 JS 返回错误）
        if btBtn.exists {
            btBtn.tap()
            sleep(4)
            snap("sysdenied-04-guide-or-result")
        }

        // 权限中心查看「需要处理」分组
        let menu = app.descendants(matching: .any)["browserManager.immersiveMenuButton"]
        if menu.waitForExistence(timeout: 6) {
            menu.tap()
            sleep(2)
            if app.descendants(matching: .any)["pwa-permission.headerCard"].waitForExistence(timeout: 6) {
                sleep(1)
                snap("sysdenied-05-permission-center")
            }
        }
    }
}

/// 系统拒绝后权限中心「需要处理」+「前往系统设置」按钮可见性
final class SystemDeniedCenterTests: XCTestCase {
    func testCenterShowsSettingsHandoff() {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-testing", "--register-pwa-permission-fixture"]
        app.launch()
        sleep(6)
        let appButton = app.buttons["pwaHome.app.com.webbridgekit.fixture.permissions"]
        XCTAssertTrue(appButton.waitForExistence(timeout: 12))
        appButton.tap()
        sleep(2)
        let launch = app.buttons.containing(NSPredicate(format: "label CONTAINS '打开应用'")).firstMatch
        XCTAssertTrue(launch.waitForExistence(timeout: 5))
        launch.tap()
        sleep(6)
        let menu = app.descendants(matching: .any)["browserManager.immersiveMenuButton"]
        XCTAssertTrue(menu.waitForExistence(timeout: 8))
        menu.tap()
        sleep(2)
        XCTAssertTrue(app.descendants(matching: .any)["pwa-permission.headerCard"].waitForExistence(timeout: 6))
        sleep(1)
        let att = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        att.name = "sysdenied-center"; att.lifetime = .keepAlways; add(att)
    }
}

/// 相机完整两层流：品牌面板 → iOS 系统弹窗 → 结果（首次申请）
final class CameraTwoLayerTests: XCTestCase {
    private func snap(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
        sleep(1)
    }

    func testCameraTwoLayerFlow() {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-testing", "--register-pwa-permission-fixture"]
        app.launch()
        sleep(6)

        let appButton = app.buttons["pwaHome.app.com.webbridgekit.fixture.permissions"]
        XCTAssertTrue(appButton.waitForExistence(timeout: 12))
        appButton.tap()
        sleep(2)
        let launch = app.buttons.containing(NSPredicate(format: "label CONTAINS '打开应用'")).firstMatch
        XCTAssertTrue(launch.waitForExistence(timeout: 5))
        launch.tap()
        sleep(8)
        snap("cam-01-page")

        // 点「使用相机」→ 第一层：品牌面板
        let camBtn = app.buttons.containing(NSPredicate(format: "label CONTAINS '使用相机'")).firstMatch
        XCTAssertTrue(camBtn.waitForExistence(timeout: 8))
        camBtn.tap()
        let prompt = app.otherElements["pwa.permission.prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        sleep(1)
        snap("cam-02-consent-panel")

        // 选「始终允许」→ 第二层：iOS 系统弹窗
        let always = app.buttons.containing(NSPredicate(format: "label CONTAINS '允许'")).firstMatch
        XCTAssertTrue(always.waitForExistence(timeout: 3))
        always.tap()
        sleep(3)
        // iOS 系统弹窗（SpringBoard 级）
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        var sysOK: XCUIElement? = nil
        for label in ["允许", "OK", "Allow", "允许访问", "Allow While Using App"] {
            if springboard.buttons[label].exists {
                sysOK = springboard.buttons[label]; break
            }
        }
        if sysOK != nil {
            snap("cam-03-system-prompt")
            sysOK!.tap()
            sleep(4)
        } else {
            snap("cam-03-no-system-prompt")
        }

        // 第四张：结果（成功或错误）
        snap("cam-04-result")

        // 第五张：再调一次（直通，不弹任何面板）
        camBtn.tap()
        sleep(4)
        snap("cam-05-second-call")
    }
}

/// 本地信任端到端：推送链接打开（非注册应用）→ 点相机 → 品牌面板 → 允许 → 结果
final class LocalTrustE2ETests: XCTestCase {
    private func snap(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
        sleep(1)
    }

    func testLocalTrustFullFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        sleep(5)
        // 深链打开公网页面（非注册应用 = 本地信任路径）
        XCUIDevice.shared.system.open(URL(string: "webbridgekit://open?url=https%3A%2F%2Fae8fcb.shanbox.19930810.xyz%3A8443%2Ftest_resources%2Fpwa-permission%2Findex.html")!)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.buttons["打开"]
        if open.waitForExistence(timeout: 10) { sleep(2); open.tap(); if open.exists { open.tap() } }
        sleep(12)
        snap("lt-01-page")

        // 点「使用相机」→ 应弹品牌面板（不再报"不是已验证的PWA"）
        let camBtn = app.buttons.containing(NSPredicate(format: "label CONTAINS '使用相机'")).firstMatch
        XCTAssertTrue(camBtn.waitForExistence(timeout: 10), "使用相机按钮应存在")
        camBtn.tap()
        sleep(2) // 等面板稳定
        // 简化版面板是 UIAlertController——查找「允许」按钮
        // 注意：iOS 系统弹窗也有「允许」，区分方式是我们的先出现
        let allowBtn = app.buttons["允许"]
        let panelShown = allowBtn.waitForExistence(timeout: 8)
        sleep(2) // 额外等待确保截到面板而非后续状态
        snap("lt-02-panel=\(panelShown)")

        // 选「始终允许」→ 系统弹窗
        let always = app.buttons.containing(NSPredicate(format: "label CONTAINS '允许'")).firstMatch
        if always.waitForExistence(timeout: 3) {
            always.tap()
            sleep(3)
            var sysOK: XCUIElement? = nil
            for label in ["允许", "OK", "Allow"] {
                if springboard.buttons[label].exists { sysOK = springboard.buttons[label]; break }
            }
            if sysOK != nil {
                snap("lt-03-system")
                sysOK!.tap()
                sleep(5)
            }
        }
        snap("lt-04-result")
    }
}

/// 深度诊断：相机流每步截图，追踪面板是否重弹
final class CameraLoopDiagTests: XCTestCase {
    private func snap(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
        sleep(1)
    }

    func testDiagCameraLoop() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        sleep(5)
        XCUIDevice.shared.system.open(URL(string: "webbridgekit://open?url=https%3A%2F%2Fae8fcb.shanbox.19930810.xyz%3A8443%2Ftest_resources%2Fpwa-permission%2Findex.html")!)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let openBtn = springboard.buttons["打开"]
        if openBtn.waitForExistence(timeout: 10) { sleep(2); openBtn.tap(); if openBtn.exists { openBtn.tap() } }
        sleep(12)
        snap("diag-01-page")

        let camBtn = app.buttons.containing(NSPredicate(format: "label CONTAINS '使用相机'")).firstMatch
        XCTAssertTrue(camBtn.waitForExistence(timeout: 8))
        camBtn.tap()
        sleep(3)

        // 面板第一次出现
        let prompt = app.otherElements["pwa.permission.prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        snap("diag-02-panel-first")

        // 选「本次使用期间」
        let session = app.buttons.containing(NSPredicate(format: "label CONTAINS '本次使用期间'")).firstMatch
        XCTAssertTrue(session.waitForExistence(timeout: 3))
        session.tap()
        sleep(3)
        snap("diag-03-after-select")

        // 等系统弹窗
        var sysBtn: XCUIElement? = nil
        for label in ["允许", "OK", "Allow"] {
            if springboard.buttons[label].exists { sysBtn = springboard.buttons[label]; break }
        }
        if sysBtn != nil {
            snap("diag-04-system-prompt")
            sysBtn!.tap()
            sleep(4)
        } else {
            snap("diag-04-no-system")
        }
        snap("diag-05-after-system")

        // 再等 5 秒看面板是否重弹
        sleep(5)
        let panelStill = prompt.exists
        snap("diag-06-panel-still=\(panelStill)")

        // 再等 5 秒
        sleep(5)
        let panelStill2 = prompt.exists
        snap("diag-07-panel-still2=\(panelStill2)")

        // dump 元素树
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "diag-tree"; tree.lifetime = .keepAlways; add(tree)
    }
}

/// 剪贴板一次授权后不重弹：第一次弹面板→允许→第二次直通→结果区有返回
final class ClipboardGrantPersistenceTests: XCTestCase {
    private func snap(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
        sleep(1)
    }

    func testGrantOnceThenSilent() {
        let app = XCUIApplication()
        // --reset-permission-grants：测试设备可能带着上次运行的持久授权
        // （xcodebuild 按名字选设备，`simctl uninstall booted` 未必清到它），
        // 不重置则首调直接命中账本，测试必然失败。
        app.launchArguments = ["--ui-testing", "--reset-permission-grants"]
        app.launch()
        sleep(5)
        XCUIDevice.shared.system.open(URL(string: "webbridgekit://open?url=https%3A%2F%2Fae8fcb.shanbox.19930810.xyz%3A8443%2Ftest_resources%2Fpwa-permission%2Findex.html")!)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.buttons["打开"]
        if open.waitForExistence(timeout: 10) { sleep(2); open.tap(); if open.exists { open.tap() } }
        sleep(12)
        snap("clip-01-page")

        // 第一次：点「读取剪贴板」→ 应弹品牌面板
        let clipBtn = app.buttons.containing(NSPredicate(format: "label CONTAINS '读取剪贴板'")).firstMatch
        XCTAssertTrue(clipBtn.waitForExistence(timeout: 10))
        clipBtn.tap()
        sleep(3)
        let panel = app.otherElements["pwa.permission.prompt"]
        let panelShown1 = panel.waitForExistence(timeout: 5)
        snap("clip-02-panel1=\(panelShown1)")
        XCTAssertTrue(panelShown1, "第一次调用应弹品牌面板")

        // 点「允许」
        let allow = app.buttons.containing(NSPredicate(format: "label == '允许'")).firstMatch
        XCTAssertTrue(allow.waitForExistence(timeout: 3))
        allow.tap()
        sleep(5)
        snap("clip-03-after-allow")

        // 第二次：再点「读取剪贴板」→ 不应弹面板
        clipBtn.tap()
        sleep(4)
        let panelShown2 = panel.exists
        snap("clip-04-second=\(panelShown2)")
        XCTAssertFalse(panelShown2, "授权后第二次调用不应再弹面板")

        // 第三次：关页面重进再点 → 依然不弹（持久）
        let close = app.buttons["browserManager.closeButton"]
        if close.waitForExistence(timeout: 4) { close.tap() }
        sleep(2)
        XCUIDevice.shared.system.open(URL(string: "webbridgekit://open?url=https%3A%2F%2Fae8fcb.shanbox.19930810.xyz%3A8443%2Ftest_resources%2Fpwa-permission%2Findex.html")!)
        if open.waitForExistence(timeout: 8) { sleep(2); open.tap(); if open.exists { open.tap() } }
        sleep(10)
        let clipBtn2 = app.buttons.containing(NSPredicate(format: "label CONTAINS '读取剪贴板'")).firstMatch
        if clipBtn2.waitForExistence(timeout: 8) {
            clipBtn2.tap()
            sleep(4)
            let panelShown3 = panel.exists
            snap("clip-05-reentry=\(panelShown3)")
            XCTAssertFalse(panelShown3, "重进页面后授权应持久，不应弹面板")
        }
    }
}

/// 网页授权管理页 E2E：授权→菜单进原生授权页→撤销→行消失→再调用重新弹面板。
/// 回归 2026-08-23：revoke(appID:) 曾硬编码 test-gateway，local-trust 授权撤销无效。
final class WebGrantRevokeTests: XCTestCase {
    private func snap(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
        sleep(1)
    }

    func testRevokeRestoresConsentPrompt() {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-testing", "--register-pwa-permission-fixture"]
        app.launch()
        sleep(6)

        let appButton = app.buttons["pwaHome.app.com.webbridgekit.fixture.permissions"]
        XCTAssertTrue(appButton.waitForExistence(timeout: 12), "宫格应有 fixture 应用")

        // 宫格按钮在 fixture 异步注册后会重建（AX 元素失效）；菜单/转场 tap 也偶发被吞——都重试
        func tapStable(_ el: XCUIElement, timeout: TimeInterval = 6) -> Bool {
            for _ in 0..<3 {
                if el.waitForExistence(timeout: timeout) {
                    el.tap()
                    return true
                }
            }
            return false
        }
        func openFixturePage() -> Bool {
            for _ in 0..<3 {
                guard tapStable(appButton) else { continue }
                sleep(2)
                let launch = app.buttons.containing(NSPredicate(format: "label CONTAINS '打开应用'")).firstMatch
                guard launch.waitForExistence(timeout: 5) else { continue }
                launch.tap()
                let clip = app.buttons.containing(NSPredicate(format: "label CONTAINS '读取剪贴板'")).firstMatch
                if clip.waitForExistence(timeout: 12) { return true }
                let close = app.buttons["browserManager.closeButton"]
                if close.waitForExistence(timeout: 3) { close.tap(); sleep(2) }
            }
            return false
        }
        XCTAssertTrue(openFixturePage(), "fixture 演示页应可打开")

        // 授权剪贴板（面板→允许）
        let clipBtn = app.buttons.containing(NSPredicate(format: "label CONTAINS '读取剪贴板'")).firstMatch
        clipBtn.tap()
        let prompt = app.otherElements["pwa.permission.prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 6), "首次调用应弹品牌面板")
        let allow = app.buttons.containing(NSPredicate(format: "label == '允许'")).firstMatch
        XCTAssertTrue(allow.waitForExistence(timeout: 4))
        allow.tap()
        sleep(4)
        snap("revoke-01-granted")

        // 菜单 → 权限中心（fixture 浏览器菜单可能直接呈现或经入口进入）
        let headerCard = app.descendants(matching: .any)["pwa-permission.headerCard"]
        var centerOpened = headerCard.waitForExistence(timeout: 4)
        if !centerOpened {
            let navMenu = app.buttons["browserManager.menuButton"]
            let immersiveMenu = app.descendants(matching: .any)["browserManager.immersiveMenuButton"]
            for m in [navMenu, immersiveMenu] where !centerOpened {
                if m.waitForExistence(timeout: 4) {
                    m.tap()
                    sleep(2)
                    if headerCard.waitForExistence(timeout: 4) { centerOpened = true; break }
                    for entry in [app.buttons["权限管理"], app.buttons["应用设置"]] {
                        if entry.waitForExistence(timeout: 2) { entry.tap(); sleep(2); break }
                    }
                    centerOpened = headerCard.waitForExistence(timeout: 5)
                }
            }
        }
        XCTAssertTrue(centerOpened, "应能进入权限中心")
        snap("revoke-02-center")

        // 撤销剪贴板（品牌确认面板 → 确认）
        let revokeBtn = app.buttons["pwa-permission.revoke.clipboard"]
        XCTAssertTrue(revokeBtn.waitForExistence(timeout: 6), "权限中心应有剪贴板撤销按钮")
        revokeBtn.tap()
        sleep(2)
        let confirmBtn = app.buttons["pwa-permission.revokeConfirm.confirm"]
        XCTAssertTrue(confirmBtn.waitForExistence(timeout: 4), "应弹出撤销确认面板")
        confirmBtn.tap()
        sleep(2)
        snap("revoke-03-after")
        XCTAssertFalse(
            app.buttons["pwa-permission.revoke.clipboard"].waitForExistence(timeout: 2),
            "撤销后该授权行应消失"
        )

        // 重启回首页（权限中心在隐藏导航栏的栈上无法点返回）→ 重新打开演示页
        // → 再点剪贴板 → 面板应重新弹出。
        // 注：fixture 重注册自身也会 revokeAll，此断言验证的是 UX 语义
        // （撤销后下次调用重新询问），修复本身的证据是上面的行消失断言。
        app.terminate()
        app.launch()
        sleep(6)
        XCTAssertTrue(openFixturePage(), "重启后应能重新打开演示页")
        let clipBtn2 = app.buttons.containing(NSPredicate(format: "label CONTAINS '读取剪贴板'")).firstMatch
        clipBtn2.tap()
        sleep(3)
        let panelBack = prompt.waitForExistence(timeout: 6)
        snap("revoke-04-reprompt=\(panelBack)")
        XCTAssertTrue(panelBack, "撤销后再次调用应重新弹品牌面板")
    }
}

/// 会话恢复：iOS 在系统设置改隐私权限（TCC）会终止 App（已实证），
/// 「前往系统设置」引导回来必然冷启动——5 分钟内自动恢复上次浏览页；
/// 用户主动关闭页面后不复活。
final class BrowserSessionRestoreTests: XCTestCase {
    private func snap(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
        sleep(1)
    }

    private func openDemoPage(_ app: XCUIApplication) {
        XCUIDevice.shared.system.open(URL(string: "webbridgekit://open?url=http%3A%2F%2Flocalhost%3A8081%2Ftest_resources%2Fpwa-permission%2Findex.html")!)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.buttons["打开"]
        if open.waitForExistence(timeout: 10) { sleep(2); open.tap(); if open.exists { open.tap() } }
    }

    private func browserVisible(_ app: XCUIApplication) -> Bool {
        app.buttons.containing(NSPredicate(format: "label CONTAINS '读取剪贴板'")).firstMatch.waitForExistence(timeout: 12)
    }

    func testRestoreAfterKillAndNoRestoreAfterClose() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--enable-session-restore"]
        app.launch()
        sleep(5)

        // 1. 打开演示页 → 模拟系统杀进程 → 冷启动应恢复
        openDemoPage(app)
        XCTAssertTrue(browserVisible(app), "演示页应已打开")
        app.terminate()
        app.launch()
        sleep(6)
        let restored = browserVisible(app)
        snap("restore-1-after-kill=\(restored)")
        XCTAssertTrue(restored, "冷启动 5 分钟内应自动恢复上次浏览页")

        // 2. 用户主动关闭页面 → 冷启动不应复活
        let close = app.buttons["browserManager.closeButton"]
        XCTAssertTrue(close.waitForExistence(timeout: 6), "应有浏览器关闭按钮")
        close.tap()
        sleep(3)
        app.terminate()
        app.launch()
        sleep(6)
        let resurrected = app.buttons.containing(NSPredicate(format: "label CONTAINS '读取剪贴板'")).firstMatch.exists
        snap("restore-2-after-close=\(resurrected)")
        XCTAssertFalse(resurrected, "用户关闭页面后冷启动不应复活")
    }
}

/// 网页授权管理页布局验证（截图）：时间/appID 换行、无 TabBar
final class OriginGrantsShotTests: XCTestCase {
    func testGrantsPageLayoutShot() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        sleep(5)
        XCUIDevice.shared.system.open(URL(string: "webbridgekit://open?url=http%3A%2F%2Flocalhost%3A8081%2Ftest_resources%2Fpwa-permission%2Fauto-clipboard.html")!)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.buttons["打开"]
        if open.waitForExistence(timeout: 10) { sleep(2); open.tap(); if open.exists { open.tap() } }
        sleep(8)

        let panel = app.otherElements["pwa.permission.prompt"]
        XCTAssertTrue(panel.waitForExistence(timeout: 10), "自动页应弹品牌面板")
        let allow = app.buttons.containing(NSPredicate(format: "label == '允许'")).firstMatch
        XCTAssertTrue(allow.waitForExistence(timeout: 4))
        allow.tap()
        sleep(4)

        let menu = app.buttons["browserManager.menuButton"]
        if !menu.waitForExistence(timeout: 5) {
            XCTFail("浏览器菜单按钮缺失"); return
        }
        menu.tap()
        sleep(2)
        let perm = app.buttons["权限管理"]
        XCTAssertTrue(perm.waitForExistence(timeout: 5), "菜单应有权限管理入口")
        perm.tap()
        sleep(3)
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = "grants-page"; a.lifetime = .keepAlways; add(a)
    }
}

/// 页面 meta 声明身份 E2E：面板显示声明名 → 允许 → 落账 page.{id} →
/// 清单外能力被拒
final class DeclaredIdentityFlowTests: XCTestCase {
    private func snap(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
        sleep(1)
    }

    func testDeclaredIdentityFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-permission-grants"]
        app.launch()
        sleep(5)
        XCUIDevice.shared.system.open(URL(string: "webbridgekit://open?url=http%3A%2F%2Flocalhost%3A8081%2Ftest_resources%2Fpwa-permission%2Fdeclared-app.html")!)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.buttons["打开"]
        if open.waitForExistence(timeout: 10) { sleep(2); open.tap(); if open.exists { open.tap() } }
        sleep(9)

        // 1. 面板出现，头部显示声明名
        let prompt = app.otherElements["pwa.permission.prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 10), "声明页应弹品牌面板")
        XCTAssertTrue(app.staticTexts["剪贴板演示应用"].waitForExistence(timeout: 4), "面板应显示声明应用名")
        snap("declared-01-panel")

        // 2. 允许 → 剪贴板成功
        let allow = app.buttons.containing(NSPredicate(format: "label == '允许'")).firstMatch
        XCTAssertTrue(allow.waitForExistence(timeout: 4))
        allow.tap()
        sleep(5)
        snap("declared-02-allowed")

        // 3. 菜单 → 权限管理 → 授权记在 page.{id} 名下
        let menu = app.buttons["browserManager.menuButton"]
        XCTAssertTrue(menu.waitForExistence(timeout: 6), "应有浏览器菜单按钮")
        menu.tap(); sleep(2)
        let perm = app.buttons["权限管理"]
        XCTAssertTrue(perm.waitForExistence(timeout: 5), "菜单应有权限管理入口")
        perm.tap(); sleep(3)
        let pageID = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'page.com.webbridgekit.demo.clipboard'")).firstMatch
        XCTAssertTrue(pageID.waitForExistence(timeout: 6), "授权应记在 page.{声明ID} 名下")
        snap("declared-03-grants")

        // 4. 清单外能力（蓝牙）被拒：返回 → 点申请蓝牙 → 错误文案含「未声明」
        let back = app.navigationBars.buttons.firstMatch
        if back.waitForExistence(timeout: 4) { back.tap(); sleep(2) }
        let btBtn = app.buttons.containing(NSPredicate(format: "label CONTAINS '申请清单外的蓝牙'")).firstMatch
        XCTAssertTrue(btBtn.waitForExistence(timeout: 8), "应有蓝牙越权按钮")
        btBtn.tap()
        sleep(4)
        let deniedText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '未声明'")).firstMatch
        let deniedShown = deniedText.waitForExistence(timeout: 6)
        snap("declared-04-capdenied=\(deniedShown)")
        XCTAssertTrue(deniedShown, "清单外能力应被拒绝并提示未声明")
    }
}

/// 相册能力 E2E：品牌面板 → 允许 → iOS 相册权限弹窗 → PHPicker → 取消
final class PhotoCapabilityFlowTests: XCTestCase {
    private func snap(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
        sleep(1)
    }

    func testPhotoFullFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-permission-grants"]
        app.launch()
        sleep(5)
        // ?v= 破 WKWebView HTTP 缓存——页面 JS 迭代后旧缓存会让断言打到老代码
        XCUIDevice.shared.system.open(URL(string: "webbridgekit://open?url=http%3A%2F%2Flocalhost%3A8081%2Ftest_resources%2Fpwa-permission%2Findex.html%3Fv%3Dphoto2")!)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.buttons["打开"]
        if open.waitForExistence(timeout: 10) { sleep(2); open.tap(); if open.exists { open.tap() } }
        sleep(10)

        let photoBtn = app.buttons.containing(NSPredicate(format: "label CONTAINS '选择相册图片'")).firstMatch
        XCTAssertTrue(photoBtn.waitForExistence(timeout: 10), "演示页应有相册按钮")

        // 跳过剪贴板卡（上面）直接滚到相册卡并点击
        photoBtn.tap()
        let prompt = app.otherElements["pwa.permission.prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 8), "相册首次调用应弹品牌面板")
        sleep(1)
        snap("photo-01-panel")
        let allow = app.buttons.containing(NSPredicate(format: "label == '允许'")).firstMatch
        XCTAssertTrue(allow.waitForExistence(timeout: 4))
        allow.tap()
        sleep(4)

        // iOS 系统相册权限弹窗（springboard 域）：notDetermined 时出现
        // 「允许完全访问」；已授权（上次运行/预授权）则直接进选择器——两种都要能走
        let sysAllow = springboard.buttons["允许完全访问"]
        let sysShown = sysAllow.waitForExistence(timeout: 5)
        snap("photo-02-system=\(sysShown)")
        if sysShown {
            sysAllow.tap()
            sleep(4)
        }

        // PHPicker 出现 → 取消
        let pickerCancel = app.buttons["取消"].firstMatch
        let pickerShown = pickerCancel.waitForExistence(timeout: 8)
        snap("photo-03-picker=\(pickerShown)")
        XCTAssertTrue(pickerShown, "应弹出照片选择器")
        pickerCancel.tap()
        sleep(3)
        let cancelled = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '已取消选择'")).firstMatch
        let cancelledShown = cancelled.waitForExistence(timeout: 5)
        snap("photo-04-result=\(cancelledShown)")
        XCTAssertTrue(cancelledShown, "取消后页面应显示已取消选择")
    }
}
