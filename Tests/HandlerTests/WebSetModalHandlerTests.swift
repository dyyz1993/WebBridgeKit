import XCTest
@testable import WebBridgeKit

final class WebSetModalHandlerTests: XCTestCase {

    private func assertSuccess(_ result: Any) -> [String: Any] {
        guard let dict = result as? [String: Any] else {
            XCTFail("Result is not a dictionary")
            return [:]
        }
        XCTAssertEqual(dict["success"] as? Bool, true)
        return dict
    }

    private func assertFailure(_ result: Any) -> [String: Any] {
        guard let dict = result as? [String: Any] else {
            XCTFail("Result is not a dictionary")
            return [:]
        }
        XCTAssertEqual(dict["success"] as? Bool, false)
        return dict
    }

    // MARK: - Handler Name

    func testSetModalHandler_HandlerName() {
        let handler = WebSetModalHandler()
        XCTAssertEqual(handler.handlerName, "SetModal")
    }

    // MARK: - No Current Modal Returns Error

    func testSetModalHandler_NoCurrentModal_ReturnsError() {
        let handler = WebSetModalHandler()
        let expectation = XCTestExpectation(description: "set modal no modal")

        handler.handle(body: [:]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Error Contains Code 400

    func testSetModalHandler_NoCurrentModal_ReturnsCode400() {
        let handler = WebSetModalHandler()
        let expectation = XCTestExpectation(description: "set modal error code")

        handler.handle(body: [:]) { result in
            let dict = self.assertFailure(result)
            XCTAssertEqual(dict["code"] as? Int, 400)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Error Message Contains Modal

    func testSetModalHandler_NoCurrentModal_ErrorMentionsModal() {
        let handler = WebSetModalHandler()
        let expectation = XCTestExpectation(description: "set modal error message")

        handler.handle(body: [:]) { result in
            let dict = self.assertFailure(result)
            let errorMsg = dict["error"] as? String ?? ""
            XCTAssertTrue(errorMsg.contains("modal"), "Error should mention modal")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Width Param Ignored When No Modal

    func testSetModalHandler_WidthParam_IgnoredWhenNoModal() {
        let handler = WebSetModalHandler()
        let expectation = XCTestExpectation(description: "set modal width param")

        handler.handle(body: ["params": ["width": "80%"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertEqual(dict["code"] as? Int, 400)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Multiple Params Ignored When No Modal

    func testSetModalHandler_MultipleParams_IgnoredWhenNoModal() {
        let handler = WebSetModalHandler()
        let expectation = XCTestExpectation(description: "set modal multiple params")

        handler.handle(body: ["params": ["width": "90%", "height": "80%", "mask": false]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertEqual(dict["code"] as? Int, 400)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Empty Body

    func testSetModalHandler_EmptyBody_ReturnsError() {
        let handler = WebSetModalHandler()
        let expectation = XCTestExpectation(description: "set modal empty body")

        handler.handle(body: [:]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
