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
        XCTAssertTrue(element("pwa.details.permissions").waitForExistence(timeout: 4))
        element("pwa.details.permissions").tap()

        XCTAssertTrue(element("pwa.permission.center").waitForExistence(timeout: 5))
        for capability in ["bluetooth", "clipboard", "camera", "location", "fileImport", "share"] {
            XCTAssertTrue(
                element("pwa.permission.capability.\(capability)").waitForExistence(timeout: 3),
                "Missing declared capability: \(capability)"
            )
        }
        XCTAssertTrue(
            element("pwa.permission.capability.bluetooth")
                .staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'iOS 系统：'")).firstMatch.exists
        )
        XCTAssertTrue(app.staticTexts["尚未使用"].exists)
        XCTAssertFalse(app.buttons["pwa.permission.revokeAll"].isEnabled)

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
        XCTAssertTrue(element("pwa.details.open").waitForExistence(timeout: 4))
        element("pwa.details.open").tap()

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
        XCTAssertTrue(element("pwa.details.open").waitForExistence(timeout: 4))
        element("pwa.details.open").tap()

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
        XCTAssertTrue(element("pwa.details.permissions").waitForExistence(timeout: 4))
        element("pwa.details.permissions").tap()

        let grant = element("pwa.permission.capability.clipboard")
        XCTAssertTrue(grant.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pwa.permission.revokeAll"].isEnabled)
        grant.tap()
        XCTAssertTrue(element("pwa.permission.revokeSheet").waitForExistence(timeout: 3))
        app.buttons["pwa.permission.revokeConfirm"].tap()

        XCTAssertTrue(
            element("pwa.permission.capability.clipboard")
                .staticTexts["WebBridgeKit：尚未授权"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.buttons["pwa.permission.revokeAll"].isEnabled)
    }

    func testManagedPWAExposesPermissionCenterFromImmersiveHostMenu() {
        app.launch()

        let appButton = element("pwaHome.app.com.webbridgekit.fixture.permissions")
        XCTAssertTrue(appButton.waitForExistence(timeout: 12))
        appButton.tap()
        XCTAssertTrue(element("pwa.details.open").waitForExistence(timeout: 4))
        element("pwa.details.open").tap()

        let menu = element("browserManager.immersiveMenuButton")
        XCTAssertTrue(menu.waitForExistence(timeout: 12))
        menu.tap()

        XCTAssertTrue(element("pwa.permission.center").waitForExistence(timeout: 5))
        XCTAssertTrue(element("pwa.permission.capability.bluetooth").exists)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
