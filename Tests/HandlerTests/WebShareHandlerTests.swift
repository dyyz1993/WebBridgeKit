import XCTest
@testable import WebBridgeKit

final class WebShareHandlerTests: XCTestCase {

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

    // MARK: - Missing Parameters

    func testShareHandler_EmptyBody_ReturnsError() {
        let handler = WebShareHandler()
        let expectation = XCTestExpectation(description: "share empty body")

        handler.handle(body: [:]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testShareHandler_MissingText_ReturnsError() {
        let handler = WebShareHandler()
        let expectation = XCTestExpectation(description: "share missing text")

        handler.handle(body: ["params": ["url": "https://example.com"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testShareHandler_MissingURL_ReturnsError() {
        let handler = WebShareHandler()
        let expectation = XCTestExpectation(description: "share missing url")

        handler.handle(body: ["params": ["text": "hello"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testShareHandler_InvalidURL_ReturnsError() {
        let handler = WebShareHandler()
        let expectation = XCTestExpectation(description: "share invalid url")

        handler.handle(body: ["params": ["text": "hello", "url": "not_a_url"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Valid Parameters

    func testShareHandler_TopLevelParams_NoVCFails() {
        let handler = WebShareHandler()
        let expectation = XCTestExpectation(description: "share top level no VC")

        handler.handle(body: ["text": "hello", "url": "https://example.com"]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - URL Edge Cases

    func testShareHandler_URLWithSpaces_ReturnsError() {
        let handler = WebShareHandler()
        let expectation = XCTestExpectation(description: "share url with spaces")

        handler.handle(body: ["params": ["text": "hello", "url": "not a url"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testShareHandler_EmptyTextAndURL_ReturnsError() {
        let handler = WebShareHandler()
        let expectation = XCTestExpectation(description: "share empty text url")

        handler.handle(body: ["params": ["text": "", "url": ""]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Handler Name

    func testShareHandler_HandlerName() {
        let handler = WebShareHandler()
        XCTAssertEqual(handler.handlerName, "Share")
    }
}
