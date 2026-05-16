import XCTest
@testable import WebBridgeKit

final class WebClosePageHandlerTests: XCTestCase {

    // MARK: - Handler Name

    func testClosePageHandler_HandlerName() {
        let handler = WebClosePageHandler()
        XCTAssertEqual(handler.handlerName, "ClosePage")
    }

    // MARK: - No Active Browser Returns Error

    func testClosePageHandler_NoActiveBrowser_ReturnsError() {
        let handler = WebClosePageHandler()
        let expectation = XCTestExpectation(description: "close page no browser")

        handler.handle(body: [:]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Error Contains Code 404

    func testClosePageHandler_NoActiveBrowser_ReturnsCode404() {
        let handler = WebClosePageHandler()
        let expectation = XCTestExpectation(description: "close page error code")

        handler.handle(body: [:]) { result in
            let dict = assertFailure(result)
            XCTAssertEqual(dict["code"] as? Int, 404)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Ignores Animated Param When No Browser

    func testClosePageHandler_AnimatedParam_IgnoredWhenNoBrowser() {
        let handler = WebClosePageHandler()
        let expectation = XCTestExpectation(description: "close page animated param")

        handler.handle(body: ["params": ["animated": false, "reason": "timeout"]]) { result in
            let dict = assertFailure(result)
            XCTAssertEqual(dict["code"] as? Int, 404)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Empty Body

    func testClosePageHandler_EmptyBody_ReturnsError() {
        let handler = WebClosePageHandler()
        let expectation = XCTestExpectation(description: "close page empty body")

        handler.handle(body: [:]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
