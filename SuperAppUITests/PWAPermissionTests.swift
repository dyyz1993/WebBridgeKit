import XCTest

final class PWAPermissionTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--register-pwa-permission-fixture",
            "--show-pwa-app-center"
        ]
        app.launchEnvironment = [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN",
            "WBK_OFFICIAL_PUSH_TEST_STATE": "initial-ready",
            "WBK_OFFICIAL_PUSH_TEST_IDENTITY": "permission_fixture_identity"
        ]
    }

    func testPWAAppDetailsExposeDeclaredAndGrantedCapabilities() {
        app.launch()

        let appButton = element("pwaHome.app.com.webbridgekit.fixture.permissions")
        XCTAssertTrue(appButton.waitForExistence(timeout: 12))
        appButton.tap()
        XCTAssertTrue(app.buttons["权限与原生能力"].waitForExistence(timeout: 4))
        app.buttons["权限与原生能力"].tap()

        XCTAssertTrue(element("pwa-permission.headerCard").waitForExistence(timeout: 5))
        // 产品决策 2026-08-21：未授权能力不再渲染行，中心此时为空授权态
        for capability in ["bluetooth", "clipboard", "camera", "location", "fileImport", "share"] {
            XCTAssertFalse(
                element("pwa-permission.capability.\(capability)").exists,
                "未授权能力不应渲染: \(capability)"
            )
        }
        // 产品决策 2026-08-21：权限中心只展示已授权/需处理，「尚未使用」不再渲染
        XCTAssertFalse(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '尚未使用'"))
                .firstMatch.waitForExistence(timeout: 2)
        )
        XCTAssertEqual(app.buttons.matching(identifier: "pwa-permission.revokeAll").count, 0)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "pwa-permission-center"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testManagedPWABridgeRequestOffersScopesAndCanBeCancelled() {
        app.launch()

        let appButton = element("pwaHome.app.com.webbridgekit.fixture.permissions")
        XCTAssertTrue(appButton.waitForExistence(timeout: 12))
        appButton.tap()
        XCTAssertTrue(app.buttons["打开应用"].waitForExistence(timeout: 4))
        app.buttons["打开应用"].tap()

        let bridgeButton = app.webViews.buttons["读取剪贴板"]
        XCTAssertTrue(bridgeButton.waitForExistence(timeout: 12))
        bridgeButton.tap()

        XCTAssertTrue(element("pwa.permission.prompt").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["原生能力申请"].exists)
        for title in ["仅这一次", "本次使用期间", "始终允许", "取消"] {
            XCTAssertTrue(app.buttons[title].exists, "Missing permission choice: \(title)")
        }
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "pwa-bridge-permission-prompt"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["取消"].tap()
        XCTAssertFalse(element("pwa.permission.prompt").waitForExistence(timeout: 2))
        XCTAssertTrue(bridgeButton.exists)
    }

    func testBluetoothRequestUsesManagedPWAConsentBeforeSystemAccess() {
        app.launch()

        let appButton = element("pwaHome.app.com.webbridgekit.fixture.permissions")
        XCTAssertTrue(appButton.waitForExistence(timeout: 12))
        appButton.tap()
        XCTAssertTrue(app.buttons["打开应用"].waitForExistence(timeout: 4))
        app.buttons["打开应用"].tap()

        let bridgeButton = app.webViews.buttons["查看蓝牙状态"]
        XCTAssertTrue(bridgeButton.waitForExistence(timeout: 12))
        bridgeButton.tap()

        let prompt = element("pwa.permission.prompt")
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["允许使用蓝牙？"].exists)
        XCTAssertTrue(app.staticTexts["允许后，iOS 仍可能显示系统权限确认。"].exists)
        XCTAssertTrue(app.buttons["仅这一次"].exists)
        XCTAssertTrue(app.buttons["本次使用期间"].exists)
        XCTAssertTrue(app.buttons["始终允许"].exists)
        XCTAssertTrue(app.buttons["取消"].exists)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "pwa-bluetooth-permission-prompt"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Keep the UI test deterministic: cancel before CoreBluetooth can ask
        // for the simulator's system-level authorization.
        app.buttons["取消"].tap()
        XCTAssertFalse(prompt.waitForExistence(timeout: 2))
    }

    func testGrantedCapabilityCanBeReviewedAndRevoked() {
        app.launchArguments.append("--seed-pwa-permission-grant")
        app.launch()

        let appButton = element("pwaHome.app.com.webbridgekit.fixture.permissions")
        XCTAssertTrue(appButton.waitForExistence(timeout: 12))
        appButton.tap()
        XCTAssertTrue(app.buttons["权限与原生能力"].waitForExistence(timeout: 4))
        app.buttons["权限与原生能力"].tap()

        let grant = element("pwa-permission.capability.clipboard")
        XCTAssertTrue(grant.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pwa-permission.revokeAll"].isEnabled)
        app.buttons["pwa-permission.revoke.clipboard"].tap()
        XCTAssertTrue(element("pwa-permission.revokeConfirm").waitForExistence(timeout: 3))
        app.buttons["pwa-permission.revokeConfirm.confirm"].tap()

        // 撤销后该能力不再渲染（未授权不显示）
        XCTAssertFalse(element("pwa-permission.capability.clipboard").waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons.matching(identifier: "pwa-permission.revokeAll").count, 0)
    }

    func testManagedPWAExposesPermissionCenterFromImmersiveHostMenu() {
        app.launch()

        let appButton = element("pwaHome.app.com.webbridgekit.fixture.permissions")
        XCTAssertTrue(appButton.waitForExistence(timeout: 12))
        appButton.tap()
        XCTAssertTrue(app.buttons["打开应用"].waitForExistence(timeout: 4))
        app.buttons["打开应用"].tap()

        let menu = element("browserManager.immersiveMenuButton")
        XCTAssertTrue(menu.waitForExistence(timeout: 12))
        menu.tap()

        XCTAssertTrue(element("pwa-permission.headerCard").waitForExistence(timeout: 5))
        // 未授权能力不再渲染行，中心此时应为空授权态
        XCTAssertFalse(element("pwa-permission.capability.bluetooth").exists)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
