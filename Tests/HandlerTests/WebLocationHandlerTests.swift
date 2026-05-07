import XCTest
@testable import WebBridgeKit

final class WebLocationHandlerTests: XCTestCase {

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

    func testLocationHandler_HandlerName() {
        let handler = WebLocationHandler()
        XCTAssertEqual(handler.handlerName, "Location")
    }

    // MARK: - Handle Returns Response

    func testLocationHandler_Handle_ReturnsResponse() {
        let handler = WebLocationHandler()
        let expectation = XCTestExpectation(description: "location handle")

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

    // MARK: - Ignores Body Params

    func testLocationHandler_IgnoresBodyParams() {
        let handler = WebLocationHandler()
        let expectation = XCTestExpectation(description: "location ignores body")

        handler.handle(body: ["accuracy": "high", "timeout": 10]) { result in
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

    func testLocationHandler_EmptyBody_DoesNotCrash() {
        let handler = WebLocationHandler()
        let expectation = XCTestExpectation(description: "location empty body")

        handler.handle(body: [:]) { result in
            guard let _ = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Multiple Calls Don't Crash

    func testLocationHandler_MultipleCalls_DontCrash() {
        let handler = WebLocationHandler()

        for i in 0..<3 {
            let expectation = XCTestExpectation(description: "location multiple \(i)")

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

    // MARK: - WebView Nil Handling

    func testLocationHandler_WebViewNil_DoesNotCrash() {
        let handler = WebLocationHandler()
        handler.webView = nil

        let expectation = XCTestExpectation(description: "location nil webView")

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
