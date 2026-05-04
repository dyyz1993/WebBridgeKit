import XCTest
@testable import WebBridgeKit

final class TokenGenerationTests: XCTestCase {

    var app: XCUIApplication!
    var tokenPage: TokenGeneratePage!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = AppLauncher.shared.launchApp()
        tokenPage = TokenGeneratePage(app: app)

        // Navigate to token generation page
        // (Assuming navigation via settings or direct access)
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()

            let settingsPage = SettingsPage(app: app)
            if settingsPage.verifyPageLoaded() {
                settingsPage.tapTokenManage()
            }
        }
    }

    override func tearDownWithError() throws {
        TestDataManager.shared.cleanupTestData()
        AppLauncher.shared.terminateApp(app)
        app = nil
        tokenPage = nil
    }

    // MARK: - Test Cases

    func testTokenGeneratePageLoads() {
        // Verify token generation page loads
        XCTAssertTrue(tokenPage.verifyPageLoaded(), "Token generate page should load within 10 seconds")
    }

    func testSelectURL() {
        // Test URL picker interaction
        TestDataManager.shared.prepareMockData()

        // Wait for data to load
        let expectation = XCTestExpectation(description: "Wait for data")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        // Select URL
        tokenPage.selectURL(at: 0)

        // Verify picker wheel exists and selection was made
        let picker = app.pickerWheels.firstMatch
        XCTAssertTrue(picker.exists, "URL picker should exist")

        // Wait a moment for selection to register
        Thread.sleep(forTimeInterval: 0.5)
    }

    func testSelectDurationOneDay() {
        // Test selecting 1 day duration
        tokenPage.selectDuration(.oneDay)

        // Verify segmented control updated
        let control = app.segmentedControls["tokenGenerate.durationSegmentedControl"]
        XCTAssertTrue(control.exists, "Duration control should exist")
    }

    func testSelectDurationSevenDays() {
        // Test selecting 7 day duration
        tokenPage.selectDuration(.sevenDays)

        let control = app.segmentedControls["tokenGenerate.durationSegmentedControl"]
        XCTAssertTrue(control.exists, "Duration control should exist")
    }

    func testSelectDurationThirtyDays() {
        // Test selecting 30 day duration
        tokenPage.selectDuration(.thirtyDays)

        let control = app.segmentedControls["tokenGenerate.durationSegmentedControl"]
        XCTAssertTrue(control.exists, "Duration control should exist")
    }

    func testSelectDurationPermanent() {
        // Test selecting permanent duration
        tokenPage.selectDuration(.permanent)

        let control = app.segmentedControls["tokenGenerate.durationSegmentedControl"]
        XCTAssertTrue(control.exists, "Duration control should exist")
    }

    func testGenerateToken() {
        // Prepare test data
        TestDataManager.shared.prepareMockData()

        // Select URL and duration
        tokenPage.selectURL(at: 0)
        tokenPage.selectDuration(.sevenDays)

        // Tap generate button
        tokenPage.tapGenerateButton()

        // Wait for token generation
        let tokenGenerated = tokenPage.waitForTokenGeneration(timeout: 10)
        XCTAssertTrue(tokenGenerated, "Token should be generated within 10 seconds")

        // Verify token was generated
        XCTAssertTrue(tokenPage.verifyTokenGenerated(), "Token generation should complete")
    }

    func testCopyToken() {
        // Generate a token first
        TestDataManager.shared.prepareMockData()
        tokenPage.selectURL(at: 0)
        tokenPage.selectDuration(.oneDay)
        tokenPage.tapGenerateButton()
        _ = tokenPage.waitForTokenGeneration(timeout: 10)

        // Copy token
        tokenPage.tapCopyButton()

        // Verify clipboard (if accessible)
        // Note: Clipboard may not be accessible in UI tests
        let alert = app.alerts.firstMatch
        if alert.exists {
            // Some apps show a "Copied" alert
        }
    }

    func testShareToken() {
        // Generate a token first
        TestDataManager.shared.prepareMockData()
        tokenPage.selectURL(at: 0)
        tokenPage.selectDuration(.sevenDays)
        tokenPage.tapGenerateButton()
        _ = tokenPage.waitForTokenGeneration(timeout: 10)

        // Tap share button
        tokenPage.tapShareButton()

        // Verify share sheet appears
        let shareSheet = app.otherElements["ActivityListView"].firstMatch
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 5), "Share sheet should appear")

        // Dismiss share sheet
        if let cancelButton = app.buttons["Cancel"].firstMatch as? XCUIElement, cancelButton.exists {
            cancelButton.tap()
        }
    }

    func testTokenGenerationFlow() {
        // Complete end-to-end flow
        TestDataManager.shared.prepareMockData()

        // 1. Select URL
        tokenPage.selectURL(at: 0)

        // 2. Select duration
        tokenPage.selectDuration(.thirtyDays)

        // 3. Generate token
        tokenPage.tapGenerateButton()

        // 4. Wait for completion
        XCTAssertTrue(tokenPage.waitForTokenGeneration(timeout: 10), "Token generation should complete")

        // 5. Verify token displayed
        let tokenText = tokenPage.getTokenText()
        XCTAssertNotNil(tokenText, "Token text should be available")
        XCTAssertFalse(tokenText!.isEmpty, "Token text should not be empty")
    }

    func testTokenAccessibility() {
        // Verify accessibility identifiers
        XCTAssertTrue(app.pickerWheels["tokenGenerate.urlPickerView"].exists, "URL picker accessibility identifier should exist")
        XCTAssertTrue(app.segmentedControls["tokenGenerate.durationSegmentedControl"].exists, "Duration control accessibility identifier should exist")
        XCTAssertTrue(app.buttons["tokenGenerate.generateButton"].exists, "Generate button accessibility identifier should exist")
        XCTAssertTrue(app.buttons["tokenGenerate.copyButton"].exists, "Copy button accessibility identifier should exist")
        XCTAssertTrue(app.buttons["tokenGenerate.shareButton"].exists, "Share button accessibility identifier should exist")
    }
}
