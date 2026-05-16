import XCTest
@testable import WebBridgeKit

final class WebOpenSettingsHandlerTests: XCTestCase {

    // MARK: - Handler Name

    func testOpenSettingsHandler_HandlerName() {
        let handler = WebOpenSettingsHandler()
        XCTAssertEqual(handler.handlerName, "OpenSettings")
    }

    // MARK: - Handle Returns Response

    func testOpenSettingsHandler_Handle_ReturnsResponse() {
        let handler = WebOpenSettingsHandler()
        let expectation = XCTestExpectation(description: "open settings handle")

        handler.handle(body: [:]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Ignores Body

    func testOpenSettingsHandler_IgnoresBodyParams() {
        let handler = WebOpenSettingsHandler()
        let expectation = XCTestExpectation(description: "open settings ignores body")

        handler.handle(body: ["setting": "privacy", "deep": true]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Empty Body

    func testOpenSettingsHandler_EmptyBody_DoesNotCrash() {
        let handler = WebOpenSettingsHandler()
        let expectation = XCTestExpectation(description: "open settings empty body")

        handler.handle(body: [:]) { result in
            guard let _ = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
