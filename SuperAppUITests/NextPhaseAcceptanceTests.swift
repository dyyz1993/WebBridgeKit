import XCTest

final class NextPhaseAcceptanceTests: XCTestCase {
    private var app: XCUIApplication!
    private let fixtureIdentity = "next_phase_identity_0123456789abcdef"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--UITesting", "-UITesting"]
        app.launchEnvironment = [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN",
            "WBK_OFFICIAL_PUSH_TEST_STATE": "initial-ready",
            "WBK_OFFICIAL_PUSH_TEST_IDENTITY": fixtureIdentity
        ]
    }

    func testOfficialHomeIsReadyWithoutGatewayConfiguration() {
        app.launch()

        XCTAssertTrue(element("pwaCenter.table").waitForExistence(timeout: 15))
        XCTAssertTrue(element("pwaHome.root").exists)
        XCTAssertTrue(app.buttons["home.push.send-safari"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["home.push.send-safari"].label, "用 Safari 发送测试")
        let address = element("home.push.address")
        XCTAssertTrue(makeVisible(address))
        XCTAssertTrue(address.label.contains(fixtureIdentity))
        XCTAssertTrue(app.buttons["home.push.copy"].isEnabled)
        XCTAssertFalse(element("gateway.table").exists)
        XCTAssertFalse(app.textViews["gateway.input"].exists)
    }

    func testOfficialCatalogRetainsSupportedV1PushCapabilities() {
        app.launch()
        XCTAssertTrue(element("pwaHome.apiExamples").waitForExistence(timeout: 15))
        element("pwaHome.apiExamples").tap()

        for type in [
            "bodyOnly", "plain", "markdown", "otp", "qr", "image",
            "sound", "badge", "badgeClear", "url", "copyManual", "copy",
            "replace", "recall"
        ] {
            let example = app.buttons["pushExamples.\(type).send"]
            XCTAssertTrue(
                makeVisible(example),
                "Missing canonical message example: \(type)"
            )
        }
    }

    func testGatewayImportRequiresValidationBeforeActivation() {
        app.launchEnvironment["WBK_GATEWAY_UI_PAYLOAD"] = Self.publicGatewayPayload
        app.launch()
        openGatewayManagement()

        XCTAssertTrue(element("gateway.current").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["gateway.scan"].exists)
        XCTAssertTrue(app.buttons["gateway.paste"].exists)
        XCTAssertTrue(app.textViews["gateway.input"].exists)
        XCTAssertFalse(element("gateway.report").exists)
        XCTAssertFalse(app.buttons["gateway.activate"].exists)

        app.buttons["gateway.validate"].tap()
        XCTAssertTrue(element("gateway.report").waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["wbk.shanbox.19930810.xyz"].exists)
        XCTAssertTrue(app.staticTexts["https://wbk.shanbox.19930810.xyz:8443/health"].exists)
        XCTAssertTrue(app.staticTexts["https://wbk.shanbox.19930810.xyz:8443/api/v1/html-apps"].exists)
        XCTAssertTrue(app.staticTexts["wbk-self-hosted-20260816"].exists)
        // SwiftUI currently surfaces this control by its visible label rather
        // than the parent gateway.activate identifier.
        let activate = app.buttons["启用此网关"]
        XCTAssertTrue(makeVisible(activate))
        XCTAssertTrue(activate.waitForExistence(timeout: 5))
    }

    func testGatewaySecretPayloadCannotReachActivation() {
        app.launchEnvironment["WBK_GATEWAY_UI_PAYLOAD"] = """
        {"name":"Unsafe","baseURL":"https://gateway.example.com","privateKey":"secret"}
        """
        app.launch()
        openGatewayManagement()
        app.buttons["gateway.validate"].tap()

        XCTAssertTrue(element("gateway.error").waitForExistence(timeout: 5))
        XCTAssertFalse(element("gateway.report").exists)
        XCTAssertFalse(app.buttons["gateway.activate"].exists)
    }

    func testInboxMarkdownAndApprovalPreservePresentationAndConsentBoundary() {
        app.launch()
        openTab("tab.notifications")

        openMessage(searchText: "运行任务", cardID: "stored-markdown-011")
        XCTAssertTrue(element("message.detail.markdown").waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        openTab("tab.notifications")

        openMessage(searchText: "生产发布", cardID: "stored-approval-media-014")
        XCTAssertTrue(element("message.detail.approvalState").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["待确认"].exists)
        XCTAssertTrue(app.buttons["message.detail.openApp"].exists)
        XCTAssertFalse(app.staticTexts["已通过"].exists)
    }

    private func openGatewayManagement() {
        openTab("tab.apps")
        XCTAssertTrue(element("pwaHome.manageApps").waitForExistence(timeout: 5))
        element("pwaHome.manageApps").tap()
        XCTAssertTrue(element("gateway.table").waitForExistence(timeout: 5))
    }

    private func openTab(_ identifier: String) {
        let tab = app.tabBars.firstMatch.buttons[identifier]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Missing tab \(identifier)")
        tab.tap()
    }

    private func openMessage(searchText: String, cardID: String) {
        let search = element("wbk_search_field")
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("\(searchText)\n")
        let card = element("notification.card.\(cardID)")
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(element("message.detail").waitForExistence(timeout: 5))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func makeVisible(_ target: XCUIElement) -> Bool {
        for _ in 0..<8 {
            if target.exists, target.isHittable { return true }
            app.swipeUp()
        }
        return target.exists
    }

    private static let publicGatewayPayload = """
    {
      "schemaVersion": "1",
      "id": "webbridgekit-gateway",
      "displayName": "WebBridgeKit Gateway",
      "baseURL": "https://wbk.shanbox.19930810.xyz:8443",
      "healthEndpoint": "/health",
      "manifestEndpoint": "/api/v1/html-apps",
      "publicKeyId": "wbk-self-hosted-20260816",
      "publicKey": "h860-f-Vu_IC9DNoOrGrMpnXydSZHjNqb2HprCJIcm8"
    }
    """
}
