import XCTest

final class GatewayOnboardingTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--UITesting", "-UITesting"]
    }

    func testGatewayScreenExposesOnePageImportAndExplicitActivation() {
        app.launchEnvironment["WBK_GATEWAY_UI_PAYLOAD"] = Self.localPayload
        app.launch()
        openGatewayManagement()

        XCTAssertTrue(element("gateway.current").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["gateway.scan"].exists)
        XCTAssertTrue(app.buttons["gateway.paste"].exists)
        XCTAssertTrue(app.textViews["gateway.input"].exists)
        XCTAssertTrue(app.buttons["gateway.validate"].exists)
    }

    func testSecretPayloadShowsErrorAndNeverShowsActivation() {
        app.launchEnvironment["WBK_GATEWAY_UI_PAYLOAD"] = """
        {"name":"Unsafe","baseURL":"https://gateway.example.com","privateKey":"secret"}
        """
        app.launch()
        openGatewayManagement()
        app.buttons["gateway.validate"].tap()

        XCTAssertTrue(element("gateway.error").waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["gateway.activate"].exists)
    }

    private func openGatewayManagement() {
        let settings = app.tabBars.buttons["设置"]
        if settings.waitForExistence(timeout: 5) { settings.tap() }
        // Official hosting is surfaced as server configuration. Self-hosted
        // gateway import remains inside that flow rather than being a primary
        // first-run destination.
        let serverConfiguration = app.buttons["settings.cell.serverConfig"]
        XCTAssertTrue(serverConfiguration.waitForExistence(timeout: 5))
        serverConfiguration.tap()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private static let localPayload = """
    {
      "id": "local-ui",
      "name": "Local UI Gateway",
      "baseURL": "http://localhost:8080",
      "healthPath": "/health",
      "manifestPath": "/manifest"
    }
    """
}
