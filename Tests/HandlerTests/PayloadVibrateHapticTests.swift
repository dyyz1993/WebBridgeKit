import XCTest
@testable import WebBridgeKit

extension SimpleHandlerTests {

    // MARK: - WebPayloadHandler

    func testPayloadHandler_ReturnsSuccessWithMessage() {
        let handler = WebPayloadHandler()
        let expectation = XCTestExpectation(description: "payload handler completes")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["message"])
            XCTAssertNotNil(data["hint"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebVibrateHandler

    func testVibrateHandler_WithExplicitDuration() {
        let handler = WebVibrateHandler()
        let expectation = XCTestExpectation(description: "vibrate with duration")

        handler.handle(body: ["duration": 500]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["duration"] as? Int, 500)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testVibrateHandler_DefaultDuration() {
        let handler = WebVibrateHandler()
        let expectation = XCTestExpectation(description: "vibrate default duration")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["duration"] as? Int, 1000)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebHapticHandler

    func testHapticHandler_LightStyle() {
        assertHapticStyle("light")
    }

    func testHapticHandler_MediumStyle() {
        assertHapticStyle("medium")
    }

    func testHapticHandler_HeavyStyle() {
        assertHapticStyle("heavy")
    }

    func testHapticHandler_SuccessStyle() {
        assertHapticStyle("success")
    }

    func testHapticHandler_WarningStyle() {
        assertHapticStyle("warning")
    }

    func testHapticHandler_ErrorStyle() {
        assertHapticStyle("error")
    }

    func testHapticHandler_SelectionStyle() {
        assertHapticStyle("selection")
    }

    func testHapticHandler_InvalidStyle_DefaultsToMedium() {
        let handler = WebHapticHandler()
        let expectation = XCTestExpectation(description: "haptic invalid style")

        handler.handle(body: ["style": "nonexistent"]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["style"] as? String, "nonexistent")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testHapticHandler_MissingStyle_DefaultsToMedium() {
        let handler = WebHapticHandler()
        let expectation = XCTestExpectation(description: "haptic default style")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["style"] as? String, "medium")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    private func assertHapticStyle(_ style: String) {
        let handler = WebHapticHandler()
        let expectation = XCTestExpectation(description: "haptic \(style)")

        handler.handle(body: ["style": style]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data for style \(style)")
                return
            }
            XCTAssertEqual(data["style"] as? String, style)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
