import XCTest
@testable import WebBridgeKit

final class WebHapticHandlerTests: XCTestCase {

    // MARK: - All Valid Styles

    func testHapticHandler_LightStyle() {
        assertHapticStyleReturns("light")
    }

    func testHapticHandler_MediumStyle() {
        assertHapticStyleReturns("medium")
    }

    func testHapticHandler_HeavyStyle() {
        assertHapticStyleReturns("heavy")
    }

    func testHapticHandler_SuccessStyle() {
        assertHapticStyleReturns("success")
    }

    func testHapticHandler_WarningStyle() {
        assertHapticStyleReturns("warning")
    }

    func testHapticHandler_ErrorStyle() {
        assertHapticStyleReturns("error")
    }

    func testHapticHandler_SelectionStyle() {
        assertHapticStyleReturns("selection")
    }

    // MARK: - Default Style

    func testHapticHandler_MissingStyle_DefaultsToMedium() {
        let handler = WebHapticHandler()
        let expectation = XCTestExpectation(description: "haptic missing style")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["style"] as? String, "medium")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Invalid Style

    func testHapticHandler_InvalidStyle_StillReturnsStyle() {
        let handler = WebHapticHandler()
        let expectation = XCTestExpectation(description: "haptic invalid style")

        handler.handle(body: ["style": "nonexistent"]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["style"] as? String, "nonexistent")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Case Sensitivity

    func testHapticHandler_UpperCaseStyle_TreatedAsInvalid() {
        let handler = WebHapticHandler()
        let expectation = XCTestExpectation(description: "haptic uppercase")

        handler.handle(body: ["style": "LIGHT"]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["style"] as? String, "LIGHT")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Handler Name

    func testHapticHandler_HandlerName() {
        let handler = WebHapticHandler()
        XCTAssertEqual(handler.handlerName, "Haptic")
    }

    // MARK: - Multiple Rapid Calls

    func testHapticHandler_MultipleRapidCalls() {
        let styles = ["light", "medium", "heavy", "success", "warning", "error", "selection"]

        for style in styles {
            let handler = WebHapticHandler()
            let expectation = XCTestExpectation(description: "haptic rapid \(style)")

            handler.handle(body: ["style": style]) { result in
                let dict = assertSuccess(result)
                guard let data = dict["data"] as? [String: Any] else {
                    XCTFail("Missing data")
                    return
                }
                XCTAssertEqual(data["style"] as? String, style)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 2.0)
        }
    }

    // MARK: - Helper

    private func assertHapticStyleReturns(_ style: String) {
        let handler = WebHapticHandler()
        let expectation = XCTestExpectation(description: "haptic \(style)")

        handler.handle(body: ["style": style]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["style"] as? String, style)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
