import XCTest

/// Real-device automation for importing the self-hosted HTML app gateway
/// (shanbox) through the product UI: 手册与调试 → 管理自有服务 → 粘贴配置 →
/// 验证 → 启用. Proves the full portable-onboarding flow without manual taps.
final class GatewayImportUITests: XCTestCase {

    /// Full portable gateway document served by GET /api/v1/gateway. Delivered
    /// through the WBK_GATEWAY_UI_PAYLOAD hook so no typing or pasteboard is
    /// needed (iOS 26 blocks runner pasteboard writes).
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
        app.launchArguments = [
            "--UITesting",
            "--push-server=https://wbk.shanbox.19930810.xyz:8443"
        ]
        app.launchEnvironment = [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN",
            "WBK_GATEWAY_UI_PAYLOAD": Self.gatewayPayload
        ]
        app.launch()
    }

    func testImportSelfHostedGatewayViaPaste() throws {
        // Home defers its bottom cards lazily; scroll first, then wait.
        let guide = app.buttons["pwaHome.guideAndDebug"]
        var prescrollAttempts = 0
        while !guide.exists && prescrollAttempts < 8 {
            app.swipeUp()
            prescrollAttempts += 1
        }
        XCTAssertTrue(guide.waitForExistence(timeout: 10), "Home should expose 手册与调试")
        while !guide.isHittable && prescrollAttempts < 12 {
            app.swipeUp()
            prescrollAttempts += 1
        }
        guide.tap()

        // Action sheets surface differently across iOS versions; accept the
        // button from the sheet container or the raw button tree.
        let manage = app.sheets.buttons["管理自有服务"].firstMatch
        let manageFallback = app.buttons["管理自有Service"].firstMatch
        let plainManage = app.buttons["管理自有服务"].firstMatch
        let matched: XCUIElement
        if manage.waitForExistence(timeout: 8) {
            matched = manage
        } else if plainManage.waitForExistence(timeout: 3) {
            matched = plainManage
        } else {
            XCTAssertTrue(manageFallback.waitForExistence(timeout: 2), "Action sheet should offer 管理自有服务")
            matched = manageFallback
        }
        matched.tap()

        // The payload was auto-filled via WBK_GATEWAY_UI_PAYLOAD; jump
        // straight to validation.
        let validate = app.buttons["gateway.validate"]
        XCTAssertTrue(validate.waitForExistence(timeout: 8))
        if !validate.isHittable {
            app.swipeUp()
        }
        validate.tap()

        // The report card renders first; the activate button sits below the
        // fold and SwiftUI renders it lazily. Signal success by the report's
        // verified-count text and use a type-agnostic query for the button —
        // SwiftUI surfaces it under different element kinds.
        let verified = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'verified'")
        ).firstMatch
        XCTAssertTrue(verified.waitForExistence(timeout: 45), "Validation report should render")

        // SwiftUI's parent .accessibilityIdentifier("gateway.report") leaks
        // onto the inner button, so the documented "gateway.activate" id never
        // surfaces in the tree — target the button by its label instead.
        let activate = app.buttons["启用此网关"]
        var reportScrollAttempts = 0
        while !activate.exists && reportScrollAttempts < 10 {
            app.swipeUp()
            reportScrollAttempts += 1
            Thread.sleep(forTimeInterval: 0.4)
        }
        XCTAssertTrue(
            activate.waitForExistence(timeout: 10),
            "启用此网关 button should render after scrolling the report"
        )
        while !activate.isHittable && reportScrollAttempts < 16 {
            app.swipeUp()
            reportScrollAttempts += 1
        }
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
