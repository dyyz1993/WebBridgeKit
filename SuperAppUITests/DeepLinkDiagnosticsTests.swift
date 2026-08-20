import XCTest

/// Opens the Online Chat PWA directly from the home screen and captures
/// screenshots of the browser load state, diagnosing white-screen/URL errors
/// without needing a push roundtrip.
final class DeepLinkDiagnosticsTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil else {
            throw XCTSkip("Real-device only")
        }
        app = XCUIApplication()
        app.launchEnvironment = [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN"
        ]
        app.launch()
    }

    func testOpenOnlineChatFromHomeAndCapture() throws {
        // Find the Online Chat app card on the home screen
        let chatCard = app.buttons["pwaHome.app.com.dyyz1993.onlinechat"]
        XCTAssertTrue(
            chatCard.waitForExistence(timeout: 20),
            "Home should list Online Chat after gateway re-activation"
        )
        chatCard.tap()

        // Action sheet: tap 打开应用
        let openButton = app.sheets.buttons["打开应用"].firstMatch
        let plainOpen = app.buttons["打开应用"].firstMatch
        if openButton.waitForExistence(timeout: 5) {
            openButton.tap()
        } else if plainOpen.waitForExistence(timeout: 3) {
            plainOpen.tap()
        } else {
            XCTFail("打开应用 action not found in sheet")
        }

        // Wait for the browser to attempt loading, capturing progressive states
        Thread.sleep(forTimeInterval: 3)
        let early = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        early.name = "01-browser-3s"
        early.lifetime = .keepAlways
        add(early)

        Thread.sleep(forTimeInterval: 7)
        let later = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        later.name = "02-browser-10s"
        later.lifetime = .keepAlways
        add(later)
    }
}
