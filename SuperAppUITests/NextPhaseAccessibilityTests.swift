import XCTest

final class NextPhaseAccessibilityTests: XCTestCase {
    func testGatewayControlsRemainReachableAtAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITesting",
            "-UITesting",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXL"
        ]
        app.launchEnvironment = [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN"
        ]
        app.launch()

        let appsTab = app.tabBars.firstMatch.buttons["tab.apps"]
        XCTAssertTrue(appsTab.waitForExistence(timeout: 10))
        appsTab.tap()
        let manage = element("pwaHome.manageApps", in: app)
        XCTAssertTrue(manage.waitForExistence(timeout: 5))
        manage.tap()

        for identifier in ["gateway.scan", "gateway.paste", "gateway.validate"] {
            let control = app.buttons[identifier]
            XCTAssertTrue(control.waitForExistence(timeout: 5), "Missing \(identifier)")
            XCTAssertGreaterThanOrEqual(control.frame.height, 44, "\(identifier) must retain a 44pt hit target")
        }
        XCTAssertTrue(app.textViews["gateway.input"].exists)
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
