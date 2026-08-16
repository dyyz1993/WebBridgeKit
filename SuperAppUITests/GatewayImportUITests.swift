import XCTest

/// Real-device automation for importing the self-hosted HTML app gateway
/// (shanbox) through the product UI: 手册与调试 → 管理自有服务 → 粘贴配置 →
/// 验证 → 启用. Proves the full portable-onboarding flow without manual taps.
final class GatewayImportUITests: XCTestCase {

    /// Portable gateway document served by GET /api/v1/gateway on shanbox.
    private static let gatewayPayload = """
    {"id":"webbridgekit-gateway","name":"WebBridgeKit Gateway","baseURL":"https://wbk.shanbox.19930810.xyz:8443","healthPath":"/health","manifestPath":"/api/v1/html-apps","publicKeyID":"wbk-self-hosted-20260816","publicKey":"h860-f-Vu_IC9DNoOrGrMpnXydSZHjNqb2HprCJIcm8"}
    """

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil else {
            throw XCTSkip("Real-device only: gateway activation and manifest trust are device flows")
        }
        app = XCUIApplication()
        app.launchEnvironment = [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN"
        ]
        app.launch()
    }

    func testImportSelfHostedGatewayViaPaste() throws {
        let guide = app.buttons["pwaHome.guideAndDebug"]
        XCTAssertTrue(guide.waitForExistence(timeout: 15), "Home should expose 手册与调试")
        var scrollAttempts = 0
        while !guide.isHittable && scrollAttempts < 6 {
            app.swipeUp()
            scrollAttempts += 1
        }
        guide.tap()

        let manage = app.sheets.buttons["管理自有服务"]
        XCTAssertTrue(manage.waitForExistence(timeout: 8), "Action sheet should offer 管理自有服务")
        manage.tap()

        // The paste button reads the system-wide pasteboard; the test runner
        // writes the portable gateway document there.
        UIPasteboard.general.string = Self.gatewayPayload
        let paste = app.buttons["gateway.paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 8), "Gateway screen should offer 粘贴配置")

        // If a previous import left an active gateway, the screen shows the
        // current state first; the import card is still reachable below it.
        if !paste.isHittable {
            app.swipeUp()
        }
        paste.tap()

        let validate = app.buttons["gateway.validate"]
        XCTAssertTrue(validate.waitForExistence(timeout: 5))
        if !validate.isHittable {
            app.swipeUp()
        }
        validate.tap()

        let activate = app.buttons["gateway.activate"]
        XCTAssertTrue(
            activate.waitForExistence(timeout: 30),
            "Validation report should appear with an activate action"
        )
        activate.tap()

        // Activated state renders the current-gateway card.
        let activated = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "已启用")
        ).firstMatch
        XCTAssertTrue(
            activated.waitForExistence(timeout: 10),
            "Gateway should report 已启用 after activation"
        )
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "gateway-activated"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
