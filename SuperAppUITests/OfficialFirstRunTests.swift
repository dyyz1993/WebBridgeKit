import XCTest

final class OfficialFirstRunTests: XCTestCase {
    private let fixtureIdentity = "official_test_identity_0123456789abcdef"

    func testFreshLaunchShowsAPIAddressBeforeExplicitEnable() {
        let app = launch(state: "permission-required")

        XCTAssertTrue(app.descendants(matching: .any)["pwaCenter.table"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["home.push.send-safari"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["home.push.send-safari"].label, "启用通知")
        XCTAssertFalse(app.textFields["gateway.url"].exists)
        let address = app.descendants(matching: .any).matching(identifier: "home.push.address").firstMatch
        XCTAssertTrue(makeVisible(address, in: app))
        XCTAssertTrue(address.label.contains("https://api.drel.app/"))
        XCTAssertNotEqual(address.label, "启用通知后显示")
        XCTAssertTrue(app.buttons["home.push.copy"].isEnabled)
    }

    func testExplicitEnableShowsSystemNotificationAuthorization() {
        let app = launch(state: "permission-required")
        let action = app.buttons["home.push.send-safari"]
        XCTAssertTrue(action.waitForExistence(timeout: 15))
        XCTAssertEqual(action.label, "启用通知")

        action.tap()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let notificationAlert = springboard.alerts.firstMatch
        XCTAssertTrue(notificationAlert.waitForExistence(timeout: 5))
        XCTAssertTrue(notificationAlert.label.contains("Drel"))

        let deny = notificationAlert.buttons["不允许"]
        if deny.exists { deny.tap() }
    }

    func testExplicitEnableMakesPushAddressAvailable() {
        let app = launch(state: "ready")
        let action = app.buttons["home.push.send-safari"]
        XCTAssertTrue(action.waitForExistence(timeout: 15))

        action.tap()

        XCTAssertTrue(waitUntil(timeout: 5) { action.label == "用 Safari 发送测试" })
        let address = app.descendants(matching: .any).matching(identifier: "home.push.address").firstMatch
        XCTAssertTrue(makeVisible(address, in: app))
        XCTAssertTrue(address.label.contains(fixtureIdentity))
        XCTAssertTrue(app.buttons["home.push.copy"].isEnabled)
    }

    func testDeniedPermissionOffersSystemSettingsRecovery() {
        let app = launch(state: "denied")
        let action = app.buttons["home.push.send-safari"]
        XCTAssertTrue(action.waitForExistence(timeout: 15))

        action.tap()

        XCTAssertTrue(waitUntil(timeout: 5) { action.label == "前往系统设置" })
        XCTAssertTrue(app.staticTexts["home.push.permission-denied"].waitForExistence(timeout: 3))
    }

    func testRecoverableServiceErrorKeepsInput() {
        let app = launch(state: "error")
        let title = app.textFields["pwaHome.pushTitle"]
        let action = app.buttons["home.push.send-safari"]
        XCTAssertTrue(title.waitForExistence(timeout: 15))

        title.tap()
        title.typeText("保留")
        action.tap()

        XCTAssertTrue(waitUntil(timeout: 5) { action.label == "启用通知" })
        XCTAssertTrue((title.value as? String)?.contains("保留") == true)
        XCTAssertFalse(app.staticTexts[fixtureIdentity].exists)
    }

    func testSupportedV1PushExamplesRemainAvailable() {
        let app = launch(state: "initial-ready")
        let examples = app.buttons["pwaHome.apiExamples"]
        XCTAssertTrue(examples.waitForExistence(timeout: 15))
        examples.tap()

        for type in [
            "bodyOnly", "plain", "markdown", "otp", "qr", "image",
            "sound", "badge", "badgeClear", "url", "copyManual", "copy",
            "replace", "recall"
        ] {
            let example = app.buttons["pushExamples.\(type).send"]
            XCTAssertTrue(
                makeVisible(example, in: app),
                "Missing canonical push example: \(type)"
            )
        }
    }

    private func launch(state: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--UITesting", "-UITesting"]
        app.launchEnvironment = [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN",
            "WBK_OFFICIAL_PUSH_TEST_STATE": state,
            "WBK_OFFICIAL_PUSH_TEST_IDENTITY": fixtureIdentity
        ]
        app.launch()
        return app
    }

    private func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }

    private func makeVisible(_ target: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<8 {
            if target.exists, target.isHittable { return true }
            app.swipeUp()
        }
        return target.exists
    }
}
